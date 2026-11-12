# SUP FUN Mobile App - Android Build Guide

## Созданная структура приложения

Flutter приложение SUP FUN полностью готово с 12 экранами согласно прототипам.

### Реализованные экраны:

| # | Файл | Описание |
|---|------|----------|
| 1 | `lib/screens/splash_screen.dart` | Заставка с логотипом и анимацией |
| 2 | `lib/screens/home_screen.dart` | Главная: погода, события, активность |
| 3 | `lib/screens/map_screen.dart` | Интерактивная карта с фильтрами |
| 4 | `lib/screens/waterbody_screen.dart` | Детали водоема с прогнозом погоды |
| 5 | `lib/screens/prestart_screen.dart` | Чек-лист снаряжения (6 пунктов) |
| 6 | `lib/screens/tracking_screen.dart` | GPS-трекинг с таймером и скоростью |
| 7 | `lib/screens/result_screen.dart` | Результаты с статистикой |
| 8 | `lib/screens/marketplace_screen.dart` | Каталог снаряжения |
| 9 | `lib/screens/community_screen.dart` | Лента сообщества |
| 10 | `lib/screens/profile_screen.dart` | Профиль пользователя |

### Архитектура:

```
lib/
├── main.dart              # Маршрутизация всех экранов
├── theme/app_theme.dart   # Тема с цветами бренда
├── models/models.dart     # 7 моделей данных
├── services/api_service.dart  # HTTP клиент
└── screens/               # 10 экранов
```

### Поддержка Android:

- `android/build.gradle` - настройки сборки
- `android/app/src/main/AndroidManifest.xml` - разрешения:
  - GPS / местоположение
  - Интернет
  - Камера
  - Фоновое отслеживание
  - Уведомления

## Запуск

### 1. Получить зависимости
```bash
cd D:\sup3\SUP_FUN_Flutter_v0.1_VISUAL_FULL
flutter pub get
```

### 2. Запустить на эмуляторе Android
```bash
flutter run -d android
```

### 3. Собрать APK
```bash
flutter build apk --release
```

APK будет создан в: `build/app/outputs/flutter-apk/app-release.apk`

## Подключение к API

Backend сервер работает на `http://localhost:3000`. Для Android-эмулятора замените в `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'http://10.0.2.2:3000/api';  // Для эмулятора
// или для физического устройства:
// static const String baseUrl = 'http://192.168.1.X:3000/api';
```

## Особенности UI

- **Цветовая схема**: бирюзовый #00A6A6 (основной), янтарный #FFB400 (акцент)
- **Material Design 3** с адаптивными компонентами
- **Кастомные виджеты** для карты, погоды, статистики
- **Анимации**: Splash, переходы, эффекты загрузки
- **Локализация**: русский язык по умолчанию
