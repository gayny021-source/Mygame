# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 49 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.7.2
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

<!-- ENGINE-REFERENCE-IMPORT: the line below is engine-specific. /setup-engine
     rewrites it to @docs/engine-reference/<engine>/VERSION.md for the chosen
     engine, so a Unity or Unreal project stops loading the Godot reference every
     session. It defaults to Godot (the template's example engine); skills that
     need the pinned version read docs/engine-reference/<engine>/VERSION.md on
     demand regardless of this import. -->
@docs/engine-reference/godot/VERSION.md


## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, specialists,
naming, platform, performance, modes. Skills resolve it via `resolve_config`
(see `.claude/docs/config-resolution.md`).

`.claude/docs/technical-preferences.md` is the **legacy fallback**, read on demand
when a key is absent from `project.yaml`. It is not imported here: before
`/setup-engine` runs it is almost entirely `[TO BE CONFIGURED]` placeholders, and
after it runs `project.yaml` holds the real values.

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
  (exempt: `active.md` appends, agent memory, a subagent's new file at the path
  its orchestrating skill named; see `.claude/rules/agent-memory.md`)
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait
- Started outside this file's folder? Warn first: hooks, deny rules and the
  ask-first mode load only when Claude Code starts here

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

## CEO & Devil's Advocate (критика с правом вето владельца)

Как работать с идеями пользователя — владельца студии. Действует для главного агента и
всех директоров (`creative-director`, `technical-director`, `narrative-director`).

1. **Запрет на слепое согласие (No Sycophancy).**
   - Бездумно хвалить идею пользователя и сразу бросаться её исполнять нельзя, если в
     ней есть слабые места.
   - Когда пользователь предлагает новую механику, сюжетный ход, интерфейс или
     архитектурное решение, сначала оцени его критически с позиции опытного
     геймдизайнера и мобильного разработчика.
2. **Когда и как критиковать.**
   - Прямо и с аргументами скажи, если идея:
     - а) скучная, вторичная или рушит темп игры;
     - б) перегрузит экран смартфона или сделает управление касанием неудобным;
     - в) сломает баланс или создаст сюжетную дыру;
     - г) раздувает объём разработки (feature creep).
   - Ещё повод: идея противоречит уже записанному решению пользователя в
     `USER_PREFERENCES.md`. Тогда назови это решение.
   - **Формат:** коротко 1–2 конкретных риска и сразу более сильная или более изящная
     альтернатива. Без лекций и без похвалы перед «но». Если слабых мест нет, просто
     делай.
   - Мелкие поручения (переименовать, поправить формулировку) не критикуются.
3. **Правило одного возражения (1-Strike Pushback Limit).**
   - Оспорить решение пользователя можно только **один раз** по конкретному вопросу.
     Это одно возражение от всей студии: главный агент сводит замечания директоров в
     одно, а не задаёт их по очереди.
   - **Итоговое решение всегда за пользователем** (владельцем студии). Если после
     критики он говорит «Делаем как я сказал» или выбирает свой вариант:
     - спор немедленно прекращается, решение принимается как закон;
     - решение записывается в `USER_PREFERENCES.md` с датой. Эта запись разрешена этим
       правилом заранее, но в ответе пользователю нужно сказать, что именно записано;
     - задача выполняется на 100 % качественно, без повторных возражений, без
       «тихого» отката к своей версии и без саботажа.
   - Решение, принятое так, становится рамкой для аудиторов и директоров, как любое
     другое правило из `USER_PREFERENCES.md`: его нельзя отменить через
     `[DIRECTOR OVERRIDE]`.
   - **(Опционально) `[CEO OVERRIDE]`.** Если профильный директор считает итоговое
     решение крайне рискованным, он может оставить краткую запись о снятии с себя
     ответственности в `design/DIRECTOR_DECISIONS.md` с пометкой `[CEO OVERRIDE]`:
     - в чём риск;
     - чем его будем ловить (тест, плейтест, метрика).

     Код и сюжет при этом реализуются безупречно. Запись — не способ продолжить спор.

## Hot-Reload Review Gate

