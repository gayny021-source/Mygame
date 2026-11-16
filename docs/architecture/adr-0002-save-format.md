# ADR-0002: Формат и запись сохранения

## Status
Accepted (2026-11-16; техническое решение, утвердил Зам от имени студии; пункты NOT SOURCEABLE закрывает история SV1–SV4 и устройство, см. Engine Compatibility)

## Date
2026-11-16

## Last Verified
2026-11-16 (против `design/gdd/save-system.md` правила 1–16, F1–F6, AC; `run-state.md` правила 11; `d20-checks.md` правило 10; ADR-0001 §«Сырой Dictionary»; код `src/core/{state,story,checks}`; headless-пробы 4.7.2)

## Decision Makers
`technical-director` (автор), Зам (утверждение). Исполнители — `gameplay-programmer`, `godot-gdscript-specialist`, `gut-test-engineer`.

## Summary
Слот сохранения — заголовок 48 байт + JSON-тело; два слота поколений на ключ файла, перезапись на месте без `rename`. Вся логика (кодек, очередь, тайм-ауты) — чистые `RefCounted` в главном потоке; поток (`WorkerThreadPool`, одна задача) только исполняет ввод-вывод `SaveIo`. Решены четыре дефекта GDD до кода (B1–B4, ниже).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7 (установлен 4.7.2) |
| **Domain** | Core (сохранение, ввод-вывод) |
| **Layer** | Foundation |
| **Knowledge Risk** | HIGH |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`; `breaking-changes.md` (`FileAccess.store_*` возвращают `bool` с 4.4 — код записи проверяет возврат); `modules/random.md` (JSON теряет точность 64-битного `state`). Про `Thread`, `WorkerThreadPool`, `HashingContext`, запись `FileAccess`, `user://` на Android справка молчит |
| **Post-Cutoff APIs Used** | None по замыслу; используются API 4.0–4.4 |
| **Verification Required** | Таблица ниже |

### NOT SOURCEABLE — справка этого не покрывает
Ничего не взято из памяти модели. «Проба» = headless 4.7.2 Linux, 2026-11-16; «устройство» = только Android-телефон.

| Что | Статус |
|---|---|
| `WorkerThreadPool.add_task` пишет в `user://` (204 800 байт, `store_buffer` = `true`); `is_task_completed` не блокирует; `wait_for_task_completion` = OK | Закрыто пробой (Linux). Android — устройство |
| `FileAccess.open(WRITE)` обнуляет файл при открытии; неверный путь — `null`, `get_open_error` = 7 | Закрыто пробой. Следствие: запись на месте не атомарна, пара поколений обязательна |
| `HashingContext` SHA-256 ("abc") = эталон `ba7816bf…15ad` | Закрыто пробой |
| `JSON.parse_string` на битом тексте печатает ERROR; `JSON.new().parse` молчит (код 43); числа — `float` | Закрыто пробой; разбор только `JSON.new().parse` (как ADR-0001) |
| `PackedByteArray.encode_u32/u64`, `decode_*`: круг точен до 2^53 − 1 | Закрыто пробой; `gen` ограничен 2^53 − 1 |
| Время записи 32 КБ — 26 мкс, 200 КБ — 97 мкс (без fsync) | Проба только Linux; Android и слабый телефон — устройство (AC-47) |
| `FileAccess` в рабочем потоке и `user://` на Android | Только устройство |
| Сброс на диск при потере питания (AC-57) | Только устройство |
| Ход монотонных часов в фоне (Э-22, AC-21) | Только устройство |
| `quit()` при зависшей задаче `WorkerThreadPool` (ANR) | Открыто: проба «долгая задача + quit». До неё не ждать задачу старше `wait_ms` |
| `JSON.stringify` + SHA-256 на ≈195 КБ на слабом телефоне (F5) | Только устройство |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (`DictReader`, `ChapterLoader.read_object`, правило: в сохранении только `id`) |
| **Enables** | Истории SV1–SV4; Выбор, Цель главы, Схема главы, Галерея, Меню (коммиты 4, 5 и экраны) |
| **Blocks** | SV1–SV4 до `Accepted` (выполнено) |
| **Ordering Note** | `format_version` 1 замораживается с первым APK для игроков; до него формат меняется без миграций |

