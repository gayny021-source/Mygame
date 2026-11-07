---
name: procedural-art-sfx
description: "Make graphics and sound with code only — crisp SVG icons and sprites as text, 2D .gdshader effects (flash, glow, water, shadow, old film), procedural SFX in GDScript (baked AudioStreamWAV or live AudioStreamGenerator). Read before drawing an asset, writing a shader or adding a sound."
argument-hint: "[svg | shader | sfx] [what to make]"
user-invocable: false
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(godot --headless *)
---

# Графика и звук без внешних программ

Справочник для агентов. Графического редактора и звуковой студии у проекта нет, поэтому
всё делается текстом и кодом.

> **Проверено на Godot 4.7.2 (2026-11-07).**
> - Импорт SVG и пиксели после растеризации проверены.
> - Все шейдеры из `examples/shaders/` компилируются; сломанный шейдер компиляцию
>   роняет.
> - Звуки из `examples/sfx_synth.gd` собираются, `AudioStreamGenerator` создаётся.
> - Вид на телефоне headless не показывает: смотри скриншотом и на устройстве.

**Сначала столпы.** Стиль игры — цветная анимация 1930-х; сцены статичные (анти-столп
«NOT озвучка и анимированные сцены»), а музыка и звуки — уровень Full Vision в
`design/gdd/systems-index.md`. Удары, взрывы и вода ниже — общие приёмы. В этой игре
они нужны точечно: бросок d20, критический успех или провал, переход между сценами,
эффект старой плёнки. Не повторяй узнаваемый стиль конкретной существующей игры: только
общий стиль эпохи.

## а) SVG: иконки и спрайты текстом

Godot растеризует SVG один раз, при импорте (ThorVG). Проверено на 4.7.2:

| Возможность SVG | Результат в 4.7.2 |
|---|---|
| `path`, `circle`, `rect rx`, `stroke`, `linecap/linejoin` | работает |
| `linearGradient` (и радиальный по той же схеме) | работает |
| `<style>` с классами CSS | работает |
| `mask` | работает |
| `filter` с `feGaussianBlur` | работает (размытие видно) |
| **`<text>`** | **молча не рисуется** (0 непрозрачных пикселей) |

Правила:

- **Текст в SVG не пиши.** Буквы — кривыми (`path`), а надписи интерфейса — нодой
  `Label` или `RichTextLabel`: они масштабируются, переводятся и читаются экранным
  диктором.
- **Размер.** `width` / `height` = размер в пикселях при базовой ширине окна 1080. Для
  чёткости на плотных экранах поднимай `svg/scale` в `.import` (по умолчанию `1.0`), а
  не размер в самом SVG.
- **Стиль 1930-х.**
  - Толстый тёмный контур (`stroke-width` 4–8 при 64–256 px).
  - `stroke-linecap="round"`, `stroke-linejoin="round"`.
  - Плоская заливка 2–4 цветами плюс один градиент на объём.
  - Палитра «старой бумаги»: тёплый жёлтый, кирпичный, тёмно-коричневый вместо
    чёрного.
- **Без внешних ссылок.** Никаких `href` на файлы или шрифты: ThorVG их не подтянет.
- **Проверка.**
  - `godot --headless --path . --import` — в логе не должно быть ошибок по файлу.
  - Глазами — скриншот (`.claude/docs/run-and-observe.md`).
  - Иллюстрации сцен (не иконки) делаются по арт-библии, когда она появится (`/art-bible`).

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="28" fill="#e8b04a" stroke="#1a1410" stroke-width="4"/>
  <path d="M20 34 L30 44 L46 22" fill="none" stroke="#1a1410" stroke-width="6"
        stroke-linecap="round" stroke-linejoin="round"/>
