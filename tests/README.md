# Test Infrastructure

**Engine**: Godot 4.7.2 · **Framework**: gdUnit4 (`addons/gdUnit4/` — NOT YET INSTALLED, see below)
**CI**: `.github/workflows/tests.yml` · **Setup date**: 2026-11-13

```
tests/unit/         # formulas, state machines, logic
tests/integration/  # cross-system, save/load
tests/smoke/        # critical-path list for /smoke-check
production/qa/evidence/  # screenshots, manual sign-offs
```

## Running

Command: `commands.test` in `project.yaml`. It needs `addons/gdUnit4/` and, after a
fresh clone, `godot --headless --path . --import` once.

## Naming

File `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`.
