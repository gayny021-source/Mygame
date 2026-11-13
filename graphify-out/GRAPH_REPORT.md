# Graph Report - Mygame  (2026-11-13)

## Corpus Check
- 68 files · ~990,249 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 539 file(s) not represented in the graph (top: .gd 245, .uid 239, .tscn 18)
- WARNING: 539 of 1224 files seen (44%) have no supported extractor and are missing from this graph entirely. It may look complete while representing only part of the codebase.

## Summary
- 645 nodes · 849 edges · 67 communities (39 shown, 28 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `7684a041`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- artifact
- entities
- project.yaml
- with
- yaml-helper.sh
- steps
- migrate-v1-config.sh
- hooks
- test-scaffold.sh
- write-guard.sh
- stories
- skills
- review-receipts.sh
- test-run.sh
- project-coherence.sh
- debt-register.sh
- update-check.sh
- project-state.sh
- registry.sh
- architecture.yaml
- config-set.sh
- inputs-check.sh
- session-state.sh
- validate-push.sh
- validate-registry.sh
- gdd-structure-check.sh
- hook-input.sh
- plan-math.sh
- log-instructions.sh
- validate-commit.sh
- validate-read.sh
- validate-write.sh
- adr-status.sh
- md-section.sh
- read-guard.sh
- review-scope.sh
- tr-registry.yaml
- validate-agent-artifact.sh
- adr-dep-graph.sh
- asset-scan.sh
- content-count.sh
- set-stage.sh
- skill-lint.sh
- detect-gaps.sh
- log-agent.sh
- log-agent-stop.sh
- notify.sh
- pre-compact.sh
- session-start.sh
- session-stop.sh
- validate-assets.sh
- validate-skill-change.sh
- agent-check.sh
- artifact-check.sh
- bug-stats.sh
- code-markers.sh
- compat-inventory.sh
- flaky-stats.sh
- rotate-session-state.sh
- story-facts.sh
- story-status.sh
- statusline.sh
- GdUnit4CSharpApi
- steps
- with
- runtest.sh

## God Nodes (most connected - your core abstractions)
1. `entities` - 14 edges
2. `yaml-helper.sh script` - 14 edges
3. `migrate-v1-config.sh script` - 14 edges
4. `GdUnit4CSharpApi` - 13 edges
5. `_yaml_helper_set_root()` - 13 edges
6. `content_of()` - 13 edges
7. `with` - 12 edges
8. `artifact` - 11 edges
9. `formulas` - 11 edges
10. `skills` - 11 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (67 total, 28 thin omitted)

### Community 0 - "artifact"
Cohesion: 0.07
Nodes (52): any_of, glob, min_count, note, description, label, next_phase, steps (+44 more)

### Community 1 - "entities"
Cohesion: 0.05
Nodes (38): constants, added, name, notes, referenced_by, revised, source, status (+30 more)

### Community 2 - "project.yaml"
Cohesion: 0.05
Nodes (38): commands, build, run, smoke, test, engine, language, name (+30 more)

### Community 3 - "with"
Cohesion: 0.05
Nodes (36): container, name, permissions, runs-on, steps, image, env, APK_NAME (+28 more)

### Community 4 - "yaml-helper.sh"
Cohesion: 0.17
Nodes (27): get_effective_yaml_array(), get_effective_yaml_key(), get_legacy_key(), get_yaml_array(), get_yaml_child_keys(), get_yaml_default(), get_yaml_key(), is_always_ask_category() (+19 more)

### Community 5 - "steps"
Cohesion: 0.07
Nodes (29): container, name, permissions, runs-on, steps, image, env, APK_NAME (+21 more)

### Community 6 - "migrate-v1-config.sh"
Cohesion: 0.22
Nodes (16): agent_name(), agent_names(), is_num(), LC_ALL, legacy_conflict(), legacy_present(), manual(), null_warn() (+8 more)

### Community 7 - "hooks"
Cohesion: 0.10
Nodes (19): hooks, Notification, PostToolUse, PreCompact, PreToolUse, SessionStart, Stop, SubagentStart (+11 more)

### Community 8 - "test-scaffold.sh"
Cohesion: 0.20
Nodes (18): content_of(), list_paths(), made(), need(), render(), test-scaffold.sh script, tpl_asmdef_edit(), tpl_asmdef_play() (+10 more)

### Community 9 - "write-guard.sh"
Cohesion: 0.24
Nodes (16): abs_path(), applied(), engine_name(), overwrite_why(), phys(), rel(), rule_agent(), rule_config() (+8 more)

### Community 10 - "stories"
Cohesion: 0.12
Nodes (16): end, generated, goal, sprint, start, stories, blocker, completed (+8 more)

### Community 11 - "skills"
Cohesion: 0.14
Nodes (13): last_updated, skills, category, last_category, last_category_result, last_spec, last_spec_result, last_static (+5 more)

### Community 12 - "review-receipts.sh"
Cohesion: 0.33
Nodes (10): compare_stamp(), hash_file(), is_unexpanded_glob(), LC_ALL, norm_path(), section_hash(), review-receipts.sh script, sha1_stdin() (+2 more)

### Community 13 - "test-run.sh"
Cohesion: 0.32
Nodes (11): attr(), exe_ok(), first_line(), is_timeout(), list_failed(), ran_no(), run_timed(), set_rule() (+3 more)

### Community 14 - "project-coherence.sh"
Cohesion: 0.38
Nodes (9): differs(), LC_ALL, match(), say(), project-coherence.sh script, skipped(), summarise(), vmm() (+1 more)

### Community 15 - "debt-register.sh"
Cohesion: 0.36
Nodes (8): effort_n(), effort_name(), impact_n(), impact_name(), is_date(), not_judged(), debt-register.sh script, usage()

### Community 16 - "update-check.sh"
Cohesion: 0.50
Nodes (7): update-check.sh script, _update_check_cache(), _update_check_enabled(), _update_check_newer(), update_check_notice(), _update_check_now(), update_check_refresh()

### Community 17 - "project-state.sh"
Cohesion: 0.54
Nodes (7): count(), first_line(), is_stage(), row(), project-state.sh script, stage_rows(), yaml_get()

### Community 18 - "registry.sh"
Cohesion: 0.46
Nodes (7): abs_path(), files(), is_slug(), next_seen(), reg_path(), registry.sh script, usage()

### Community 19 - "architecture.yaml"
Cohesion: 0.25
Nodes (7): api_decisions, forbidden_patterns, interfaces, last_updated, performance_budgets, state_ownership, version

### Community 20 - "config-set.sh"
Cohesion: 0.48
Nodes (5): replace_file(), config-set.sh script, usage(), yget(), yh_const()

### Community 21 - "inputs-check.sh"
Cohesion: 0.60
Nodes (5): add_spec(), glob_matches(), has_content(), inputs-check.sh script, slashes()

### Community 22 - "session-state.sh"
Cohesion: 0.60
Nodes (4): emit(), emit_text(), lines(), session-state.sh script

### Community 23 - "validate-push.sh"
Cohesion: 0.80
Nodes (4): command_segments(), git_segment(), mask_quoted(), validate-push.sh script

### Community 24 - "validate-registry.sh"
Cohesion: 0.80
Nodes (4): validate-registry.sh script, vr_row(), vr_skip(), vr_warn()

### Community 25 - "gdd-structure-check.sh"
Cohesion: 0.70
Nodes (4): check_file(), not_a_system_gdd(), placeholders(), gdd-structure-check.sh script

### Community 26 - "hook-input.sh"
Cohesion: 0.60
Nodes (3): phys(), hook-input.sh script, usage()

### Community 27 - "plan-math.sh"
Cohesion: 0.70
Nodes (4): is_date(), is_num(), plan-math.sh script, usage()

### Community 28 - "log-instructions.sh"
Cohesion: 0.83
Nodes (3): pick(), log-instructions.sh script, shorten()

### Community 29 - "validate-commit.sh"
Cohesion: 0.83
Nodes (3): command_segments(), git_segment(), validate-commit.sh script

### Community 30 - "validate-read.sh"
Cohesion: 0.83
Nodes (3): validate-read.sh script, vr_row(), vr_warn()

### Community 31 - "validate-write.sh"
Cohesion: 0.83
Nodes (3): validate-write.sh script, vw_row(), vw_warn()

### Community 32 - "adr-status.sh"
Cohesion: 0.83
Nodes (3): add_file(), adr_id(), adr-status.sh script

### Community 34 - "read-guard.sh"
Cohesion: 0.83
Nodes (3): rg_get(), read-guard.sh script, usage()

### Community 35 - "review-scope.sh"
Cohesion: 1.00
Nodes (3): all_gdds(), not_a_system_gdd(), review-scope.sh script

### Community 36 - "tr-registry.yaml"
Cohesion: 0.50
Nodes (3): last_updated, requirements, version

### Community 63 - "GdUnit4CSharpApi"
Cohesion: 0.08
Nodes (3): ExecutionCompletedEventHandler, GdUnit4CSharpApi, gdUnit4.addons.gdUnit4.src.dotnet

### Community 64 - "steps"
Cohesion: 0.07
Nodes (29): container, name, permissions, runs-on, steps, image, env, APK_NAME (+21 more)

### Community 65 - "with"
Cohesion: 0.08
Nodes (25): jobs, test, name, on, pull_request, push, checks, contents (+17 more)

## Knowledge Gaps
- **3 isolated node(s):** `LC_ALL`, `LC_ALL`, `LC_ALL`
  These have ≤1 connection - possible missing edges. (Counts symbols only; 309 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **28 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `LC_ALL`, `LC_ALL`, `LC_ALL` to the rest of the system?**
  _3 weakly-connected nodes found - possible missing edges._
- **Should `artifact` be split into smaller, more focused modules?**
  _Cohesion score 0.07039187227866474 - nodes in this community are weakly interconnected._
- **Should `entities` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._
- **Should `project.yaml` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._
- **Should `with` be split into smaller, more focused modules?**
  _Cohesion score 0.05405405405405406 - nodes in this community are weakly interconnected._
- **Should `steps` be split into smaller, more focused modules?**
  _Cohesion score 0.06666666666666667 - nodes in this community are weakly interconnected._
- **Should `hooks` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._