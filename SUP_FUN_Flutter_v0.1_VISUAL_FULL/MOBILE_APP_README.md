# SUP FUN Mobile App

Flutter приложение для SUP (Stand-Up Paddleboarding) сообщества.

## Структура проекта

```
lib/
├── main.dart                  # Точка входа, маршрутизация
├── theme/
│   └── app_theme.dart         # Тема приложения
├── models/
│   └── models.dart            # Модели данных (User, WaterBody, Trip, Event, Listing)
├── services/
│   └── api_service.dart       # HTTP клиент для API
└── screens/
    ├── splash_screen.dart     # Заставка с логотипом
    ├── home_screen.dart       # Главная (погода, события, активность)
    ├── map_screen.dart        # Карта водоемов с фильтрами
    ├── waterbody_screen.dart  # Детали водоема
    ├── prestart_screen.dart   # Чек-лист перед заплывом
    ├── tracking_screen.dart   # GPS-трекинг активного заплыва
    ├── result_screen.dart     # Результаты заплыва
    ├── marketplace_screen.dart # Маркетплейс снаряжения
    ├── community_screen.dart  # Лента сообщества
    └── profile_screen.dart    # Профиль пользователя
```

## 12 экранов приложения

| # | Экран | Назначение |
|---|-------|-----------|
| 1 | Splash | Заставка с логотипом и анимацией |
| 2 | Home | Главная: погода, события, активность друзей |
| 3 | Map | Интерактивная карта водоемов |
| 4 | Waterbody | Детальная информация о водоеме |
| 5 | Event | Детали заплыва/мероприятия |
| 6 | Prestart | Чек-лист снаряжения перед выходом |
| 7 | Tracking | GPS-трекинг в реальном времени |
| 8 | Result | Статистика завершенного заплыва |
| 9 | Route | Сохраненный маршрут |
| 10 | Marketplace | Объявления о продаже снаряжения |
| 11 | Profile | Профиль пользователя |
| 12 | Community | Лента активности сообщества |

## Используемые технологии

- **Flutter 3.x** - кроссплатформенный фреймворк
- **Provider** - управление состоянием
- **HTTP** - работа с API
- **Geolocator** - геолокация для трекинга
- **Shared Preferences** - локальное хранилище
- **Cached Network Image** - кэширование изображений
- **Shimmer** - эффекты загрузки
- **Intl** - локализация

## Установка и запуск

### Требования
- Flutter SDK 3.10+
- Dart SDK 3.0+
- Android Studio / VS Code
- Android SDK для Android-сборки

### Установка зависимостей

```bash
cd D:/sup3/SUP_FUN_Flutter_v0.1_VISUAL_FULL
flutter pub get
```

### Запуск в режиме разработки

```bash
flutter run
```

### Сборка для Android

```bash
# APK для разработки
flutter build apk --debug

# APK для релиза
flutter build apk --release

# App Bundle для Google Play
flutter build appbundle --release
```

### Подключение к API

API запускается на http://localhost:3000. Для эмулятора Android используйте:
```dart
static const String baseUrl = 'http://10.0.2.2:3000/api';
```

Для физического устройства - используйте IP-адрес компьютера в локальной сети.

## API Endpoints

| Метод | Endpoint | Описание |
|-------|----------|----------|
| POST | /auth/login | Авторизация |
| POST | /auth/register | Регистрация |
| GET | /waterbodies | Список водоемов |
| GET | /waterbodies/:id | Детали водоема |
| GET | /events | Список событий |
| POST | /events | Создать событие |
| GET | /trips | Список заплывов |
| POST | /trips | Сохранить заплыв |
| GET | /marketplace/listings | Объявления |
| GET | /feed | Лента активности |
| GET | /weather | Погода |

## Дизайн

### Цветовая палитра
- **Primary**: #00A6A6 (бирюзовый)
- **Secondary**: #FFB400 (янтарный)
- **Background**: #F4F8F7 (светло-серый)
- **Card**: #FFFFFF
- **Text Primary**: #1A2B3C
- **Text Secondary**: #6B7B8C

### Шрифт
Roboto (стандартный для Material Design 3)

## Следующие шаги

1. Добавить аутентификацию (JWT)
2. Интегрировать реальные карты (Google Maps или OSM)
3. Добавить push-уведомления
4. Реализовать оффлайн-режим
5. Добавить аналитику и трекинг ошибок
6. Создать админ-панель