## Context
GDD «Сохранение» оставляет ADR: `T_ожид`, поток и сброс на диск, имена файлов и классов (`save-system.md` ≈57, 61, 200, 365). Требования: главный поток жив при висящей записи (правило 7, Э-18, Э-20, AC-21, AC-52, AC-63), иначе `TIMEOUT` недостижим, а зависшая запись — ANR. Синхронная запись по бюджету F5 проходит, но не решает этого. Логика очереди должна тестироваться юнит-тестами без потоков.

## Decision

### 1. Классы (`src/core/save/`), всё — `RefCounted`, кроме `SaveNode`
- `SaveCodec` (static): `encode(version, gen, body) -> PackedByteArray`; `decode(bytes, slot, app_version, expect_hero) -> SlotRead {VALID|INVALID|TOO_NEW, version, gen, body}`; `pick(a, b) -> Pick {OK|EMPTY|CORRUPT|TOO_NEW, slot, gen_max}` (F1/F2; одинокий неверный `_b` → EMPTY, `_a` → CORRUPT; `gen_max` учитывает TOO_NEW-слот, AC-43). При TOO_NEW тело не разбирается.
- `RunBody` — единственный владелец сырого тела прохождения; читает только `DictReader` и `RunState/StoryPosition/RollRecord.from_dict`.
- `SaveWriter` — очередь, поколения, пара, тайм-ауты, загрузка. `SaveIo` — база из трёх методов (`start_write`, `start_read`, `poll`); `ThreadSaveIo` — одна задача `WorkerThreadPool` за раз; `FakeSaveIo` — фикстура тестов.
- `RunSession` (сторона Истории) — владелец commit 1, 2, 6 (позже 4, 5), замыкание для 3 и 7. `SaveNode` (`Node`) — единственное место с `Time.get_ticks_msec` и `_process`, зовёт `pump(now_ms)`.
- Навигатор и `CheckTurn` не меняются.

### 2. Формат слота
- Заголовок 48 байт: `KPSV` (4) + `format_version` u32 LE (4) + `gen` u64 LE (8) + SHA-256 (32) по байтам 4…15 и телу. Тело — UTF-8 JSON.
- `gen` и `format_version` — только в заголовке; в теле поля `gen` нет (AC-61).
- Слот верен: метка, версия и `gen` читаются, `gen % 2` = номеру слота, сумма сошлась, `body.hero` = `expect_hero`. У TOO_NEW проверка по заголовку.
- Файлы: `user://run_<hero>_a.sav` / `_b.sav`; `gallery`, `settings` — те же слоты своих ключей. `hero_id` проверяется `DictReader.is_id` до подстановки в путь. Слот поколения `gen % 2`; пишется всегда слот, не держащий новейшее верное поколение. `rename` не используется.
- Числа тела — малые целые; 64-битных значений в JSON нет (ADR-0001).

### 3. Тело v1
`{run_id, hero, resume:{state, position}, schema:[{state, position}], chapter_map?, roll?}`.
- `resume.state` и `schema[].state` = `RunState.to_dict()`: `flags` (id стоящих), `journal` [{flag, action, scene, outcome}]. Ничего больше (B4).
- `position` = `StoryPosition.to_dict()`; `roll` = `RollRecord.to_dict()` как есть, **без `state` генератора** (B1).
- Лишний ключ — отказ загрузки (`DT-04`); неизвестный `format_version` новее приложения — TOO_NEW.

### 4. Поток и запись
- Байты уходят в `SaveIo` готовыми; сериализация и SHA-256 — в главном потоке в момент `commit` (AC-15). Поток — исполнитель на ≈30 строк.
- Одна упорядоченная очередь; глубина 1 на ключ файла, вытеснение на месте, билеты вытесненного завершаются исходом вытеснившего; переход 6 — неделимая пара. `gen` назначается при старте записи: `gen_ok[ключ] + 1`; `gen_ok` растёт только по `OK`. Неизвестный `gen_ok` — первый шаг задания: чтение обоих слотов и `pick`.
- `wait_ms` (`T_ожид`) = **2000** мс (кандидат GDD; допустимо 500…5000; пересмотр по AC-47/48 на устройстве). Источник — `assets/data/config/save.json` через `ChapterLoader.read_object` + `DictReader` → `SaveConfig.from_dict`.
- `TIMEOUT`: `now − t_enqueue ≥ wait_ms`, один сигнал на билет; `LOAD_TIMEOUT`: `now − max(t_token, t_last_done) ≥ wait_ms`. Часы — внедряемые.
- Миграции — только в памяти, цепочка `Dictionary[int, Callable]` (в игре пуста), файл при загрузке не меняется (инвариант 5 DD-008).