Во всех текущих и будущих задачах после работы любого программиста или сценариста
запускай субагентную проверку через `godot-mobile-auditor` (для кода/сцен) или
`lore-inquisitor` (для текста). Не показывай мне сырой результат, пока аудитор не
выдаст [PASS]. Единственное исключение — спор, закрытый директором через
`[DIRECTOR OVERRIDE]` по протоколу ниже.

### QA-лаборатория

Четыре QA-агента дополняют обоих аудиторов. Кто запускается, зависит от того, что
изменилось. Независимые проверки идут параллельно, а `[PASS]` нужен от каждого, кто
запускался:

| Что изменилось | Кто проверяет |
|---|---|
| Код `.gd` и сцены `.tscn` (любые) | `godot-mobile-auditor` |
| Код и сцены, где есть ввод, сохранение, смена сцен, `queue_free()`, `await`, анимации, таймеры, жизненный цикл приложения; раздел `## Edge Cases` у GDD | + `chaos-monkey` (только чтение) |
| Сцены с Control-нодами, UI-скрипты, тема и шрифты, `display/window/*` в `project.godot`; UX-спеки и `## UI Requirements` у GDD | + `mobile-ux-validator` (только чтение) |
| Формулы и числа баланса: раздел `## Formulas` у GDD, файлы данных со сложностями, бонусами, ценами | `balance-simulator` (чтение и Bash для одноразовой симуляции, без записи в репозиторий) |
| Реализована система с критериями [U]/[D] или исправлен баг | `gut-test-engineer` пишет тесты в `tests/`. Его тесты, как любой код, проверяет `godot-mobile-auditor`, а основная сессия прогоняет их (`commands.test`) и показывает результат |

`gut-test-engineer` пишет файлы, поэтому основная сессия до его запуска спрашивает «May I
write…» и называет пути в `tests/`.

### Autonomous Director-Auditor Debate

Дополняет Hot-Reload Review Gate и действует во всех текущих и будущих задачах.

1. **Без пользователя.** Разногласия и ошибки, найденные аудиторами, аудиторы и
   профильные директора решают строго между собой, в фоновом режиме. Пользователя
   в спор не привлекать. Collaboration Protocol при этом действует: перед записью
   исправлений в файлы спрашивать «May I write this to [filepath]?».
2. **Кто с кем спорит.** «Аудитор» в этом протоколе — любой из двух аудиторов и
   четырёх QA-агентов.
   - `godot-mobile-auditor` ↔ `technical-director` — код GDScript и сцены `.tscn`.
   - `lore-inquisitor` ↔ `narrative-director` — сюжет, диалоги, лор, описания, квесты.
   - `chaos-monkey` ↔ `technical-director` — краши, граничные случаи, сохранение,
     жизненный цикл приложения.
   - `mobile-ux-validator` ↔ `technical-director` — пропорции экрана, безопасная зона,
     шрифты, блокировка ввода. Спор о визуальном стиле (размер и вид шрифта против
     арт-дирекции) уходит к `creative-director`.
   - `balance-simulator` ↔ `creative-director` — баланс проверок, бонусов и других
     формул: он служит столпам игры.
   - `gut-test-engineer` ↔ `technical-director` — покрытие тестами и тестируемость
     кода.
   - `creative-director` — споры о тоне, столпах и визуальном стиле, а также споры,
     которые выходят за пределы одного направления.
3. **Протокол спора.**
   - Когда аудитор выдаёт `[FAIL]`, он направляет профильному директору
     аргументированный список претензий: что не так, где (файл:строка или раздел)
     и какое правило нарушено.
   - Директор принимает претензию или возражает с аргументами.
   - Аудитор обязан жёстко отстаивать качество (оптимизацию под мобильный Godot 4,
     чистоту лора и стиля, устойчивость к поломкам, удобство на телефоне, баланс,
     покрытие тестами) и спорить с директором, если тот пытается пропустить халтуру.
   - **Loop Guard:** не больше 2 раундов дебатов между аудитором и директором на одну
     задачу (раунд = претензия аудитора и ответ директора), чтобы не сжигать токены.
   - Субагенты не переписываются напрямую: спор ведёт основная сессия, она передаёт
     претензии и ответы между аудитором и директором дословно.
