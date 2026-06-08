# Руководство по компиляции исходного кода Telegram для iOS

Мы приветствуем всех разработчиков, использующих наш API и исходный код для создания приложений на нашей платформе.
На данный момент мы предъявляем ряд требований ко **всем разработчикам**.

# Создание вашего приложения Telegram

1. [**Получите собственный api_id**](https://core.telegram.org/api/obtaining_api_id) для вашего приложения.
2. Пожалуйста, **не используйте** название Telegram для вашего приложения — или убедитесь, что пользователи понимают, что оно является неофициальным.
3. Пожалуйста, **не используйте** наш стандартный логотип (белый бумажный самолётик в синем круге) в качестве логотипа вашего приложения.
4. Пожалуйста, ознакомьтесь с нашими [**рекомендациями по безопасности**](https://core.telegram.org/mtproto/security_guidelines) и бережно относитесь к данным и конфиденциальности ваших пользователей.
5. Не забудьте опубликовать **ваш** код для соблюдения условий лицензий.

# Краткое руководство по компиляции

## Получение кода

```
git clone --recursive -j8 https://github.com/TelegramMessenger/Telegram-iOS.git
```

## Настройка Xcode

Установите Xcode (напрямую с https://developer.apple.com/download/applications или через App Store).

## Настройка конфигурации

1. Сгенерируйте случайный идентификатор:
```
openssl rand -hex 8
```
2. Создайте новый проект Xcode. Используйте `Telegram` в качестве названия продукта (Product Name). Используйте `org.{идентификатор из шага 1}` в качестве идентификатора организации (Organization Identifier).
3. Откройте `Keychain Access` и перейдите в раздел `Certificates`. Найдите `Apple Development: your@email.address (XXXXXXXXXX)` и дважды нажмите на сертификат. В разделе `Details` найдите `Organizational Unit` — это и есть Team ID.
4. Отредактируйте файл `build-system/template_minimal_development_configuration.json`, используя данные из предыдущих шагов.

## Генерация проекта Xcode

```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=build-system/template_minimal_development_configuration.json \
    --xcodeManagedCodesigning
```

# Расширенное руководство по компиляции

## Xcode

1. Скопируйте и отредактируйте файл `build-system/appstore-configuration.json`.
2. Скопируйте `build-system/fake-codesigning`. Создайте и загрузите профили подготовки (provisioning profiles), используя папку `profiles` в качестве справочника по правам доступа (entitlements).
3. Сгенерируйте проект Xcode:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=configuration_from_step_1.json \
    --codesigningInformationPath=directory_from_step_2
```

## IPA

1. Повторите шаги из предыдущего раздела. Используйте дистрибутивные профили подготовки (distribution provisioning profiles).
2. Выполните команду:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    build \
    --configurationPath=...см. предыдущий раздел... \
    --codesigningInformationPath=...см. предыдущий раздел... \
    --buildNumber=100001 \
    --configuration=release_arm64
```

# Часто задаваемые вопросы

## Xcode завис на "build-request.json not updated yet"

Иногда в журнале сборки может появиться следующее сообщение:
```
"/Users/xxx/Library/Developer/Xcode/DerivedData/Telegram-xxx/Build/Intermediates.noindex/XCBuildData/xxx.xcbuilddata/build-request.json" not updated yet, waiting...
```

Если это произошло, просто отмените текущую сборку и запустите новую.

## Telegram_xcodeproj: no such package

После перезагрузки системы автоматически сгенерированный проект Xcode может завершиться с ошибкой:
```
ERROR: Skipping '@rules_xcodeproj_generated//generator/Telegram/Telegram_xcodeproj:Telegram_xcodeproj': no such package '@rules_xcodeproj_generated//generator/Telegram/Telegram_xcodeproj': BUILD file not found in directory 'generator/Telegram/Telegram_xcodeproj' of external repository @rules_xcodeproj_generated. Add a BUILD file to a directory to mark it as a package.
```

Если вы столкнулись с этой проблемой, повторно выполните шаги по генерации проекта из README.

# Советы

## Подпись кода не требуется для сборок только под симулятор

Добавьте флаг `--disableProvisioningProfiles`:
```
python3 build-system/Make/Make.py \
    --cacheDir="$HOME/telegram-bazel-cache" \
    generateProject \
    --configurationPath=path-to-configuration.json \
    --codesigningInformationPath=path-to-provisioning-data \
    --disableProvisioningProfiles
```

## Версии

Каждый релиз собирается с использованием определённой версии Xcode (см. `versions.json`). Вспомогательный скрипт проверяет версии установленного программного обеспечения и сообщает об ошибке, если они не совпадают с указанными в `versions.json`. Эти проверки можно обойти:

```
python3 build-system/Make/Make.py --overrideXcodeVersion build ... # Не проверять версию Xcode
```