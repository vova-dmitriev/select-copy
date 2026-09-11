# SelectCopy — Design Specification

**Дата:** 2026-09-11
**Статус:** согласованный дизайн перед implementation plan

## 1. Цель

SelectCopy — фоновая macOS menu bar utility, которая автоматически копирует выделенный пользователем текст в системный буфер обмена. После успешного копирования приложение при необходимости показывает компактный toast с галочкой.

Приложение предназначено для публикации как open-source проект на GitHub и распространения в виде подписанных и notarized сборок.

## 2. Границы первой версии

Первая версия включает:

- автоматическое копирование после drag-выделения мышью;
- автоматическое копирование после двойного и тройного клика;
- автоматическое копирование после клавиатурного выделения через `Shift` и навигационные клавиши;
- обработку `Command+A` как явного выделения всего текста;
- получение текста через macOS Accessibility API;
- fallback через синтетический `Command+C` для совместимых текстовых элементов;
- toast успешного копирования;
- шесть позиций toast;
- режимы toast: локализованный текст, пользовательский текст, только иконка;
- включение и отключение toast;
- запуск при входе в систему;
- системный, русский и английский языки;
- onboarding для Accessibility permission;
- menu bar интерфейс без Dock-иконки;
- GitHub CI и подписанные notarized релизы.

Первая версия не включает:

- историю буфера обмена;
- синхронизацию или сетевые функции;
- правила для отдельных приложений и blocklist;
- пользовательскую настройку длительности toast;
- Mac App Store;
- автоматическое обновление через Sparkle;
- копирование изображений, файлов, ссылок как отдельных rich-типов или других нетекстовых объектов.

## 3. Платформа и технологии

- Минимальная версия: macOS 13 Ventura.
- Язык: Swift 6.
- Интерфейс: SwiftUI.
- Нативные интеграции: AppKit, ApplicationServices, CoreGraphics, ServiceManagement.
- Сборка: Xcode project и `xcodebuild`.
- Архитектуры релиза: `arm64` и `x86_64` в одном Universal Binary.
- Сторонние runtime-зависимости отсутствуют.
- App Sandbox отключён, потому что приложение использует глобальный Accessibility-доступ и event tap.
- Hardened Runtime включён для релизных сборок.
- `LSUIElement` установлен в `true`, поэтому приложение не появляется в Dock и переключателе приложений.

## 4. Архитектура

### 4.1 Компоненты

`SelectionMonitor`

- Создаёт глобальный CoreGraphics event tap.
- Отслеживает только события, необходимые для распознавания явного выделения.
- Формирует типизированный `SelectionGesture` после завершения жеста.
- Повторно включает event tap после `tapDisabledByTimeout` и `tapDisabledByUserInput`.
- Пересоздаёт монитор после пробуждения системы.

`SelectionGestureClassifier`

- Отличает drag от обычного одиночного клика по минимальному перемещению указателя.
- Распознаёт двойной и тройной клик по `clickState` события.
- Распознаёт завершение комбинаций `Shift+Arrow`, `Shift+Home`, `Shift+End`, `Shift+PageUp`, `Shift+PageDown` и `Command+A`.
- Не анализирует и не сохраняет обычные печатные клавиши.

`SelectionCopyCoordinator`

- Принимает `SelectionGesture`.
- Применяет debounce 100 мс после завершения жеста, чтобы целевое приложение обновило Accessibility tree.
- Отменяет предыдущую незавершённую попытку при поступлении нового жеста.
- Не обрабатывает события, синтезированные самим SelectCopy.
- Управляет основным потоком `AX read -> direct pasteboard write -> Command+C fallback -> toast`.

`AccessibilitySelectionReader`

- Получает системный wide element и focused UI element.
- Проверяет роль и subrole элемента.
- Немедленно отклоняет secure text fields.
- Читает `kAXSelectedTextAttribute` через `AXUIElementCopyAttributeValue`.
- Возвращает одно из типизированных состояний: непустой текст, пустое выделение, неподдерживаемый атрибут, secure element или ошибка.