</svg>
```

## б) 2D-шейдеры (`.gdshader`)

Готовые шейдеры в `examples/shaders/` (все `shader_type canvas_item`):

| Файл | Эффект | Чем анимировать |
|---|---|---|
| `hit_flash.gdshader` | вспышка удара или урона: спрайт уходит в цвет | Tween `flash` 1 → 0 за 0,15 с |
| `outline_glow.gdshader` | свечение или обводка вокруг непрозрачных пикселей, с пульсом | `TIME` внутри; `radius_px` |
| `water_wave.gdshader` | вода, жар, «сон» — волна UV | `TIME` внутри |
| `drop_shadow.gdshader` | плоская мультяшная тень от силуэта | `offset_px` |
| `old_film.gdshader` | **старая плёнка**: зерно, виньетка, мерцание, царапины | `TIME` внутри |

Правила:

- **Рендерер — Compatibility** (OpenGL 3.3 / WebGL 2; `project.godot`,
  `modules/rendering.md`). Пиши простой `canvas_item`: без `compute`, без 3D, без
  десятков выборок текстуры.
- **Чем меньше выборок, тем лучше для телефона.** `outline_glow` делает 9 выборок на
  пиксель, это предел для спрайта, но не для полного экрана.
- **Полноэкранный эффект** (`old_film`) — шейдер на `ColorRect` с пресетом FULL_RECT и
  **`mouse_filter = 2`**, иначе слой съест все нажатия.
  - `hint_screen_texture` читает уже нарисованный кадр.
  - Это один полноэкранный проход: замерь кадр на слабом устройстве
    (`/perf-profile`).
- **Прозрачный запас.** Свечению и тени нужны прозрачные поля вокруг спрайта, иначе
  эффект обрежется по краю текстуры.
- **Проверка компиляции headless:** загрузи шейдер и спроси список параметров. Ошибка
  синтаксиса печатает `SHADER ERROR` с номером строки, а список приходит пустым.

  ```gdscript
  var sh := load("res://src/fx/old_film.gdshader") as Shader
  print(sh.get_shader_uniform_list().map(func(u): return u.name))
  ```

  Компилируется — ещё не значит «так выглядит на Mali или Adreno»: смотри на устройстве.

## в) Звук кодом, без `.wav`

Два способа (оба в `examples/`):

1. **Запечь при загрузке → `AudioStreamWAV`** (`examples/sfx_synth.gd`). **По умолчанию
   для коротких звуков.**
   - Готовые функции: щелчок интерфейса `click`, глухой удар `thud`, ретро-взрыв `boom`,
     перестук кубика `dice_rattle`.
   - Звук один раз считается в `PackedFloat32Array` и кладётся в 16-битный PCM
     (`AudioStreamWAV.FORMAT_16_BITS`, 22 050 Гц, моно). Дальше он играет как обычный
     файл, на телефоне нагрузки нет.
   - Случайность только через `RandomNumberGenerator` с зерном: звук повторяем, его
     можно проверить тестом.
2. **Синтез в реальном времени → `AudioStreamGenerator`** (`examples/sfx_stream.gd`).
   - Нужен только для непрерывного звука, который меняется по ходу игры (гул, высота
     тона за прогрессом).
   - Каждый кадр `get_frames_available()` → `push_buffer(PackedVector2Array)`.
   - GDScript считает каждую выборку на CPU телефона, поэтому держи `mix_rate` 22 050,
     `buffer_length` около 0,1 с и не запускай больше одного-двух таких потоков.

Как звучит в 1930-х: короткие щелчки и бум без ревербации; бой барабана и «вжух» —
перепадом высоты (`thud` с f0 → f1). Громкость — через шину (`AudioServer`), а не числами
в коде. Звуковой системы в проекте ещё нет: громкость и шины решит её GDD.

## После работы

- Код (`.gd`) и шейдеры проверяет `godot-mobile-auditor`.
- Слои поверх интерфейса — ещё и `mobile-ux-validator` (`mouse_filter`).
- Анимации с `await` или Tween — ещё и `chaos-monkey`.

Таблица — в `CLAUDE.md`, раздел «QA-лаборатория».
