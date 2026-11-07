---
name: godot-apk-ci
description: "Build an Android debug APK in the cloud with GitHub Actions — export_presets.cfg template for Godot 4.7.2 (arm64-v8a, permissions, touch/screen options), workflow on the barichello/godot-ci container with an auto-generated debug.keystore, APK to Artifacts and to Releases on v* tags. Read before setting up or fixing the APK build."
argument-hint: "[setup | fix <what failed>]"
user-invocable: false
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(godot --headless *)
---

# Автосборка Android APK в облаке

Справочник для агентов. Шаблоны лежат в `templates/`:

- `export_presets.cfg` — пресет экспорта Android;
- `build-apk.yml` — вариант A: контейнер + `firebelley/godot-export`;
- `build-apk-container-only.yml` — вариант B: только контейнер.

> **Что проверено (2026-11-07), а что нет.**
>
> | Что | Как проверено |
> |---|---|
> | Пресет | Godot 4.7.2 его разбирает: экспорт остановился только на отсутствии шаблонов экспорта и Android SDK в контейнере разработки |
> | Имена опций пресета, переменные `GODOT_ANDROID_KEYSTORE_*` | найдены в бинарнике 4.7.2 |
> | Образ `barichello/godot-ci:4.7.2` | есть на Docker Hub; состав — по его Dockerfile: JDK 17, Android SDK `/usr/lib/android-sdk`, build-tools 33.0.2, `/root/debug.keystore`, `~/.config/godot/editor_settings-<major.minor>.tres` |
> | `firebelley/godot-export@v8.0.0` | входы взяты из его README и кода |
> | Сами workflow | **на GitHub не запускались.** Первый запуск через `workflow_dispatch` и есть проверка |
>
> Пока он не прошёл, не называй сборку рабочей.

## 1. Что сделать до первой сборки (каждый пункт — отдельное «May I write…»)

1. **`export_presets.cfg` в git.**
   - Сейчас он в `.gitignore` (строка `export_presets.cfg`), и CI его не увидит. Убери
     строку из `.gitignore` и положи пресет из `templates/` в корень проекта.
   - Пароли в пресет не пиши: поля `keystore/*` пустые, ключи приходят через переменные
     окружения.
2. **`package/unique_name`.**
   - В шаблоне стоит заглушка `com.example.kritproval`.
   - После первой публикации имя пакета не меняется никогда. Выбирает его пользователь.
3. **Настройки экрана в `project.godot`.**
   - Раздела `[display]` сейчас нет: портретную ориентацию и растяжение задай до сборки
     (скилл `tscn-handcrafter`, раздел 5).
   - Нужна и главная сцена `run/main_scene`, иначе APK запустится в пустоту.
4. **Workflow.** Скопируй выбранный шаблон в `.github/workflows/build-apk.yml`. Он
   запускается на каждый push в `main`, поэтому сначала договорись с пользователем.

## 2. Пресет `export_presets.cfg` (главное)

| Опция | Значение | Почему |
|---|---|---|
| `architectures/arm64-v8a` | `true` | все современные телефоны |
| `architectures/armeabi-v7a`, `x86`, `x86_64` | `false` | меньше APK; эмулятору x86_64 он нужен — включай только для теста |
| `gradle_build/use_gradle_build` | `false` | обычный шаблон, без Android build template и Gradle; для `.aab` в Google Play — `true` и `export_format=1` (отдельная задача) |
| `permissions/vibrate` | `true` | `Input.vibrate_handheld` (скилл `mobile-juice`) |
| `permissions/internet` | `false` | игре сеть не нужна; включишь — объясни зачем |
| `screen/immersive_mode` | `true` | полный экран для чтения |
| `screen/edge_to_edge` | `false` | пока не обработана безопасная зона: со значением `true` интерфейс уходит под вырез и системные панели (`mobile-ux-validator`) |
| `package/name` | «Критический провал» | имя под иконкой |
| `version/code` | `1`, затем +1 на каждый выпуск | Android сравнивает именно его |
| `keystore/*` | пусто | ключи берутся из `GODOT_ANDROID_KEYSTORE_DEBUG_*` / `_RELEASE_*` |
| `exclude_filter` | `*.md, tests/*, prototypes/*, production/*, design/*, docs/*` | документы и прототипы не попадают в APK |