### 5. Решения по дефектам GDD (B1–B4)
- **B1.** Поле `state` генератора в записи о броске **не пишется**. `RollRecord` его не хранит (d20 правило 10); `RollRecord.from_dict` отвергает лишний ключ (DT-04). Правило 2 (строка `state`) и AC-04 заменяются; последовательность сбрасывается при запуске процесса (d20), детерминизм тестов не страдает.
- **B2.** commit 1 вызывается только `RunSession` после возврата `advance()`/`outcome_applied()` видом `SCENE`, не из `_enter_scene`. `resume` при загрузке, экран `ERROR` и отказ (`null`) не пишут (инвариант 5, AC-38).
- **B3.** Флаг в снимке, не объявленный у героя (удалён из данных), **не отказ**: по `run-state.md` AC-24 и Edge Case `RunState.from_dict` отбрасывает флаг и его записи журнала, логирует `id` один раз, прохождение продолжается; флаги `устарел` восстанавливаются. Отказ по id остаётся только для сцен и исходов (правило 8, п. 6). Восстановление присваивает `_active/_journal` напрямую, мимо `apply_outcome`. Предложение схемы Opus (отказ) отвергнуто: дизайн уже решён.
- **B4.** До истории «Цель главы» тело **не содержит** `status`, `start`, `milestone_max` (в `RunState` их нет, YAGNI, непрозрачных заготовок не вводим). Их добавляет своя история: ключ в `to_dict`/`from_dict` и в этот ADR одним изменением; `format_version` остаётся 1 до первого APK (без миграции), после — шаг миграции. Статус — история Концовки.

### 6. Закрытый список сырого словаря (дополнение ADR-0001)
Входы: `RunState.from_dict`, `RunBody`, `SaveConfig.from_dict`. Выходы в слой сохранений: `RunState.to_dict()` (вместе с `StoryPosition.to_dict()`, `RollRecord.to_dict()`). Остальной код сырой словарь не получает.

## Alternatives Considered
- **Синхронная запись в главном потоке:** проходит бюджет F5, но `TIMEOUT`/`LOAD_TIMEOUT` недостижимы, зависание = ANR. Отвергнуто.
- **Запись во временный файл + `rename`:** лишняя платформенная неизвестность; пара поколений даёт ту же защиту. Отвергнуто.
- **Мьютексы и логика в потоке:** недетерминированные тесты. Отвергнуто в пользу `SaveIo` + `FakeSaveIo`.
- **`state` строкой в теле (GDD правило 2):** ломает загрузку (B1). Отвергнуто.
- **Непрозрачные `start`/`milestone_max` сейчас (предложение схемы):** поле без владельца и теста. Отвергнуто (B4).

## Consequences
- Плюс: вся очередь и тайм-ауты — юнит-тесты без потоков; формат прост, без `rename`.
- Минус: ввод-вывод на Android и сброс на диск проверяются только устройством; выход при зависшей задаче — открытый риск.
- Правки GDD и ADR-0001 вносит Зам (`save_td_pre.md`).

## Performance Implications
Запись 32 КБ — 26 мкс, 200 КБ — 97 мкс (Linux, проба). Главный поток: `JSON.stringify` + SHA-256 на ≈195 КБ — измерить (AC-47). Бюджеты F5 GDD без изменений.

## Risks
Зависшая задача при `quit()` (ANR); потеря питания (AC-57); часы в фоне (AC-21); `WorkerThreadPool` в Android. Закрываются пробой и устройством, не кодом.

## GDD Requirements Addressed
`save-system.md`: правила 1, 2, 4–8, 11; F1–F3, F5, F6; AC-01…AC-20, AC-22…AC-43, AC-61…AC-67 (SV1–SV4). Отложено: переходы 4, 5, AC-07, AC-33, AC-44, AC-45, AC-59, UI AC-50…52, AC-63, устройство AC-21, 47, 48, 54…57.

## Validation Criteria
Фикстурный круг `to_dict → JSON → from_dict` без удвоения журнала; запись о броске грузится; загрузка пишет 0 раз; `save_disk_test.gd` на `user://`; замер на устройстве закрывает строки NOT SOURCEABLE.

## Related
ADR-0001; DD-008, DD-009, DD-021, DD-022; `/tmp/.../save_td_pre.md` (точные правки).
