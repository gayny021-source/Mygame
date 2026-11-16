# Передача сессии — «Критический провал»

Обновлено: 2026-11-16. Ветка: `ccr-1d613ff8-jumb1q` (каждой облачной сессии среда выдаёт свою ветку `ccr-*`; пушить только в выданную, PR не создавать). `main` — отдельный «Initial commit» без общей истории с ветками.

## Первое действие новой сессии
1. Прочитать `CLAUDE.md`, `USER_PREFERENCES.md`, `production/session-state/active.md` (последние записи внизу).
2. Сказать пользователю одной строкой, что сессия восстановлена, и продолжить конвейер ниже. Новых тем без слова CEO не начинать.

## Роли и правила
- Пользователь — Гендиректор (CEO), последнее слово за ним. Claude — Зам (COO): оркестрирует агентов, экономит лимиты. К CEO идут только вопросы по дизайну, сюжету, персонажам. Общение по-русски; отчёт CEO — 3–5 строк, стиль caveman.
- Технику и код решает Зам. Код и сцены пишут только агенты-программисты (`gameplay-programmer`); правка до 30 строк в 1–2 известных файлах — Зам сам. Аудиторы только читают.
- Каждый промпт агента заканчивать: «Ответ строго до 8 строк: только баги/решения без кусков кода».
- Аудит после кода: `godot-mobile-auditor` + `chaos-monkey` параллельно, максимум 2 раунда (Loop Guard). Нет консенсуса — `[DIRECTOR OVERRIDE]` с парой DS + DD.
- Журналы `design/DISSENT_LOG.md`, `design/DIRECTOR_DECISIONS.md`, `USER_PREFERENCES.md` — дописывать только `Bash >>`.
- Перед коммитом: `python3 scripts/update_visual_graph.py >/dev/null 2>&1`. В коммитах не указывать идентификаторы моделей; атрибуция — по системной подсказке сессии.
- Нельзя: `rm -rf`, `.git/hooks/`, коммит ключей/keystore, чтение целиком `GRAPH_REPORT.md` и `graph.json`.
- Агенты упираются в лимит 20 шагов — возобновлять через `SendMessage` («продолжай, запиши отчёт»). Лимит API (429) — подождать сброса.

## Команды
- Импорт после новых `class_name`: `godot --headless --path . --import`
- Тесты: `godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode` (две строки ERROR про remote debugger безвредны)
- Парс-проверка: `.claude/scripts/godot-parse-check.gd`

## Где мы
Код ядра по ADR-0001 (`docs/architecture/adr-0001-scene-data-format.md`), тесты 508 зелёные:
- S1 загрузчики данных, S2 язык условий, S3 RunState/FlagLoader/`if` в ChapterLoader, S4 граф главы и структурные проверки BS-02…10 — закрыты, аудит 2 раунда.
- S5 закрыта 2026-11-16, аудит 2 раунда, override DD-018/DS-001, DD-019/DS-002: `DataValidator` (= GraphValidator + bs_traces/bs_budget/bs_limits/bs_ids), `ChapterPaths` (предел `path_enum_max`), `ReleasedIds` (Snapshot, read/compare), `JsonLint`, конфиг `assets/data/config/story_limits.json`, CLI `tools/validate_data.gd` (выход 0/1/2, `--freeze`, `--root=`). Тест AC-27 — `tests/integration/story/data_validator_test.gd`. Героев в `assets/data/heroes` пока нет (CLI выходит 2).
- Дальше: S6 (позиция и навигатор; chaos-monkey обязателен), S7 (d20). Агентам давать точные строки, а не разделы: лимит 20 шагов уходил на чтение.

GDD (все Designed, ждут независимого ревью): run-state, d20-checks, heroes, branching-story, choice-system, chapter-goal, save-system, scene-illustrations. MVP 8/10 в `design/gdd/systems-index.md`. Решения директоров — `design/DIRECTOR_DECISIONS.md` (последний DD-017).

## Открытые задачи
- UR-1 (C6 аудита S5): решение CEO 2026-11-16 — пробел у вставки моста ставит движок (`USER_PREFERENCES.md`, ADR-0001 §1 «Вставка моста»). Сделать в начале S6: соединение в навигаторе, проверка `bs_limits.gd:77,93`, фикстура `ch_f1` (`слово {insert}`), текст GDD правило 6 и AC-52 — с «May I write» у CEO.
- Вопрос game-designer: толкование BS-07, BS-11, BS-14, BS-16 в коде S5 — список в отчёте S5 (в репозитории нет; при нужде восстановить из `checks/`).
- ADR-0001: `k_budget`, `k_min`, `s_path_min` временно в `story_limits.json` — перенести в конфиг d20, когда он появится (формула 7 d20-checks).
- Техдолг S5: CLI не подключён к CI; `DirAccess.rename_absolute` с перезаписью, `FileAccess`/`DirAccess`/`JSON`/`Time` в CLI не покрыты справкой движка (проверены только headless на 4.7.2 Linux); диапазоны конфига проверяются только на знак и min ≤ max.
- Правки под рамку тона 12+ (11 мест в GDD/ADR; список в scratchpad `tone_followups.md`, если файла нет — искать по НП-55…61 в `design/narrative/chapter-writing-rules.md`): game-concept ×3, d20-checks ×1 (развести «титр крита» и «картуш сцены»), branching-story ×2, ADR-0001 (ключ метки картуша); заменить тексты прототипа, нарушающие 12+.
- GDD branching-story: BS-05 и AC-10 расходятся про отсутствие `финал` (код: только BS-10) — выровнять текст.
- Вопрос к game-designer/CEO: правило для пустых `endings` («каждая концовка героя — цель перехода») — в спеке нет.
- Дизайн систем: «Экран чтения», «Экран броска» (MVP); дальше VS/Alpha/FV по `systems-index.md`. Арт-библия разделы 5–8 пусты.
- Независимое ревью `/design-review` в новой сессии для всех GDD выше, затем `/consistency-check`, позже `/gate-check`.
- Техдолг S1/S3: массив с неверными типами всех элементов даёт DT-02 + BS-01; индекс sets/clears в пути BS-01 сдвигается при не-строках; decl с пустым id попадает в flags; `RunState.new` напрямую не ловит дубль id.
- Сборка APK ни разу не запускалась; `package/unique_name` = `com.example.kritproval` до релиза; потоки, SHA-256, FileAccess и Safe Area на Android не проверены (нужна проба на устройстве).
- Решения CEO: TalkBack исключён; рейтинг 12+ по содержанию (подробности — `USER_PREFERENCES.md`).
