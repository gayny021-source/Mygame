# Review Log: design/gdd/game-concept.md

## Review — 2026-11-07 — Verdict: NEEDS REVISION
Review mode: lean · Workflow: standard
Scope signal: L
Specialists: none (lean mode)
Blocking items: 4 | Recommended: 6
Summary: Концепт отставал от итогов прототипа: перехваливал провалы, не определял безопасный вариант без броска, не показывал последствия прошлых решений и не требовал связности главы. Стандарт GDD из 8 разделов к концепту не применялся (это не GDD системы); проверка шла по шаблону концепта, все 15 разделов на месте. Все находки исправлены в тот же день по решениям пользователя (commits 48f79d5, 07fb245, eb9a234, 8adc183); исправленный текст прошёл гейт lore-inquisitor с третьего прохода ([PASS]). Хэш ниже — у проверенной версии до правок, поэтому следующий /design-review увидит CHANGED и проверит исправленную версию заново.
Prior verdict resolved: First review
Findings:
- [BLOCKING] Game Pillars / Core Fantasy / Unique Hook: провал подан как «самая смешная ветка» вопреки плейтесту — исправлено: успех и безопасный выбор на том же уровне
- [BLOCKING] Core Mechanics: безопасный вариант без броска не определён — исправлено: гарантированный результат с ценой, которую называет сцена
- [BLOCKING] Pillar 4 / Core Loop: последствия прошлых решений не видны — исправлено: новые варианты выбора с названной причиной, прошлые решения не меняют число на кубике
- [BLOCKING] Core Loop / MVP: нет требования связности — исправлено: цель главы, маркер прогресса, переходы, проверка на нескольких главах
- [RECOMMENDED] Pillar 3: нелепые герои не покрыты — исправлено: нелепый герой тоже не подмигивает
- [RECOMMENDED] Status / Next Steps / Open Questions: устаревшие данные — исправлено
- [RECOMMENDED] Technical Considerations: объём (написанные vs прочитанные слова, плотность проверок, сроки) — уточнено
- [RECOMMENDED] MVP Definition: не совпадал с построенным прототипом — обновлено
- [RECOMMENDED] Core Identity / Market Risks: не записан рейтинг 16+ — добавлено
- [RECOMMENDED] Player Motivation: «видит, как растут его шансы» противоречил антистолпу — исправлено
Open after review: может ли прошлое решение менять сложность проверки (решает пользователь); как хранить цену «потерял час» без счётчика (GDD ветвящейся истории).
Reviewed-Content-Hash: design/gdd/game-concept.md 2aa6a103b733fb7037e54728178d8ef6b2afeba6
Reviewed-Content-Hash: design/registry/entities.yaml dfeacb02917f751cb1dfd88cf490c7ec3d8d2d0f
Reviewed-Content-Hash: .claude/skills/design-review/SKILL.md a63d8fba9b7142eeb43791f061e2e1533c429b43
Reviewed-Content-Hash: USER_PREFERENCES.md 0f4db255d6aa38fdafe768971491db8809a69126
Reviewed-Content-Hash: prototypes/critical-fail-concept/REPORT.md 8c336a6202baa1e299a37c60a7e1879eca104bd8
