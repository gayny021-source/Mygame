---
name: tscn-handcrafter
description: "Hand-build valid Godot 4 .tscn/.tres text files without the editor — section order, ids, value syntax, anchors_preset cheat sheet for portrait 16:9–20:9 phones, load check. Read before writing or editing any scene or resource by hand."
argument-hint: "[path to the .tscn or .tres to write or fix]"
user-invocable: false
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(godot --headless *)
---

# Ручная сборка сцен Godot 4 без редактора

Справочник для агентов. Читать перед тем, как писать или править `.tscn` или `.tres`
руками. Общие запреты для таких правок — в `.claude/rules/scene-files.md`, они
главнее этого файла.

> **Проверено на Godot 4.7.2 (2026-11-07).** Сцену собрали кодом и сохранили движком.
> Файлы, написанные руками, загрузили, сломанные варианты уронили. Если версия
> движка в `docs/engine-reference/godot/VERSION.md` сменилась, перепроверь формат
> командой из раздела «Проверка».

## 1. Порядок секций (строгий)

```
[gd_scene format=3]          ← заголовок без load_steps (у .tres: [gd_resource type="…" format=3])
[ext_resource …]             ← все внешние ресурсы: скрипты, текстуры, сцены
[sub_resource …]             ← все встроенные ресурсы: StyleBox, Shape, Gradient…
[node …]                     ← дерево: сначала корень, потом дети, родитель выше ребёнка
[connection …]               ← сигналы, в самом конце
```

- **Нарушил порядок — сцена не грузится.** Проверено: `[connection]` перед `[node]`
  или `[ext_resource]` после нод даёт `Parse Error`. То же со ссылкой на
  `SubResource`, которого нет выше по файлу.
- **Заголовок — `[gd_scene format=3]`, без `load_steps`** (решение пользователя
  2026-11-07, `USER_PREFERENCES.md`). Так пишет и сам Godot 4.7.2.
  - Старая форма `[gd_scene load_steps=X format=3]` тоже загружается (проверено), но
    в новых файлах её не пиши.
  - Встретил её в существующем файле — можно убрать при правке.
- **`format=` не меняй никогда:** `format=3` — это Godot 4.
- **`.tres` устроен так же.** Сначала `[gd_resource type="StyleBoxFlat" format=3]`,
  затем ext и sub, а в конце `[resource]` со свойствами самого ресурса.

## 2. Ресурсы и ссылки

```ini
[ext_resource type="Script" path="res://src/ui/choice_button.gd" id="1_btn"]
[ext_resource type="Texture2D" path="res://assets/art/icons/die.svg" id="2_die"]
[ext_resource type="PackedScene" path="res://src/ui/hero_card.tscn" id="3_card"]
[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_choice"]
bg_color = Color(0.93, 0.86, 0.7, 1)
```

- **`id`** — любая строка, уникальная внутри файла. Редактор пишет `1_ab3cd` для ext и
  `Тип_ab3cd` для sub. Ссылка на ресурс: `ExtResource("1_btn")`, `SubResource("StyleBoxFlat_choice")`.
- **`uid="uid://…"`** в новом `ext_resource` не придумывай. Ставь только `path`, а `uid`
  назначит `godot --headless --path . --import` или редактор. Существующие `uid` при
  правке не трогай.
- **`unique_id=`** на нодах Godot 4.7.2 пишет сам. Руками его не ставь, при копировании
  ноды удаляй, существующие не трогай. Сцена без `unique_id` грузится (проверено).

## 3. Ноды

```ini
[node name="ReadingScreen" type="Control"]                     ← корень: без parent
[node name="Safe" type="MarginContainer" parent="."]           ← ребёнок корня
[node name="Column" type="VBoxContainer" parent="Safe"]        ← путь от корня
[node name="Card" parent="Safe/Column" instance=ExtResource("3_card")]  ← вложенная сцена
```

- В файл пишутся только свойства, отличные от значения по умолчанию.
- Синтаксис значений:
  - `Vector2(0, 144)`, `Color(r, g, b, a)`, `Rect2(…)`;
  - `PackedStringArray("a", "b")`;
  - `NodePath("../Label")`, `&"name"` (StringName);
  - `"строка"`, `true`, `1.0`.
- Тема у ноды:
  - `theme_override_font_sizes/font_size = 40`;
  - `theme_override_styles/normal = SubResource("…")`;
  - `theme_override_constants/separation = 24`.
- У `RichTextLabel` размер шрифта задаётся ключом `theme_override_font_sizes/normal_font_size`.
- `layout_mode`: `0` Position, `1` Anchors, `2` Container, `3` Uncontrolled. Значения
  взяты из подсказки свойства в 4.7.2.
  - Корень сцены — `3`.
  - Ребёнок обычного Control с якорями — `1`.
  - Ребёнок контейнера (`VBoxContainer`, `MarginContainer`…) — `2`, якоря ему не пишутся:
    раскладку задают `size_flags_*` (`3` = растянуть и заполнить).

## 4. Сигналы

```ini
[connection signal="pressed" from="Safe/Column/Choices/Choice1" to="." method="_on_choice_pressed"]
```

`from` и `to` — пути от корня, корень пишется как `"."`. Метод должен существовать в
скрипте ноды `to`, иначе соединение не сработает: проверь его `Grep`. Загрузку сцены
отсутствующий метод не роняет, поэтому проверка из раздела 6 этого не поймает.

## 5. Якоря для портретных телефонов (16:9, 19,5:9, 20:9)

