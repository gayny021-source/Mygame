class_name OptionView
extends RefCounted
## One option card as RunSession prepares it (reading-screen.md, Dependencies; choice-system.md, rules 1,
## 4, 7, 8). The UI only draws `state` and `caption`; a touch on any state but OPEN must not be passed on.

## OPEN takes a touch; CLOSED is shut by a hindrance (`reason` says which); INACTIVE waits for the stake
## to be read; CHOSEN is the option taken; BLOCKED is every other option after the choice.
enum State { OPEN, CLOSED, INACTIVE, CHOSEN, BLOCKED }

var option: OptionData
var state: State = State.OPEN
## «Сила +4 · Средне 13 · шанс 60 %», «Без броска[ · цена]» or «Сила закрыта: причина».
var caption: String
## Title of the hindrance that closes the option; empty otherwise.
var reason: String