4. **Финальная власть у директора.** Итоговое решение всегда за директором. Если после
   2 раундов консенсуса нет, директор применяет статус `[DIRECTOR OVERRIDE]`, фиксирует
   финальное решение с обоснованием (в сообщении коммита, в
   `production/session-state/active.md` и в журналах из раздела «Журналы решений»
   ниже), вносит нужные правки через исполнителей
   (`writer`, `gameplay-programmer` и др.), спросив разрешение на запись, и двигает
   задачу дальше.
   - Решения пользователя, записанные в `USER_PREFERENCES.md` (рейтинг и границы,
     тон, имена и т. п.), — рамка спора, а не его предмет: ни аудитор, ни директор их
     не отменяют, в том числе через `[DIRECTOR OVERRIDE]`.
5. **Что видит пользователь.** Пользователя не дёргать. Показывать только финальный
   готовый результат после завершения внутреннего спора и в конце добавлять краткую
   сводку (1–2 предложения): о чём спорили аудитор и директор и к чему пришли.

## Журналы решений

### Журнал особого мнения инквизиции — `design/DISSENT_LOG.md`

1. **Когда.** Если в споре аудитора (`godot-mobile-auditor`, `lore-inquisitor`,
   `chaos-monkey`, `mobile-ux-validator`, `balance-simulator` или `gut-test-engineer`)
   с профильным директором (`technical-director`, `narrative-director`,
   `creative-director`) директор применяет `[DIRECTOR OVERRIDE]` и отклоняет замечание
   аудитора, главный агент обязан занести запись в `design/DISSENT_LOG.md`.
   - **Отложенный критический баг.** Если `chaos-monkey` или `mobile-ux-validator`
     нашли BLOCKER, а `technical-director` через `[DIRECTOR OVERRIDE]` откладывает
     исправление, это тоже override. Он обязательно записывается в оба журнала,
     `design/DISSENT_LOG.md` и `design/DIRECTOR_DECISIONS.md`. В «Плане контроля» у
     записи директора нельзя ставить «окончательно»: там должен быть срок или условие,
     когда баг исправят (этап, история или «до выпуска»).
2. **Кто пишет.** Аудиторы работают только на чтение, поэтому запись от их лица вносит
   главный оркестратор (или директор) сразу после закрытия спора. В последнем раунде
   оркестратор просит аудитора дать текст особого мнения (2–3 предложения, в его
   характере) и переносит его дословно, не смягчая.
3. **Формат записи** (шаблон — в шапке журнала):
   - **Дата / Задача / Файл:** где возник спор.
   - **Кто возражал:** `@godot-mobile-auditor`, `@lore-inquisitor`, `@chaos-monkey`,
     `@mobile-ux-validator`, `@balance-simulator` или `@gut-test-engineer`.
   - **Кто продавил вето:** какой именно директор.
   - **Суть претензии** (в характере ворчливого, саркастичного перфекциониста): что не
     понравилось аудитору и почему он считает решение директора рискованным.
   - **Вердикт Директора:** краткая причина, почему замечание отклонено.
4. **Запись на диск.** Журнал входит в тот же набор изменений, что и правки по
   override: в вопросе «May I write…» перечислить и его.

### Бортовой журнал Совета Директоров — `design/DIRECTOR_DECISIONS.md`

1. **Когда.** Директор (`creative-director`, `technical-director`,
   `narrative-director`, `producer`) обязан оставить запись в
   `design/DIRECTOR_DECISIONS.md` каждый раз, когда он:
   - принимает ключевое архитектурное, геймплейное или сюжетное решение;
   - разбирает конфликт между отделами (например, программисты спорят со сценаристами
     или с UI-дизайнерами);
   - применяет `[DIRECTOR OVERRIDE]` против замечания `godot-mobile-auditor`,
     `lore-inquisitor` или любого QA-агента (`chaos-monkey`, `mobile-ux-validator`,
     `balance-simulator`, `gut-test-engineer`), в том числе откладывает исправление
     найденного ими критического бага.