Минимальный и целевой SDK у обычного шаблона задаёт сам шаблон 4.7.2. Какие это числа,
в `docs/engine-reference/godot/` не описано: `NOT SOURCEABLE`. Требования Google Play к
целевому SDK проверять перед публикацией, не по памяти.

## 3. Workflow: два варианта

Общее у обоих:

- образ `barichello/godot-ci:4.7.2`;
- запуск на push в `main`, на теги `v*` и вручную (`workflow_dispatch`);
- новый `debug.keystore` на каждый прогон (`keytool` есть в образе) и передача через
  `GODOT_ANDROID_KEYSTORE_DEBUG_PATH/USER/PASSWORD` в `$GITHUB_ENV`;
- APK — в Artifacts (`actions/upload-artifact@v4`), а на теге `v*` — ещё и в Release
  (`softprops/action-gh-release@v2`, нужно `permissions: contents: write`);
- в контейнерной задаче GitHub ставит `HOME=/github/home`, а образ хранит настройки под
  `/root`, поэтому первым шагом настройки переносятся.

| | A: `build-apk.yml` (как просил пользователь) | B: `build-apk-container-only.yml` (рекомендация) |
|---|---|---|
| Экспорт | `firebelley/godot-export@v8.0.0` внутри контейнера | `godot --headless --export-debug` прямо в контейнере |
| Загрузки за прогон | Godot (74 МБ) и **шаблоны экспорта 1,19 ГБ** — их уже содержит образ; `cache: true` смягчает | ничего |
| Настройки редактора | firebelley кладёт свой `editor_settings-4.tres`, только если файла нет; Godot 4.7 читает `editor_settings-4.7.tres` из образа | из образа |
| Где APK | `steps.export.outputs.build_directory` | `build/android/` |
| Лишние зависимости | ещё одно действие со своей версией | нет |

Пока пользователь не выбрал иначе, рабочий шаблон — вариант A (его просили). Вариант B
предложен как более простой. Решение за пользователем
(`CLAUDE.md`, «CEO & Devil's Advocate»).

## 4. Release-ключ (когда понадобится публикация)

Это не debug и не для CI по умолчанию.

1. Ключ создаёт пользователь у себя (`keytool -genkeypair …`).
2. Ключ кладётся в GitHub Secrets base64-строкой (`RELEASE_KEYSTORE_BASE64`, плюс
   `RELEASE_KEYSTORE_USER` и `RELEASE_KEYSTORE_PASSWORD`).
3. В workflow он декодируется во временный файл и передаётся через
   `GODOT_ANDROID_KEYSTORE_RELEASE_*`. Экспорт идёт с `--export-release`.

Ключ и пароли никогда не коммитятся и не печатаются в лог.

## 5. Если сборка упала

| Сообщение | Причина | Что делать |
|---|---|---|
| `No export template found at …/export_templates/4.7.2.stable/` | шаблоны не там, где ищет Godot | вариант B: проверь шаг переноса `/root/.local/share/godot/export_templates` в `$HOME`; вариант A: не стоит `godot_export_templates_download_url` |
| `Invalid Android SDK path in Editor Settings` | настройки редактора не в `$HOME/.config/godot` | шаг копирования `/root/.config/godot` |
| `Invalid export preset name` | `EXPORT_PRESET` ≠ `name=` в пресете | сверь имена |
| `Cannot export … configuration errors` без строки про шаблоны или SDK | ошибка в пресете | `godot --headless --path . --export-debug "Android" build/x.apk` локально покажет ту же ошибку |
| пустой APK или его нет | экспорт тихо не прошёл | вариант B ловит это шагом `test -s`; смотри лог Godot выше |

Правки CI проверяет `technical-director`. Первую рабочую сборку стоит установить на
телефон и снять скриншоты для `mobile-ux-validator`.