`ClipboardClient`

- Инкапсулирует `NSPasteboard.general`.
- Выполняет прямую запись plain text.
- Считывает `changeCount`.
- Создаёт ограниченный snapshot существующих pasteboard items перед fallback.
- Восстанавливает snapshot, когда fallback заменил clipboard нетекстовым содержимым.

`CopyFallbackService`

- Запускается только после явного жеста выделения, для текстоподобной Accessibility-роли и результата `attributeUnsupported`/`notImplemented`.
- Сохраняет clipboard snapshot и `changeCount`.
- Отмечает синтетические события специальным `eventSourceUserData`.
- Эмулирует нажатие и отпускание `Command+C`.
- Ждёт до 250 мс изменения pasteboard без блокировки main thread.
- Принимает результат только при наличии непустого plain text.
- Восстанавливает snapshot, если clipboard изменился, но результат не является текстом.

`ToastCoordinator`

- Управляет единственным `NSPanel`.
- Новое успешное копирование заменяет текущий toast и перезапускает таймер.
- Скрывает toast через 1,2 секунды.
- Пересчитывает экран и позицию перед каждым показом.
- Закрывает toast при sleep и пересоздаёт его после wake при следующем копировании.

`SettingsStore`

- Хранит настройки в `UserDefaults` через типизированные ключи.
- Публикует изменения для SwiftUI и runtime-сервисов.
- Применяет безопасные значения по умолчанию при повреждённом или неизвестном значении.

`LoginItemService`

- Использует `SMAppService.mainApp` для регистрации и удаления login item.
- Отражает фактический `SMAppService.Status`, а не только сохранённое желание пользователя.
- Показывает локализованную ошибку и ссылку на System Settings, если системе требуется подтверждение.

`PermissionCoordinator`

- Проверяет доверие через `AXIsProcessTrusted`.
- На первом запуске объясняет назначение разрешения до системного prompt.
- Открывает правильный раздел System Settings, если разрешение отклонено или отозвано.
- Останавливает мониторинг, пока разрешение отсутствует.

`LocalizationService`

- Поддерживает `system`, `ru` и `en`.
- Обновляет menu bar, settings, onboarding и toast без перезапуска приложения.
- Использует String Catalog для всех встроенных строк.
- Никогда не переводит пользовательский текст toast.

### 4.2 Поток копирования

1. Event tap получает глобальное событие.
2. `SelectionGestureClassifier` либо игнорирует его, либо завершает явный жест выделения.
3. `SelectionCopyCoordinator` ждёт 100 мс.
4. `AccessibilitySelectionReader` проверяет focused element.
5. Если AX вернул непустой текст, `ClipboardClient` записывает plain text напрямую.
6. Если выделение пустое или поле secure, операция заканчивается без изменения clipboard и без toast.
7. Если AX не поддерживается, но роль текстоподобная, `CopyFallbackService` выполняет контролируемый `Command+C`.
8. Успех подтверждается записью AX-текста либо изменением `NSPasteboard.changeCount` с непустым plain text.
9. Если toast включён, `ToastCoordinator` показывает подтверждение.

Одинаковый текст копируется повторно после нового явного жеста. Дедупликация событий не должна блокировать намеренное повторное копирование.

## 5. Распознаваемые жесты

### Мышь и trackpad

- Drag считается кандидатом на выделение, когда указатель между mouse down и mouse up прошёл не менее 3 points.
- Двойной и тройной клик считаются кандидатами независимо от дистанции drag.
- Одиночный click без drag игнорируется.
- Drag-and-drop нетекстового объекта проходит классификацию, но заканчивается без fallback, если focused Accessibility element не является текстоподобным.

### Клавиатура

- `Shift` вместе со стрелками, Home, End, Page Up или Page Down запускает проверку после key up.
- Дополнительные модификаторы `Option` и `Command` разрешены вместе с `Shift` для выделения по словам, строкам и документу.
- `Command+A` запускает проверку после key up.
- Обычные символы, delete, function keys и shortcut-комбинации без выделения игнорируются.

