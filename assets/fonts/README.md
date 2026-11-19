# Шрифты (решение CEO 2026-11-18, USER_PREFERENCES.md «Шрифт»)

- Literata (OFL 1.1, Google Fonts, google/fonts ofl/literata) — текст и интерфейс. Статические Regular (wght 400), Bold (700), Italic (400) при opsz 12, сделаны из вариативного файла `fonttools varLib.instancer`.
- Yeseva One (OFL 1.1, ofl/yesevaone) — только титры и картуши от ~64 px; знака U+2212 «минус» нет — числа с минусом набирать Literata.
- Сабсет `pyftsubset`: латиница Basic+Latin-1, кириллица U+0400–04FF, пунктуация U+2000–206F, ₽, €, №, ™, U+2212, NBSP; все OpenType-фичи сохранены (у Literata есть `tnum`).
- Лицензии: Literata-OFL.txt, YesevaOne-OFL.txt.
