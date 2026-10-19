# OpenVK Messenger (Native Swift: macOS & iOS)

<div align="center">

![OpenVK Messenger Banner](https://raw.githubusercontent.com/openvk/openvk/master/public/assets/packages/static/openvk/img/logo_big.png)

### Нативный и производительный клиент OpenVK на Swift 6 & SwiftUI

[![Swift](https://img.shields.io/badge/Swift-6.0%20%7C%205.10-F05138?logo=swift&logoColor=white)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue?logo=apple&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![macOS](https://img.shields.io/badge/macOS-12.0%2B%20(Monterey%20--%20Sequoia)-black?logo=apple&logoColor=white)](#поддерживаемые-платформы)
[![iOS](https://img.shields.io/badge/iOS-16.0%2B-black?logo=apple&logoColor=white)](#поддерживаемые-платформы)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

---

## 📖 О проекте

**OpenVK Messenger** — полностью нативный клиент для социальной сети [OpenVK](https://github.com/openvk/openvk), разработанный на **Swift** и **SwiftUI** с применением дизайн-системы **VKUI Milkshake** и эстетики классического **VK Messenger 3.9.0**.

Приложение создано с максимальным соблюдением Human Interface Guidelines от Apple, поддерживает как **macOS** (десктоп с поддержкой разделения экранов, многооконности и горячих клавиш), так и **iOS / iPadOS** (адаптивная мобильная версия, жестовая навигация, фоновое воспроизведение медиа).

---

## ✨ Основные возможности

### 💬 Сообщения и чаты
- **Адаптивные баблы сообщений**: баблы динамически подстраиваются под размер содержимого без растягивания на всю ширину экрана.
- **Редактирование сообщений**: быстрое редактирование отправленных сообщений с плашкой предпросмотра (`Esc` — отмена, `Enter` / кнопка — сохранить).
- **Удаление сообщений**: удаление сообщений для себя или для всех участников чата.
- **Упоминания и пинги (@mentions)**:
  - Автоматическое форматирование синтаксиса `[id123|Имя]` в кликабельные `@Имя`.
  - Уникальный цвет имени автора сообщения в групповых беседах.
  - Подсветка сообщений с пингом текущего пользователя.
  - Значок собаки `@` в списке диалогов рядом со счетчиком непрочитанных сообщений при наличии входящего пинга.
- **Закрепленные сообщения** (`PinnedMessageBarView`): быстрый просмотр и переход к закрепленному сообщению в диалоге.
- **Индикаторы онлайн и набора текста**: отображение статуса собеседника в реальном времени (включая иконку мобильного устройства для сессий со смартфонов).

### 🎨 Дизайн-система VKUI & Telegram Theme Engine
- **Дизайн-система VKUI Milkshake**:
  - Фирменные цвета VK (`#0077FF`, `#F0F1F4`, `#CCE4FF`, бейджи `#4BB34B`).
  - Полная поддержка темной и светлой темы macOS / iOS.
- **Импорт тем Telegram Desktop (`.tdesktop-theme`)**:
  - Чтение и парсинг палитры цветов Telegram (включая hex-цвета с прозрачностью `#RRGGBBAA`).
  - Распаковка и наложение кастомных фонов и фоновых узоров (doodles).
  - Настройка эффекта размытия (blur) и прозрачности подложки чата.
- **Кастомизация баблов**: выбор толщины и цвета контура (обводки) сообщений в настройках.

### 🎵 Медиа и плееры
- **Музыкальный плеер в стиле Telegram (`AudioPlayerService`)**:
  - Компактный миниплеер над списком чатов.
  - Управление воспроизведением, прогресс-бар, плейлист прикрепленных аудиозаписей.
  - Поддержка фонового воспроизведения (`audio` background mode на iOS).
- **Встроенный видеоплеер (`VideoPlayerService` / AVPlayer)**:
  - Воспроизведение видео со звуковыми дорожками.
  - Полноэкранный режим, управление громкостью и таймлайном.
- **Просмотр фотографий (`PhotoViewerService`)**: полноэкранная галерея вложений с зумом и сохранением.
- **Анимированные стикеры и GIF**: поддержка Lottie-анимаций для стикеров OpenVK и рендеринг анимированных GIF.

### 👥 Мультиаккаунт и сообщества
- **Банк аккаунтов (`AccountBankModalView`)**: быстрое переключение между несколькими учетными записями OpenVK в один клик.
- **Сообщения сообществ (`CommunityMessagesModalView`)**: общение и ответы от имени групп и публичных страниц.
- **Папки диалогов (`FolderManagerModalView`)**: группировка чатов по вкладкам (Личные, Беседы, Каналы, Работа).

### ⚡ Производительность и интеграция с ОС
- **Сверхбыстрая работа**: отсутствие веб-оберток (Electron/WebView) — чистый нативный бинарник.
- **Умный кэш изображений (`VKImageCache`)**: диск + оперативная память с автоматической очисткой.
- **Real-time LongPoll**: интеграция с API OpenVK v5.x и микросервисом `openvk-im` (`/nim`).
- **Drag & Drop и хоткеи**: поддержка системных шорткатов на macOS и перетаскивания файлов прямо в чат.

---

## 🖥 Поддерживаемые платформы

| Платформа | Минимальная версия | Архитектура | Описание |
| :--- | :---: | :---: | :--- |
| **macOS** | **12.0+** (Monterey, Ventura, Sonoma, Sequoia) | Apple Silicon (arm64) & Intel (x86_64) | Полнофункциональный десктопный клиент со Split View, меню бара и хоткеями |
| **iOS / iPadOS** | **16.0+** | arm64 | Адаптированный интерфейс для iPhone и iPad, жестовая навигация, фоновый звук |

---

## 🛠 Стек технологий

- **Язык**: [Swift](https://swift.org) (Swift 5.10 / 6.0)
- **UI Фреймворк**: [SwiftUI](https://developer.apple.com/xcode/swiftui/) + Combine
- **Медиа**: AVFoundation, AVPlayer
- **Анимации**: [Lottie-spm](https://github.com/airbnb/lottie-spm.git) (анимированные стикеры)
- **Сетевой слой**: URLSession, WebSockets / LongPoll (OpenVK-IM)
- **Управление проектом**: Swift Package Manager (`Package.swift`) + [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`)

---

## 🚀 Сборка и запуск проекта

### Вариант 1. Открытие в Xcode (macOS & iOS)

Проект настроен через **XcodeGen** и **Swift Package Manager**.

1. Убедитесь, что установлен Xcode 15 или новее:
   ```bash
   xcode-select -p
   ```
2. Генерация или открытие проекта:
   ```bash
   cd "/Users/alexs/Documents/OpenVK Messenger"

   # Открыть готовый Xcode проект:
   open "OpenVK Messenger.xcodeproj"

   # Либо открыть проект напрямую через Swift Package Manager:
   open Package.swift
   ```
3. В Xcode выберите схему:
   - **`OpenVK Messenger`** — для запуска на macOS (`⌘R`).
   - **`OpenVK Messenger iOS`** — для запуска в симуляторе или на устройстве iPhone / iPad (`⌘R`).

---

### Вариант 2. Сборка из терминала (macOS)

```bash
cd "/Users/alexs/Documents/OpenVK Messenger"

# Сборка и запуск приложения для macOS:
swift run
```

---

### Вариант 3. Сборка IPA для iOS

Для генерации `.ipa` файла для установки через AltStore, TrollStore, Sideloadly или Xcode:

```bash
cd "/Users/alexs/Documents/OpenVK Messenger"

# Генерация xcodeproj через xcodegen (если требуется обновить)
xcodegen generate

# Сборка архива под iOS:
xcodebuild -project "OpenVK Messenger.xcodeproj" \
  -scheme "OpenVK Messenger iOS" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/OpenVK_iOS.xcarchive \
  archive \
  CODE_SIGNING_ALLOWED=NO

# Упаковка в .ipa:
mkdir -p build/Payload
cp -R "build/OpenVK_iOS.xcarchive/Products/Applications/OpenVK Messenger.app" build/Payload/
cd build && zip -r -9 OpenVK.ipa Payload && rm -rf Payload
```

---

## 📁 Архитектура и структура проекта

```text
Sources/OpenVKMessenger/
├── OpenVKMessengerApp.swift      # Главная точка входа приложения (@main)
├── Models/
│   └── Models.swift              # Модели API OpenVK (User, Conversation, Message, Attachments)
├── Services/
│   ├── OpenVKAPIService.swift    # REST API OpenVK (v5.x эндпоинты)
│   ├── OpenVKLongPollService.swift # Real-time подписка на события OpenVK-IM
│   ├── MessengerStore.swift      # Центральный реактивный Store приложения
│   ├── AudioPlayerService.swift  # Сервис воспроизведения аудио и плейлистов
│   ├── VideoPlayerService.swift  # Сервис видеоплеера
│   ├── PhotoViewerService.swift  # Сервис просмотра полноразмерных фото
│   └── VKImageCache.swift        # Локальное кэширование аватарок и вложений
├── VKUI/
│   ├── VKDesignTokens.swift      # Палитра VKUI Milkshake, шрифты, отступы
│   ├── VKComponents.swift        # Базовые UI-компоненты (аватарки, репосты, бейджи)
│   ├── ThemeManager.swift        # Менеджер тем и настроек внешнего вида
│   ├── TelegramThemeImporter.swift # Парсер файлов тем .tdesktop-theme
│   └── PlatformCompat.swift      # Кроссплатформенные мосты (AppKit / UIKit)
└── Views/
    ├── MainView.swift            # Главное Split-View окно (macOS)
    ├── iOSMainView.swift         # Главный NavigationStack интерфейс (iOS)
    ├── ConversationsSidebarView.swift # Список диалогов и чатов
    ├── ChatView.swift            # Экран активного чата
    ├── MessageRowView.swift      # Строка сообщения и баблы
    ├── WriteBarView.swift        # Поле ввода, прикрепление файлов, запись аудио
    ├── TelegramAudioMiniplayerView.swift # Музыкальный миниплеер
    ├── VideoPlayerWindowView.swift       # Окно воспроизведения видео
    ├── PhotoViewerWindowView.swift       # Окно просмотра изображений
    ├── AccountBankModalView.swift        # Окно мультиаккаунта
    └── SettingsModalView.swift   # Экран настроек сервера, токена и тем
```

---

## 🤝 Вклад в проект (Contributing)

Пулл-реквесты приветствуются!  
1. Форкните репозиторий.
2. Создайте свою ветку (`git checkout -b feature/cool-feature`).
3. Закоммитьте изменения (`git commit -m 'Add cool feature'`).
4. Запушьте ветку (`git push origin feature/cool-feature`).
5. Откройте **Pull Request**.

---

## 📄 Лицензия

Проект распространяется под лицензией **MIT**. Подробности в файле [LICENSE](LICENSE).