## 6. Безопасность и приватность

- Secure text fields не читаются и не активируют fallback.
- Экран входа и lock screen не обрабатываются.
- SelectCopy игнорирует собственные окна и собственные синтетические события.
- Текст выделения не сохраняется на диск.
- История clipboard не создаётся.
- Текст, clipboard payload и пользовательский toast text не пишутся в логи.
- Диагностический лог ограничен типом события, результатом операции, AX error code и bundle identifier активного приложения.
- Сетевые запросы в runtime отсутствуют.
- Приложение не запускает fallback после обычного клика или для нетекстовой Accessibility-роли.

Полное покрытие всех приложений не гарантируется: некоторые приложения не публикуют выделение через Accessibility API и блокируют синтетический `Command+C`. Это ограничение отображается в README и troubleshooting.

## 7. Toast

Toast реализуется как borderless non-activating `NSPanel`:

- `canBecomeKey = false`;
- не перехватывает фокус;
- игнорирует мышь;
- отображается поверх обычных окон;
- доступен на текущем Space;
- использует системные light/dark appearance, material, тень и reduced motion;
- не использует системный notification center и не требует notification permission.

### Содержимое

Доступны три режима:

1. `localizedText`: галочка и локализованная строка `Скопировано`/`Copied`.
2. `customText`: галочка и пользовательская строка длиной не более 60 Unicode characters.
3. `iconOnly`: компактный квадратный toast только с галочкой.

Пустой `customText` отображается как `iconOnly`, но сохранённый режим не изменяется. Возврат текста сразу восстанавливает custom preview.

### Положение

Перед каждым показом выбирается экран, на котором находился указатель при завершении выделения. Если экран определить невозможно, используется `NSScreen.main`.

Toast располагается внутри `visibleFrame` с отступом 20 points:

- top leading;
- top center;
- top trailing;
- bottom leading;
- bottom center;
- bottom trailing.

При изменении конфигурации экранов открытый toast скрывается; следующий toast использует новую геометрию.

## 8. Визуальный стиль и иконка

Выбран вариант A: clipboard с галочкой.

- App icon: скруглённая macOS-иконка с крупным читаемым clipboard и контрастной галочкой; сохраняет узнаваемость на размерах от 16 до 1024 px.
- Menu bar icon: отдельный монохромный template asset без цветного фона и мелких декоративных деталей.
- Toast icon: SF Symbol `checkmark.circle.fill` или эквивалентный нативный символ.
- Иконка не содержит текста и не зависит от выбранного языка.
- Все состояния проверяются в light mode, dark mode и increased contrast.

## 9. Menu bar, onboarding и настройки

### Menu bar

`MenuBarExtra` показывает:

- статус `Работает`/`Active` при доступном Accessibility permission;
- предупреждение и действие открытия System Settings при отсутствии permission;
- действие открытия Settings;
- действие показа тестового toast;
- действие Quit.

Автокопирование активно всегда, пока приложение запущено и permission доступен. Отдельный pause-toggle не входит в первую версию.

### Первый запуск

Onboarding:

1. Кратко объясняет автоматическое копирование и отсутствие clipboard history.
2. Объясняет необходимость Accessibility permission.
3. По явному действию пользователя вызывает системный Accessibility prompt.
4. После выдачи разрешения запускает монитор и предлагает показать тестовый toast.

Если permission не выдан, menu bar и Settings остаются доступны, но монитор событий не работает.

### Настройки

Настройки содержат:

- checkbox `Запускать при входе в систему`;
- checkbox `Показывать уведомление о копировании`;
- picker из шести позиций toast;
- picker режима содержимого toast;
- однострочное поле пользовательского текста, активное для `customText`;
- живой preview и кнопку повторного показа toast;
- picker языка: `Как в системе`, `Русский`, `English`;
- состояние Accessibility permission и кнопку открытия System Settings;
- версию приложения и ссылку на GitHub.

Значения по умолчанию:

- launch at login: off;
- toast enabled: on;
- toast position: top trailing;
- toast content: localized text;
- custom toast text: empty;
- language: system.

## 10. Ошибки и восстановление

- AX error не завершает приложение; операция копирования пропускается и логируется без содержимого.
- Отозванный permission останавливает монитор и обновляет status UI.
- Event tap автоматически повторно включается после системного отключения; если повторное включение не удалось, монитор пересоздаётся.
- Clipboard fallback имеет timeout 250 мс и не блокирует main thread.
- Ошибка регистрации login item возвращает switch к фактическому состоянию и показывает локализованное сообщение.
- Ошибка создания toast не влияет на успешное копирование.
- После sleep/wake заново проверяются permission, event tap и список экранов.

## 11. Тестирование

### Unit tests

- классификация drag, click count и клавиатурных комбинаций;
- debounce и отмена предыдущей операции;
- фильтрация secure и нетекстовых ролей;
- решения direct AX write/fallback/no-op;
- предотвращение feedback loop;
- сериализация и значения по умолчанию настроек;
- locale resolution и fallback на системный язык;
- вычисление шести toast positions;
- ограничение пользовательского текста до 60 characters.

### Integration tests

- прямое копирование строки в pasteboard;
- ожидание `changeCount` после fallback;
- восстановление clipboard после нетекстового fallback;
- регистрация и удаление `SMAppService.mainApp` через инъецируемый adapter;
- выбор экрана и visible frame;
- жизненный цикл единственного toast panel.

### UI tests

- onboarding без permission и после его выдачи;
- изменение каждого setting;
- немедленное переключение языка;
- preview трёх режимов toast;
- недоступность custom text field вне соответствующего режима.

### Ручная матрица

- Safari, Chrome и Firefox;
- TextEdit, Notes и Mail;
- VS Code и другое Electron-приложение;
- Terminal и iTerm2;
- Preview с обычным PDF;
- Finder как отрицательный сценарий;
- несколько мониторов, Spaces и разные scale factors;
- light mode, dark mode, increased contrast и reduced motion;
- VoiceOver;
- sleep/wake и отзыв Accessibility permission во время работы.

## 12. GitHub и релизы

- Имя приложения: `SelectCopy`.
- Предлагаемое имя репозитория: `select-copy`.
- Лицензия: MIT.
- Основная ветка защищена обязательным CI.
- Pull request workflow выполняет SwiftFormat check, SwiftLint, unit tests и build на поддерживаемой версии Xcode.
- Release workflow собирает Release configuration как Universal Binary.
- Приложение подписывается сертификатом Developer ID Application.
- Notarization выполняется через `notarytool`, затем ticket прикрепляется через `stapler`.
- GitHub Release содержит `.dmg`, `.zip`, SHA-256 checksums и release notes.
- Сертификат, пароль сертификата, App Store Connect key, key ID и issuer ID хранятся только в GitHub Actions Secrets.
- README содержит установку, permission flow, troubleshooting, privacy statement, ограничения, инструкции сборки и release verification.
- Автообновление не входит в первую версию; обновления устанавливаются вручную из GitHub Releases.

## 13. Критерии готовности первой версии

Версия готова, когда:

- на macOS 13+ выделенный текст автоматически попадает в clipboard в поддерживаемой ручной матрице;
- secure fields и обычные одиночные клики не изменяют clipboard;
- fallback никогда намеренно не оставляет в clipboard нетекстовый результат;
- toast корректно работает во всех шести позициях и на нескольких экранах;
- настройки и язык сохраняются и применяются без перезапуска;
- login item отражает фактическое состояние системы;
- приложение не хранит и не логирует скопированный текст;
- CI проходит, Universal Binary подписан, notarized и опубликован с checksum;
- README честно описывает permission и ограничения совместимости.

## 14. Ссылки Apple

- [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [NSPasteboard](https://developer.apple.com/documentation/appkit/nspasteboard)
- [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)
- [AXUIElementCopyAttributeValue](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue)
