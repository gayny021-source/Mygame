class_name D20Check
extends RefCounted
## The d20 check (d20-checks.md, rules 4-6, 9 and formulas 1, 2, 5, 6; ADR-0001 §6; story S7).
## The static functions are pure: the chance and N take only the DC and the bonus (AC-19).
## An instance owns the config and the one call of the source per roll; it never reads RunState.
##
## Usage: [code]var result: D20Result = D20Check.new(config, source).roll(check, hero)[/code]

var _config: D20Config
var _source: D20Source


func _init(config: D20Config, source: D20Source) -> void:
	_config = config
	_source = source


## Smallest face that succeeds (formula 2): 2…20, the faces 1 and 20 decide the edges.
static func need(dc: int, bonus: int) -> int:
	return clampi(dc - bonus, 2, 20)


## Chance in percent (formula 2): 5…95, step 5.
static func chance(dc: int, bonus: int) -> int:
	return (21 - need(dc, bonus)) * 5


## Formula 1: 20 always succeeds, 1 never; otherwise total >= DC, a tie goes to the hero.
static func succeeds(n: int, bonus: int, dc: int) -> bool:
	return n == 20 or (n != 1 and n + bonus >= dc)


## Result of the face `n` of `check` at `bonus` and `dc`.
static func resolve(check: CheckData, bonus: int, dc: int, n: int, rerolled: bool) -> D20Result:
	var result: D20Result = D20Result.new()
	result.check_id = check.id
	result.stat_id = check.stat
	result.roll = n
	result.bonus = bonus
	result.total = n + bonus
	result.dc = dc
	result.success = succeeds(n, bonus, dc)
	result.outcome_id = check.success if result.success else check.failure
	result.bonus_decided = result.success != succeeds(n, 0, dc)
	result.rerolled = rerolled
	if n == 20:
		result.crit = D20Result.Crit.SUCCESS
		result.crit_line = check.crit_success_line.strip_edges()
	elif n == 1:
		result.crit = D20Result.Crit.FAILURE
		result.crit_line = check.crit_failure_line.strip_edges()
	return result


## The result of a saved roll by the record's own numbers, not the config's (AC-21: a balance
## patch does not change a roll already made).
static func restore(record: RollRecord, check: CheckData) -> D20Result:
	var result: D20Result = resolve(check, record.bonus, record.dc, record.roll, record.rerolled)
	result.stat_id = record.stat_id
	return result


## Bonus of the stat `stat_id` of `hero`; the loader guarantees the stat exists (BS-01).
static func bonus_of(hero: HeroData, stat_id: String) -> int:
	for stat: StatData in hero.stats:
		if stat.id == stat_id:
			return stat.bonus
	return 0


## DC of the level of `check` from the config (formula 3).
func dc_of(check: CheckData) -> int:
	return _config.dc(check.level)


## A new roll: the one call of the source for this check.
func roll(check: CheckData, hero: HeroData) -> D20Result:
	var bonus: int = bonus_of(hero, check.stat)
	var dc: int = dc_of(check)
	return resolve(check, bonus, dc, _source.roll(), false)