Значения якорей сняты с Godot 4.7.2 (`set_anchors_and_offsets_preset`, все 16
пресетов).

- **Отступы** считаются от размера элемента W×H: это расчёт, а не данные движка.
- **`grow_*`**: `0` = влево / вверх, `1` = вправо / вниз, `2` = в обе стороны. Направление
  выбирай от прижатого края: при вызове из кода движок grow не ставит, его дописывает
  редактор.

| `anchors_preset` | anchor L / T / R / B | offset (W×H) | grow H / V | Где нужен на телефоне |
|---|---|---|---|---|
| 0 TOP_LEFT | 0 / 0 / 0 / 0 | R=W, B=H | 1 / 1 | редко |
| 1 TOP_RIGHT | 1 / 0 / 1 / 0 | L=−W, B=H | 0 / 1 | кнопка меню |
| 2 BOTTOM_LEFT | 0 / 1 / 0 / 1 | T=−H, R=W | 1 / 0 | — |
| 3 BOTTOM_RIGHT | 1 / 1 / 1 / 1 | L=−W, T=−H | 0 / 0 | — |
| 4 CENTER_LEFT | 0 / .5 / 0 / .5 | T=−H/2, R=W, B=H/2 | 1 / 2 | — |
| 5 CENTER_TOP | .5 / 0 / .5 / 0 | L=−W/2, R=W/2, B=H | 2 / 1 | заголовок |
| 6 CENTER_RIGHT | 1 / .5 / 1 / .5 | L=−W, T=−H/2, B=H/2 | 0 / 2 | — |
| 7 CENTER_BOTTOM | .5 / 1 / .5 / 1 | L=−W/2, T=−H, R=W/2 | 2 / 0 | кнопка «Дальше» |
| 8 CENTER | .5 / .5 / .5 / .5 | ±W/2, ±H/2 | 2 / 2 | окно, бросок d20 |
| 9 LEFT_WIDE | 0 / 0 / 0 / 1 | R=W | 1 / 2 | — |
| 10 TOP_WIDE | 0 / 0 / 1 / 0 | B=H | 2 / 1 | **верхняя панель** (цель, прогресс) |
| 11 RIGHT_WIDE | 1 / 0 / 1 / 1 | L=−W | 0 / 2 | — |
| 12 BOTTOM_WIDE | 0 / 1 / 1 / 1 | T=−H | 2 / 0 | **панель вариантов** |
| 13 VCENTER_WIDE | .5 / 0 / .5 / 1 | L=−W/2, R=W/2 | 2 / 2 | — |
| 14 HCENTER_WIDE | 0 / .5 / 1 / .5 | T=−H/2, B=H/2 | 2 / 2 | — |
| 15 FULL_RECT | 0 / 0 / 1 / 1 | 0 | 2 / 2 | **корень, фон, слой эффектов** |

**Рецепт экрана, который не съезжает на 20:9.** Готовый шаблон, проверенный на 1080×1920,
1080×2340 и 1080×2400, — `templates/reading_screen.tscn`.

1. Корень `Control` с пресетом FULL_RECT и `layout_mode = 3`.
2. Фон FULL_RECT с `mouse_filter = 2` (IGNORE), иначе он съест нажатия.
3. `MarginContainer` FULL_RECT — безопасные поля. Сверху и снизу отступы больше, чем по
   бокам (вырез камеры, жестовая полоса). Настоящие размеры безопасной зоны задаются из
   кода; API безопасной зоны в `docs/engine-reference/godot/` не описан, поэтому он
   `NOT SOURCEABLE`.
4. Внутри — `VBoxContainer`:
   - верхняя панель;
   - `ScrollContainer` с `size_flags_vertical = 3`: забирает всю лишнюю высоту, поэтому
     на 20:9 растёт текст, а не дыра;
   - внизу — `VBoxContainer` с кнопками.
5. Никаких абсолютных `position` у элементов интерфейса.
6. При базовой ширине 1080 px и растяжении `canvas_items` 1 dp ≈ 3 px. Касание
   48 dp (`interaction-pattern-library-guide-standard-controls.md`) ≈ 144 px, отсюда
   `custom_minimum_size = Vector2(0, 144)` у кнопок.

**Настройки проекта.** Без них якоря не помогут. В `project.godot` сейчас нет раздела
`[display]`. Его ключи (имена сверены с бинарником 4.7.2):

- `display/window/handheld/orientation` — портрет;
- `display/window/stretch/mode`;
- `display/window/stretch/aspect`.

Значения по умолчанию в 4.7 — в `docs/engine-reference/godot/modules/ui.md`. Правка
`project.godot` — отдельное изменение, спроси «May I write…».

## 6. Проверка (обязательно после каждой ручной правки)

```bash
godot --headless --path . --import
godot --headless --path . -s res://.claude/scripts/godot-scene-check.gd -- res://path/scene.tscn res://path/theme.tres
```

- Код выхода `0` — всё загрузилось, `1` — что-то не загрузилось (ошибка движка выше
  строки `LOAD FAIL`), `2` — не передан файл.
- Для сцены скрипт печатает дерево нод и число соединений: сверь их с тем, что
  собирался написать.
- Загрузилась ещё не значит «выглядит правильно». Дальше идут:
  - `godot-mobile-auditor` и `mobile-ux-validator` по таблице QA-лаборатории
    (`CLAUDE.md`);
  - скриншот по `.claude/docs/run-and-observe.md`.
