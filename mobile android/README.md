# SUP FUN — мобильное приложение (Android)

Мобильное приложение SUP FUN сообщества на Flutter: заплывы на SUP-бордах,
карты водоёмов, события, чаты, маркетплейс снаряжения, профиль пользователя.
Backend (NestJS + PostgreSQL) — отдельный компонент; клиент общается с ним
по REST API с JWT-аутентификацией.

## Содержание

- [Архитектура](#архитектура)
- [Структура проекта](#структура-проекта)
- [Запуск](#запуск)
- [Аутентификация и сессия](#аутентификация-и-сессия)
- [API — общая сводка](#api--общая-сводка)
- [API — полный справочник](#api--полный-справочник)
- [Локальное хранение](#локальное-хранение)
- [Используемые пакеты](#используемые-пакеты)

---

## Архитектура

```
┌─────────────────────────────┐
│  Flutter-приложение (этот   │   UI: Material 3, цвет primary #1A4A6E
│  каталог)                   │   Auth: refresh-token в Keychain
│                             │   Storage: Hive + sqlite (GPS-точки)
└──────────────┬──────────────┘
               │  HTTPS/HTTP (REST + JSON)
               │  Authorization: Bearer <accessToken>
               ▼
┌─────────────────────────────┐
│  Backend NestJS             │   Глобальный JwtAuthGuard + @Public()
│  D:\sup3\server             │   Все endpoints кроме auth/health/search
│                             │   требуют валидный accessToken
└──────────────┬──────────────┘
               │  TypeORM
               ▼
┌─────────────────────────────┐
│  PostgreSQL 18 + PostGIS   │   Таблицы: users, auth_tokens, waterbodies,
│  БД: sup_fun                │   events, tracks, marketplace_listings,
└─────────────────────────────┘   channels, posts, messages, friends, ...
```

---

## Структура проекта

```
D:\sup3\mobile android\                ← корень Flutter-проекта
│
├── pubspec.yaml                        ← зависимости (Flutter, provider,
│                                        hive, flutter_secure_storage, http, ...)
├── pubspec.lock
├── launch-app.bat                      ← запуск на разных платформах
├── README.md                           ← этот файл
├── android/                            ← Android-обёртка (build.gradle,
│   │                                     AndroidManifest.xml, MainActivity)
│   └── app/
│       └── src/main/AndroidManifest.xml
│
├── assets/                             ← статические ресурсы
│   ├── images/                         ← логотип, сплеш-картинки
│   ├── icons/                          ← SVG-иконки нижней навигации
│   └── splash/                         ← Full-HD вертикальные сплеши
│       ├── splash_540.jpg              ← маленькие экраны
│       ├── splash_720.jpg              ← средние
│       ├── splash_1080.jpg             ← основная (большинство устройств)
│       └── splash_1440.jpg             ← QHD+
│
└── lib/
    ├── main.dart                       ← MultiProvider + Consumer<AuthController>,
    │                                     маршрутизация, _SplashGate,
    │                                     _AuthenticatedRoot, Shell с нижней навигацией
    │
    ├── controllers/                    ← state-management, ChangeNotifier
    │   ├── auth_controller.dart        ← логин/регистрация/refresh/logout,
    │   │                                 тихий вход по refreshToken,
    │   │                                 override apiBaseUrl
    │   └── storage_controller.dart     ← CRUD над локальными данными
    │
    ├── models/                         ← чистые данные (без Hive-генераторов)
    │   ├── user_model.dart             ← AppUser: id, email, name, city, bio,
    │   │                                 avatarUrl, role → rank, xp → level/...
    │   ├── local_models.dart           ← LocalRoute, LocalWaterBody,
    │   │                                 LocalConversation, LocalChatMessage,
    │   │                                 LocalFeedPost, LocalEvent, ...
    │   ├── local_models.g.dart         ← авто-сгенерированные TypeAdapter
    │   └── models.dart                 ← реэкспорт
    │
    ├── services/                       ← хранилища и сеть
    │   ├── api_service.dart            ← общий http-клиент (можно расширить)
    │   └── local_storage_service.dart  ← Hive + SQLite (trip_points),
    │                                     secure-keys (refresh token),
    │                                     api base URL, пользователи
    │
    ├── screens/                        ← все экраны
    │   ├── splash_screen.dart          ← картинка с fade+scale (Full-HD)
    │   ├── auth_screen.dart            ← логин/регистрация (поверх сплеша),
    │   │                                 поле адреса сервера для эмулятора/LAN
    │   ├── home_screen.dart            ← главная: погода, события, лента,
    │   │                                 имя и аватар из AuthController
    │   ├── map_screen.dart             ← карта + фильтры
    │   ├── waterbody_screen.dart       ← страница водоёма
    │   ├── community_screen.dart       ← лента, каналы
    │   ├── profile_screen.dart         ← профиль, статистика, меню,
    │   │                                 аватар/имя/город — из БД,
    │   │                                 refresh — реальный запрос на сервер
    │   ├── prestart_screen.dart        ← старт заплыва
    │   ├── tracking_screen.dart        ← GPS-трекинг в реальном времени
    │   ├── result_screen.dart          ← итоги заплыва
    │   ├── chats_list_screen.dart      ← список диалогов
    │   ├── chat_screen.dart            ← диалог
    │   ├── marketplace_screen.dart     ← маркетплейс снаряжения
    │   ├── create_event_screen.dart    ← создание заплыва
    │   └── local_data_screen.dart      ← список локальных данных
    │
    └── theme/
        └── app_theme.dart              ← AppTheme:
                                          - primaryColor = #1A4A6E (тёмно-синий)
                                          - accentColor = #00A6A6 (бирюзовый)
                                          - secondaryColor = #FFB400 (янтарный)
                                          - Material 3, ColorScheme.fromSeed
```

---

## Запуск

### Предварительные требования

- Flutter SDK 3.10+
- Java 17+
- Android SDK + Android Emulator (или физическое устройство по USB)
- Backend NestJS должен быть поднят (см. ниже)

### Подготовка

```bash
cd D:\sup3\mobile android
flutter pub get
```

### Запуск на Android-эмуляторе

```bash
flutter run -d android
```

Убедитесь, что эмулятор запущен (`flutter devices`).

### Адрес сервера

По умолчанию клиент ходит на `http://localhost:3000/api`. Это работает, если:

- **Десктоп с сервером на той же машине** → `http://localhost:3000/api` (дефолт).
- **Android-эмулятор** → `http://10.0.2.2:3000/api` (маршрут к хост-машине).
- **Физическое устройство** → `http://<LAN-IP>:3000/api` (IP машины с сервером, например `192.168.1.5`).

URL можно поменять прямо на экране логина (поле «Адрес сервера»). Он
сохраняется в локальном хранилище и применяется после перезапуска.

### Сборка APK

```bash
flutter build apk --release
```

Файл: `build/app/outputs/flutter-apk/app-release.apk`.

### Сборка AAB (для Google Play)

```bash
flutter build appbundle --release
```

Файл: `build/app/outputs/bundle/release/app-release.aab`.

---

## Аутентификация и сессия

### Схема обмена токенами

```
[Запуск приложения]
    │
    ▼
AuthController.initialize()
    │
    ├─► читает refreshToken из flutter_secure_storage (Android Keychain)
    │
    └─► если есть → POST /api/auth/refresh
            │
            ├─ accessToken (живёт ~15 мин, JWT)
            └─ refreshToken (живёт 30 дней, ОБНОВЛЯЕТСЯ при каждом refresh,
                            старый гасится — защита rotation)
```

### Логика входа

1. **Первый запуск** — нет токенов → показывается AuthScreen.
2. **Логин** — `POST /api/auth/login` → accessToken + refreshToken;
   оба сохраняются, профиль из `users` кешируется в Hive.
3. **Следующие запуски** — приложение молча обменивает refreshToken
   на новый accessToken; пользователь сразу попадает в Shell
   с нижней навигацией.
4. **Logout** — refreshToken инвалидируется на сервере
   (`POST /api/auth/logout`), локально всё стирается.
5. **Expired / invalid** — refresh провалился → показывается AuthScreen
   (с сообщением об ошибке в SnackBar).

### Что и где хранится

| Данные                  | Хранилище                     |
|-------------------------|--------------------------------|
| `accessToken`           | Hive `auth` box (временный)    |
| `refreshToken`          | `flutter_secure_storage` — Android Keychain (зашифровано) |
| Кеш `AppUser`           | Hive `users` box               |
| Адрес сервера           | Hive `auth` box                |
| Локальные маршруты/чаты | Hive + SQLite (`trip_points`)  |

---

## API — общая сводка

| Параметр              | Значение                                    |
|------------------------|---------------------------------------------|
| Базовый URL            | `http://<host>:3000/api`                   |
| Формат                | JSON                                        |
| Авторизация           | `Authorization: Bearer <accessToken>`       |
| Content-Type          | `application/json`                          |
| Лимит запросов        | 500 в минуту на IP (ThrottlerGuard)         |
| Глобальная защита     | `JwtAuthGuard` на все эндпоинты, кроме помеченных `@Public()` |
| Публичные эндпоинты   | `/auth/login`, `/auth/register`, `/auth/refresh`, `/auth/verify-email`, `/auth/forgot-password`, `/auth/reset-password`, `/health`, `/search` |

### Коды ответов

| Код | Смысл                                                   |
|------|---------------------------------------------------------|
| 200 | OK                                                     |
| 400 | Невалидный запрос (валидация DTO)                       |
| 401 | Нет токена / истёк / невалидный / пользователь забанен |
| 403 | Доступ запрещён (роль, бан)                             |
| 404 | Эндпоинт/ресурс не найден                               |
| 409 | Конфликт (например, дубликат email)                     |
| 429 | Превышен лимит запросов                                 |
| 500 | Серверная ошибка                                        |

---

## API — полный справочник

Серверная часть: `D:\sup3\server\src\modules\`. Все эндпоинты требуют
JWT, кроме отмеченных **Public**.

### Auth (`/api/auth`)

| Метод | Путь                          | Что делает                               | Доступ |
|--------|------------------------------|--------------------------------------------|--------|
| POST   | `/auth/register`              | Регистрация нового пользователя            | Public |
| POST   | `/auth/login`                 | Логин → accessToken + refreshToken         | Public |
| POST   | `/auth/refresh`               | Обмен refresh на новую пару токенов        | Public |
| POST   | `/auth/logout`                | Инвалидировать переданный refreshToken     | JWT    |
| POST   | `/auth/logout-all`            | Инвалидировать ВСЕ refreshTokens пользователя | JWT |
| POST   | `/auth/resend-verification`   | Письмо подтверждения email                 | JWT    |
| POST   | `/auth/verify-email`          | Подтверждение по токену из письма          | Public |
| POST   | `/auth/forgot-password`       | Письмо для сброса пароля                   | Public |
| POST   | `/auth/reset-password`        | Сброс пароля по токену                     | Public |
| POST   | `/auth/change-password`       | Смена пароля (знаем текущий)               | JWT    |

`POST /auth/login` request:
```json
{ "email": "user@example.com", "password": "supersecret" }
```

Response:
```json
{
  "accessToken":  "eyJ...",
  "refreshToken": "vnr5oT...",
  "user": { "id": "uuid", "email": "...", "name": "...", "city": "...", "role": "user", "xp": 0, "isEmailVerified": false, ... }
}
```

### Users (`/api/users`)

| Метод   | Путь                          | Что делает                                    | Доступ |
|---------|-------------------------------|-----------------------------------------------|--------|
| GET     | `/users`                      | Список всех (только admin/moderator)          | JWT+Role |
| GET     | `/users/me`                   | Текущий пользователь                          | JWT    |
| PATCH   | `/users/me`                   | Обновить имя/город/bio/avatarUrl/phone        | JWT    |
| DELETE  | `/users/me`                   | Удалить аккаунт                               | JWT    |
| GET     | `/users/:id/profile`          | Профиль пользователя (с учётом видимости)     | JWT    |
| GET     | `/users/:id`                  | Краткая карточка пользователя                 | JWT    |
| POST    | `/users`                      | Создать пользователя (admin/moderator)        | JWT+Role |

### Waterbodies (`/api/waterbodies`)

| Метод | Путь                | Что делает                              | Доступ |
|--------|---------------------|----------------------------------------|--------|
| GET    | `/waterbodies`      | Список с поиском (`?q=`, `?limit=`, `?offset=`) | JWT |
| GET    | `/waterbodies/nearby` | Ближайшие (`?lat=`, `?lng=`, `?radius=`) | JWT |
| GET    | `/waterbodies/:id`  | Карточка одного водоёма                 | JWT    |

### Events (`/api/events`)

| Метод  | Путь                              | Что делает                          | Доступ |
|--------|-----------------------------------|-------------------------------------|--------|
| POST   | `/events`                         | Создать заплыв                      | JWT    |
| GET    | `/events`                         | Лента                               | JWT    |
| GET    | `/events/nearby`                  | Ближайшие                           | JWT    |
| GET    | `/events/mine/:status`            | Мои (`status = upcoming / past / …`) | JWT   |
| GET    | `/events/:id`                     | Карточка                            | JWT    |
| PATCH  | `/events/:id`                     | Редактировать (только владелец)     | JWT    |
| DELETE | `/events/:id`                     | Отменить                            | JWT    |
| POST   | `/events/:id/join`                | Присоединиться                      | JWT    |
| GET    | `/events/:id/participants`        | Список участников                   | JWT    |
| PATCH  | `/events/:id/participants/:userId`| Изменить роль (owner / admin)       | JWT    |
| DELETE | `/events/:id/participants/:userId`| Исключить                           | JWT    |
| POST   | `/events/:id/invites`             | Пригласить пользователя             | JWT    |
| GET    | `/events/:id/invites`             | Список приглашений                  | JWT    |
| DELETE | `/events/:id/invites/:userId`     | Отозвать приглашение                | JWT    |

### Tracks (`/api/tracks`) — GPS-треки заплывов

| Метод  | Путь                         | Что делает                          | Доступ |
|--------|------------------------------|-------------------------------------|--------|
| POST   | `/tracks`                    | Создать трек                        | JWT    |
| GET    | `/tracks/mine`               | Мои треки                           | JWT    |
| GET    | `/tracks/:id`                | Получить трек + точки               | JWT    |
| PATCH  | `/tracks/:id`                | Обновить (название, видимость)      | JWT    |
| POST   | `/tracks/:id/points`         | Добавить GPS-точки (батч)           | JWT    |
| POST   | `/tracks/:id/complete`       | Завершить                           | JWT    |
| POST   | `/tracks/:id/publish`        | Опубликовать в ленту                | JWT    |
| DELETE | `/tracks/:id`                | Удалить                             | JWT    |

### Posts & Feed

| Метод | Путь                            | Доступ |
|--------|----------------------------------|--------|
| GET    | `/feed`                          | JWT    |
| GET    | `/feed?q=...` (контроллер search) | Public |
| GET    | `/posts`                         | JWT    |
| GET    | `/posts/:id`                     | JWT    |
| DELETE | `/posts/:id`                     | JWT    |
| PATCH  | `/posts/:id/like`                | JWT    |
| GET    | `/posts/:id/comments`            | JWT    |
| DELETE | `/posts/:id/comments/:commentId` | JWT    |

### Marketplace (`/api/marketplace`)

| Метод  | Путь                                       | Что делает                       | Доступ |
|--------|--------------------------------------------|----------------------------------|--------|
| POST   | `/marketplace/listings`                    | Создать объявление               | JWT    |
| GET    | `/marketplace/listings`                    | Лента (`?category=`, `?q=`)      | JWT    |
| GET    | `/marketplace/listings/mine`               | Мои                              | JWT    |
| GET    | `/marketplace/listings/for-me`             | Для меня                         | JWT    |
| GET    | `/marketplace/listings/:id`                | Карточка                         | JWT    |
| PATCH  | `/marketplace/listings/:id`                | Редактировать                    | JWT    |
| DELETE | `/marketplace/listings/:id`                | Удалить                          | JWT    |
| POST   | `/marketplace/listings/:id/complete`       | Продано                          | JWT    |
| POST   | `/marketplace/listings/:id/leads`          | Оставить заявку                  | JWT    |
| PATCH  | `/marketplace/listings/:id/favorite`       | В избранное                      | JWT    |
| GET    | `/marketplace/listings/:id/reviews`        | Отзывы                           | JWT    |
| POST   | `/marketplace/listings/:id/reviews`        | Оставить отзыв                   | JWT    |
| GET    | `/marketplace/listings/:id/rating`         | Средний рейтинг                  | JWT    |
| POST   | `/marketplace/listings/:id/status`         | Сменить статус                   | JWT    |
| GET    | `/marketplace/categories`                  | Список категорий                 | JWT    |

### Channels (`/api/channels`)

| Метод  | Путь                                       | Что делает                       | Доступ |
|--------|--------------------------------------------|----------------------------------|--------|
| GET    | `/channels`                                | Список каналов                   | JWT    |
| POST   | `/channels`                                | Создать                          | JWT    |
| GET    | `/channels/:id`                            | Карточка                         | JWT    |
| PATCH  | `/channels/:id`                            | Редактировать                    | JWT    |
| DELETE | `/channels/:id`                            | Удалить                          | JWT    |
| POST   | `/channels/:id/join`                       | Вступить                         | JWT    |
| POST   | `/channels/:id/leave`                      | Выйти                            | JWT    |
| GET    | `/channels/:id/members`                    | Участники                        | JWT    |
| PATCH  | `/channels/:id/members/:userId`            | Сменить роль                     | JWT    |
| GET    | `/channels/:id/posts`                      | Посты                            | JWT    |
| POST   | `/channels/:id/posts`                      | Создать пост                     | JWT    |
| DELETE | `/channels/:id/posts/:postId`              | Удалить пост                     | JWT    |
| PATCH  | `/channels/:id/posts/:postId/pin`          | Закрепить                        | JWT    |
| PATCH  | `/channels/:id/posts/:postId/like`         | Лайк                             | JWT    |
| GET    | `/channels/:id/posts/:postId/comments`     | Комментарии                      | JWT    |
| POST   | `/channels/:id/posts/:postId/comments`     | Добавить комментарий             | JWT    |
| DELETE | `/channels/:id/posts/:postId/comments/:cid`| Удалить комментарий              | JWT    |

### Messages (`/api/conversations` — диалоги)

| Метод  | Путь                                       | Что делает                       | Доступ |
|--------|--------------------------------------------|----------------------------------|--------|
| GET    | `/conversations`                           | Список диалогов                  | JWT    |
| POST   | `/conversations`                           | Создать групповой                 | JWT    |
| POST   | `/conversations/direct`                    | Создать/получить direct          | JWT    |
| GET    | `/conversations/:id`                       | Метаданные диалога               | JWT    |
| GET    | `/conversations/:id/messages`              | Сообщения                        | JWT    |
| POST   | `/conversations/:id/messages`              | Отправить                        | JWT    |
| POST   | `/conversations/:id/read`                  | Пометить прочитанным             | JWT    |
| GET    | `/conversations/:id/participants`          | Участники                        | JWT    |

### Friends (`/api/friends`)

| Метод  | Путь                              | Что делает                       | Доступ |
|--------|-----------------------------------|----------------------------------|--------|
| GET    | `/friends`                        | Мои друзья                       | JWT    |
| GET    | `/friends/requests/incoming`      | Входящие заявки                  | JWT    |
| GET    | `/friends/requests/outgoing`      | Исходящие заявки                 | JWT    |
| POST   | `/friends/requests`               | Отправить заявку                 | JWT    |
| POST   | `/friends/requests/:id/accept`    | Принять                          | JWT    |
| POST   | `/friends/requests/:id/reject`    | Отклонить                        | JWT    |
| DELETE | `/friends/requests/:id`           | Отозвать свою заявку             | JWT    |
| DELETE | `/friends/:userId`                | Удалить из друзей                | JWT    |

### Blocks (`/api/blocks`)

| Метод  | Путь                              | Что делает                       | Доступ |
|--------|-----------------------------------|----------------------------------|--------|
| GET    | `/blocks`                         | Список заблокированных           | JWT    |
| POST   | `/blocks`                         | Заблокировать (`{userId}`)       | JWT    |
| DELETE | `/blocks/:userId`                 | Разблокировать                   | JWT    |

### Notifications (`/api/notifications`)

| Метод  | Путь                               | Что делает                      | Доступ |
|--------|------------------------------------|----------------------------------|--------|
| GET    | `/notifications`                   | Лента                            | JWT    |
| GET    | `/notifications/unread-count`      | Сколько непрочитанных            | JWT    |
| GET    | `/notifications/settings`          | Настройки                       | JWT    |
| PATCH  | `/notifications/settings/:category`| Сменить настройку                | JWT    |
| POST   | `/notifications/read`              | Пометить прочитанными            | JWT    |
| DELETE | `/notifications/:id`               | Удалить                          | JWT    |
| POST   | `/notifications/register`          | Привязать push-токен             | JWT    |
| DELETE | `/notifications/:token`            | Отвязать push-токен              | JWT    |

### Gamification (`/api/gamification`)

| Метод | Путь                            | Что делает                          | Доступ |
|--------|---------------------------------|-------------------------------------|--------|
| GET    | `/gamification/me`              | XP, уровень, ранг текущего          | JWT    |
| GET    | `/gamification/points`          | Сколько начислено                   | JWT    |
| GET    | `/gamification/achievements`    | Список достижений                   | JWT    |

### Gear / Marketplace Equipment (`/api/gear`)

| Метод  | Путь                | Что делает                          | Доступ |
|--------|---------------------|-------------------------------------|--------|
| GET    | `/gear/mine`        | Моё снаряжение                      | JWT    |
| GET    | `/gear/:userId`     | Снаряжение пользователя             | JWT    |
| POST   | `/gear`             | Добавить                            | JWT    |
| PATCH  | `/gear/:id`         | Редактировать                       | JWT    |
| DELETE | `/gear/:id`         | Удалить                             | JWT    |

### News (`/api/news`)

| Метод  | Путь                | Доступ           |
|--------|---------------------|------------------|
| GET    | `/news`             | JWT              |
| GET    | `/news/:id`         | JWT              |
| POST   | `/news`             | JWT + admin role |
| PATCH  | `/news/:id`         | JWT + admin role |
| DELETE | `/news/:id`         | JWT + admin role |

### Ratings (`/api/ratings`)

| Метод | Путь                       | Доступ |
|--------|----------------------------|--------|
| GET    | `/ratings/leaderboard`     | JWT    |

### Admin (`/api/admin`) — только `admin`/`moderator`

| Метод  | Путь                              | Что делает                          |
|--------|-----------------------------------|-------------------------------------|
| GET    | `/admin/stats`                    | Сводные метрики                     |
| GET    | `/admin/users`                    | Поиск пользователей                 |
| PATCH  | `/admin/users/:id/role`           | Сменить роль                        |
| POST   | `/admin/users/:id/ban`            | Забанить                            |
| POST   | `/admin/users/:id/unban`          | Разбанить                           |
| GET    | `/admin/listings`                 | Объявления                          |
| PATCH  | `/admin/listings/:id/status`      | Сменить статус                      |
| GET    | `/admin/events`                   | Заплывы                             |
| PATCH  | `/admin/events/:id/status`        | Сменить статус                      |
| GET    | `/admin/tracks`                   | Треки                               |
| PATCH  | `/admin/tracks/:id/status`        | Сменить статус                      |
| GET    | `/admin/waterbodies`              | Водоёмы                             |
| POST   | `/admin/waterbodies`              | Создать водоём                      |
| PATCH  | `/admin/waterbodies/:id`          | Редактировать                       |
| PATCH  | `/admin/waterbodies/:id/active`   | Включить/выключить                  |
| DELETE | `/admin/waterbodies/:id`          | Удалить                             |

### Uploads (`/api/uploads`)

| Метод | Путь                  | Что делает                          | Доступ |
|--------|-----------------------|-------------------------------------|--------|
| POST   | `/uploads/image`      | Загрузить одну картинку             | JWT    |
| POST   | `/uploads/images`     | Загрузить несколько                 | JWT    |

### Health (`/api/health`)

| Метод | Путь       | Что делает                            | Доступ |
|--------|------------|---------------------------------------|--------|
| GET    | `/health`  | Статус + версия БД/PostGIS            | Public |

---

## Локальное хранение

### Что кешируется офлайн

- Маршруты (`routes`) — точки + дистанция + время.
- Избранные водоёмы, диалоги, сообщения.
- Список событий, лента.

### Что НЕ кешируется

- Аккаунт пользователя (всегда живые данные из `users`).
- Push-уведомления (загружаются с сервера при логине).

---

## Используемые пакеты

| Пакет                          | Версия   | Зачем                                      |
|--------------------------------|----------|--------------------------------------------|
| `flutter`                      | SDK ≥3.0 | Сам фреймворк                              |
| `provider`                     | 6.1.2    | `ChangeNotifier` + `MultiProvider`         |
| `http`                         | 1.2.2    | REST-запросы к backend                     |
| `hive` / `hive_flutter`        | 2.2.3    | Локальное хранилище (NoSQL)                |
| `flutter_secure_storage`       | 9.2.2    | refreshToken (Android Keychain)            |
| `shared_preferences`           | 2.3.2    | Простые настройки                          |
| `sqflite`                      | 2.3.3+1  | Быстрые SQL-вставки GPS-точек             |
| `path_provider`                | 2.1.4    | Каталог документов                         |
| `geolocator`                   | 13.0.1   | GPS-трекинг                                |
| `cached_network_image`         | 3.4.1    | Кеширование сетевых картинок               |
| `shimmer`                      | 3.0.0    | Скелетонная загрузка                       |
| `intl`                         | 0.19.0   | Форматирование дат/чисел                   |
| `cupertino_icons`              | 1.0.8    | Системные иконки                           |

---

## Лицензия

Proprietary. © SUP FUN, 2026.
