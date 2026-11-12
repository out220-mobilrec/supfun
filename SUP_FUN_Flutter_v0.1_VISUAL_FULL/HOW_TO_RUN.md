# Как запустить SUP FUN Mobile App

## ✅ Приложение запущено в Chrome!

Приложение успешно скомпилировано и работает в браузере Chrome на `http://localhost:8080`.

## 🚀 Варианты запуска

### 1. Самый быстрый - через Chrome (Web)

```bash
cd D:\sup3\SUP_FUN_Flutter_v0.1_VISUAL_FULL
flutter run -d chrome --web-port=8080
```

Откроется новое окно Chrome с приложением.

### 2. Через готовый скрипт

```batch
cd D:\sup3\SUP_FUN_Flutter_v0.1_VISUAL_FULL
launch-app.bat
```

Или сразу с платформой:
```batch
launch-app.bat chrome    # Веб-версия
launch-app.bat edge      # Microsoft Edge
launch-app.bat android   # Android (требует SDK)
launch-app.bat windows   # Windows desktop
```

### 3. На Android-устройстве

Требуется установка **Android SDK** (не установлен в текущей среде):

1. Скачайте [Android Studio](https://developer.android.com/studio)
2. Установите Android SDK
3. Подключите устройство по USB (с включенной отладкой) ИЛИ запустите эмулятор
4. Выполните:
```bash
flutter doctor    # Проверка настройки
flutter devices   # Список устройств
flutter run -d android
```

### 4. Сборка APK для установки на Android

```bash
flutter build apk --release
```
APK будет создан в: `build/app/outputs/flutter-apk/app-release.apk`

## 📱 Что вы увидите после запуска

После запуска откроется **Splash Screen** (3 секунды), затем:

1. **Главная** - погода, события, активность
2. **Карта** - фильтры маршрутов и водоемов
3. **Трекинг** - GPS-запись заплыва (в вебе работает в демо-режиме)
4. **Результаты** - статистика и достижения
5. **Маркетплейс** - каталог снаряжения
6. **Профиль** - пользовательские данные
7. **Чаты** - диалоги с офлайн-сохранением
8. **Локальные данные** - управление кэшем

## 🛠 Возможные проблемы

### Android SDK не найден
```
[X] Android toolchain - develop for Android devices
    X Unable to locate Android SDK.
```
**Решение**: Установите Android Studio или задайте путь:
```bash
flutter config --android-sdk "C:\Users\admin\AppData\Local\Android\Sdk"
```

### Path provider не работает в вебе
В веб-версии локальное хранилище работает через IndexedDB (вместо файловой системы).

### Ошибки зависимостей
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📋 Команды для разработки

| Команда | Описание |
|---------|----------|
| `flutter run` | Запуск в режиме отладки |
| `flutter run --release` | Запуск release-версии |
| `flutter build apk` | Сборка APK |
| `flutter build appbundle` | Сборка AAB для Google Play |
| `flutter build web` | Сборка для веб |
| `flutter test` | Запуск тестов |
| `flutter analyze` | Анализ кода |
| `flutter clean` | Очистка кэша сборки |
| `flutter pub get` | Получить зависимости |

## 🎯 Следующие шаги

1. **Установите Android SDK** для запуска на реальном Android
2. **Подключите физическое устройство** или запустите эмулятор
3. **Используйте `launch-app.bat android`** для удобного запуска
4. **Соберите APK** для распространения: `flutter build apk --release`

**Приложение готово к запуску!**
