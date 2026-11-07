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

## Hot-Reload Review Gate

Во всех текущих и будущих задачах после работы любого программиста или сценариста
запускай субагентную проверку через `godot-mobile-auditor` (для кода/сцен) или
`lore-inquisitor` (для текста). Не показывай мне сырой результат, пока аудитор не
выдаст [PASS]. Единственное исключение — спор, закрытый директором через
`[DIRECTOR OVERRIDE]` по протоколу ниже.

### Autonomous Director-Auditor Debate

Дополняет Hot-Reload Review Gate и действует во всех текущих и будущих задачах.

1. **Без пользователя.** Разногласия и ошибки, найденные аудиторами, аудиторы и
   профильные директора решают строго между собой, в фоновом режиме. Пользователя
   в спор не привлекать. Collaboration Protocol при этом действует: перед записью
   исправлений в файлы спрашивать «May I write this to [filepath]?».
2. **Кто с кем спорит.**
   - `godot-mobile-auditor` ↔ `technical-director` — код GDScript и сцены `.tscn`.
   - `lore-inquisitor` ↔ `narrative-director` — сюжет, диалоги, лор, описания, квесты.
   - `creative-director` — споры о тоне, столпах и визуальном стиле, а также споры,
     которые выходят за пределы одного направления.
3. **Протокол спора.**
   - Когда аудитор выдаёт `[FAIL]`, он направляет профильному директору
     аргументированный список претензий: что не так, где (файл:строка или раздел)
     и какое правило нарушено.
   - Директор принимает претензию или возражает с аргументами.
   - Аудитор обязан жёстко отстаивать качество (оптимизацию под мобильный Godot 4,
     чистоту лора и стиля) и спорить с директором, если тот пытается пропустить
     халтуру.
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

1. **Когда.** Если в споре аудитора (`godot-mobile-auditor` или `lore-inquisitor`) с
   профильным директором (`technical-director`, `narrative-director`,
   `creative-director`) директор применяет `[DIRECTOR OVERRIDE]` и отклоняет замечание
   аудитора, главный агент обязан занести запись в `design/DISSENT_LOG.md`.
2. **Кто пишет.** Аудиторы работают только на чтение, поэтому запись от их лица вносит
   главный оркестратор (или директор) сразу после закрытия спора. В последнем раунде
   оркестратор просит аудитора дать текст особого мнения (2–3 предложения, в его
   характере) и переносит его дословно, не смягчая.
3. **Формат записи** (шаблон — в шапке журнала):
   - **Дата / Задача / Файл:** где возник спор.
   - **Кто возражал:** `@godot-mobile-auditor` или `@lore-inquisitor`.
   - **Кто продавил вето:** какой именно директор.
   - **Суть претензии** (в характере ворчливого, саркастичного перфекциониста): что не
     понравилось аудитору и почему он считает решение директора рискованным.
   - **Вердикт Директора:** краткая причина, почему замечание отклонено.
4. **Запись на диск.** Журнал входит в тот же набор изменений, что и правки по
   override: в вопросе «May I write…» перечислить и его.

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