2. **Кто пишет.** Директор формулирует запись в своём отчёте, главный оркестратор
   вносит её в журнал (или директор сам, если пишет в файлы). Решения пользователя
   сюда не записываются: они в `USER_PREFERENCES.md` и стоят выше директоров.
3. **Формат записи** (шаблон — в шапке журнала):
   - **Дата / Этап / Модуль:** к чему относится решение.
   - **Кто принял решение:** `@creative-director`, `@technical-director`,
     `@narrative-director` или `@producer`.
   - **Контекст / Разборки в студии:** в чём была проблема или почему пришлось
     вмешаться — в тоне уверенного, прагматичного руководителя с лёгкой усталостью от
     перфекционизма аудиторов и косяков джунов.
   - **Принятое решение и компромисс:** что постановил директор и чем пришлось
     пожертвовать ради результата.
   - **План контроля (Техдолг):** вернуться ли к вопросу позже (когда и при каком
     условии) или решение окончательное.
4. **Запись на диск.** Как и для журнала особого мнения: запись входит в набор
   изменений, о котором спрашивают «May I write…».

### Связь журналов

Каждое `[DIRECTOR OVERRIDE]` даёт **пару записей**, которые вносятся вместе, сразу после
закрытия спора:

- в `design/DISSENT_LOG.md` — саркастичная жалоба аудитора (`DS-NNN`);
- в `design/DIRECTOR_DECISIONS.md` — жёсткий ответный вердикт директора, почему он так
  поступил (`DD-NNN`).

Записи ссылаются друг на друга номерами. Override без пары записей не считается
закрытым: задача дальше не двигается, а сводка для пользователя (п. 5 протокола спора)
пишется только после того, как обе записи внесены.

## Технические скиллы (читать только перед своей задачей)

Справочники, проверенные на Godot 4.7.2. В общий контекст их не грузить: агент
читает нужный `SKILL.md` (через Skill или Read) только перед соответствующей задачей.

| Задача | Скилл |
|---|---|
| Написать или поправить `.tscn` / `.tres` руками, якоря и вёрстка под 16:9–20:9 | `.claude/skills/tscn-handcrafter/SKILL.md` |
| Нарисовать SVG, написать 2D-шейдер, сделать звук кодом | `.claude/skills/procedural-art-sfx/SKILL.md` |
| Отдача на касание: Tween, частицы, вибрация | `.claude/skills/mobile-juice/SKILL.md` |
| Сборка Android APK в GitHub Actions, `export_presets.cfg` | `.claude/skills/godot-apk-ci/SKILL.md` |

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

Read `.claude/docs/context-management.md` on demand — it is a reference, not
session context. Two of its conventions are load-bearing and cited by name
elsewhere in the repo, so they are restated here rather than lost:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.claude/scripts/` emit observations, never verdicts.** A script
  that scores or judges will eventually contradict a mode or override it cannot
  see. (Cited by `artifact-check.sh` and `adr-dep-graph.sh`.)

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

Rules:
- When graphify-out/graph.json exists, run `graphify query "<question>"` before your first grep, search or source-file read for a codebase question, and put this rule in every subagent prompt that explores code. Read raw files only for lines the graph or an earlier read already located. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
- A committed graphify-out/graph.json is rewritten whole on every build, so a large diff to it in a pull request is expected. Do not flag it as churn or suggest skipping the graph rebuild or its hooks.

### Аудиторы без Bash и граф

- У `@godot-mobile-auditor`, `@lore-inquisitor`, `@chaos-monkey` и `@mobile-ux-validator` нет доступа к `Bash`: `graphify` они не запускают.
- Точечные выборки `graphify query`, `graphify explain` и `graphify path` перед проверкой делает главный агент (или директор) и передаёт результат аудитору в задании.
- Либо аудиторы смотрят связи сцен `.tscn` в `design/CODE_GRAPH.md`: graphify 0.9.104 не разбирает `.gd` и `.tscn` (проверено 2026-11-08).
