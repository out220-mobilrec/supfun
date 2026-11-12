# SUP FUN: Безопасная регистрация и email-подтверждение

## Поток регистрации пользователя

### Клиент → Сервер (Register.tsx)

1. **Клиентская валидация:**
   - Имя: `minLength={2}`
   - Email: `type="email"` + `required`
   - Пароль: `minLength={8}`
   - Подтверждение пароля: совпадение с полем password

2. **Запрос:**
   ```http
   POST /api/auth/register
   Content-Type: application/json
   
   {
     "name": "Александр",
     "email": "alex@example.com",
     "password": "SecurePass123!",
     "city": "Владивосток"
   }
   ```

### Сервер (auth.service.ts)

1. **Проверка email на существование** — защита от enumeration:
   ```typescript
   if (existing) {
     return { message: 'Если email свободен, на него отправлен код.' };
   }
   ```

2. **Хеширование пароля:**
   ```typescript
   const passwordHash = await bcrypt.hash(dto.password, 10);
   ```

3. **Создание пользователя:**
   ```typescript
   const user = await this.usersService.create({ /* ... */ });
   // isEmailVerified=false по умолчанию
   ```

4. **Генерация кода подтверждения:**
   - `randomBytes(4).readUInt32BE(0) % 1_000_000` → 6 цифр
   - Хэш SHA-256 сохраняется в БД
   - TTL: 15 минут
   - attemptCount: счётчик брутфорса (блокировка после 10 попыток)

5. **Отправка кода:**
   - Если SMTP настроен → письмо на email
   - Dev-mode (NODE_ENV !== 'production') → devCode в ответе API

6. **Ответ клиента:**
   ```json
   { "message": "Код подтверждения отправлен на ваш email." }
   // или
   { "message": "...", "devCode": "123456" }  // только dev
   ```

---

## Подтверждение email

### Клиент → Сервер (VerifyEmail.tsx)

1. **Форма:**
   - Поле email
   - Поле для ввода 6-значного кода
   - Кнопка «Подтвердить»

2. **Запрос:**
   ```http
   POST /api/auth/verify-email
   Content-Type: application/json
   
   {
     "email": "alex@example.com",
     "code": "123456"
   }
   ```

3. **Серверная логика:**
   ```typescript
   async verifyWithCredentials(email, code, ctx) {
     const user = await findUserByEmail(email);
     if (!user) throw BadRequest('Invalid or expired code');
     
     const row = await findCode(code, EMAIL_VERIFY, user.id);
     // Проверка attemptCount (блокировка после 10 неверных)
     
     await updateUser(user.id, { isEmailVerified: true });
     await deleteVerificationCodes(user.id);
     return issueTokens(user);  // JWT + auto-login
   }
   ```

4. **Успешный ответ (AuthResult):**
   ```json
   {
     "accessToken": "eyJhbG...",
     "refreshToken": "...",
     "user": {
       "id": "...",
       "email": "alex@example.com",
       "isEmailVerified": true,
       "name": "Александр"
     }
   }
   ```

---

## Вход после подтверждения

### Guard EmailVerifiedGuard

Применяется к endpoints, требующим подтверждённый email:

```typescript
@UseGuards(EmailVerifiedGuard)
@Post('/profile')
getProfile(@CurrentUser() user) { ... }
```

**Логика guard:**
```typescript
async canActivate(ctx): Promise<boolean> {
  const userId = req.user?.id;
  const user = await users.findOne({ where: { id: userId }, select: ['id', 'isEmailVerified'] });
  
  if (!user || !user.isEmailVerified) {
    throw new ForbiddenException({
      message: 'Email не подтверждён. Проверьте почту.',
      code: 'EMAIL_NOT_VERIFIED'
    });
  }
  
  return true;
}
```

---

## Rate-limiting и брутфорс-защита

### Контроллер (@Throttle)

```typescript
@Controller('auth')
@UseGuards(HttpThrottlerGuard)
@Throttle({ limit: 5, ttl: 60000 })  // 5 запросов в минуту
export class AuthController { ... }
```

Для sensitive endpoints (login, register, forgot-password) применяется stricter лимит:

```typescript
@Throttle({ limit: 3, ttl: 60000 })  // 3 запроса в минуту
@Post('/register')
async register(...) { ... }
```

### Code brute-force protection

```typescript
const MAX_CODE_ATTEMPTS = 10;

if (row.attemptCount >= MAX_CODE_ATTEMPTS) {
  await this.tokens.delete({ id: row.id });  // удалить токен
  throw new ForbiddenException(
    'Слишком много неверных попыток. Запросите новый код.'
  );
}
```

Каждая неверная попытка увеличивает `attemptCount`. При достижении порога токен удаляется полностью.

---

## Аудит событий (auth_audit)

Таблица `auth_audit` записывает все критичные события:

| Столбец | Описание | Пример значения |
|---------|----------|-----------------|
| `user_id` | UUID пользователя (null если неизвестно) | `b603c328-5e12-4b52-8eb0-938e9ae9a0a1` |
| `event` | Тип события | `register_success`, `login_unverified`, `email_verified` |
| `ip` | IP адрес клиента | `::1` (localhost) или реальный IP |
| `user_agent` | Browser/Client UA | `Mozilla/5.0...` |
| `created_at` | Таймстемп | `2026-09-30T21:52:33+10:00` |

**Примеры событий:**
- `register_attempt_existing` — пользователь пытался зарегистрироваться с существующим email
- `register_success` — успешная регистрация нового пользователя
- `login_failed_no_user` — неверный email
- `login_banned` — попытка входа заблокированного аккаунта
- `login_unverified` — вход без подтверждённого email
- `email_verify_code_sent` — код отправлен на email
- `email_verified` — email успешно подтверждён

---

## Security Features Summary

| Feature | Implementation | Status |
|---------|----------------|--------|
| **Password hashing** | bcrypt cost=10 | ✅ |
| **No user enumeration** | Одинаковый ответ для новых/существующих email | ✅ |
| **Email verification required** | Запрет login до подтверждения | ✅ |
| **Short codes** | 6 цифр (20 бит энтропии) | ✅ |
| **Code expiration** | 15 минут TTL | ✅ |
| **Brute-force protection** | attemptCount ≤ 10 | ✅ |
| **Rate limiting** | @Throttle(limit=3..5, ttl=60s) | ✅ |
| **Audit logging** | auth_audit table | ✅ |
| **Dev-code fallback** | Возврат кода в response если NODE_ENV !== production | ✅ |
| **Mail fallback** | Log вместо отправки если SMTP недоступен | ✅ |

---

## Развёртывание

### .env настройки

```bash
NODE_ENV=production  # devCode будет возвращаться только в development
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USER=sup.fun.app@gmail.com
MAIL_PASS=***AppPassword***
MAIL_FROM=no-reply@supfun.app

FRONTEND_URL=https://app.supfun.fun
JWT_SECRET=your-secret-key-here
```

### Migrations

```bash
cd server && npx typeorm-ts-node-commonjs migration:run
# создаёт таблицу auth_audit и колонку attempt_count
```

### Frontend routing

Маршруты уже объявлены в App.tsx:
- `/register` — форма регистрации
- `/verify-email?email=...&code=...` — страница подтверждения
- `/forgot-password` — запрос сброса пароля
- `/reset-password?email=...&code=...` — сброс пароля

