extends GdUnitTestSuite
## Unit tests for the typed snapshot of released_ids.json (ReleasedIds.read, compare, unchanged; TD S5 round 1,
## G2 and C4): the file content stops at `read`; --freeze keeps a list that already holds the current ids.


func _hero() -> HeroData:
	var hero: HeroData = MeaningFixtures.hero_of([MeaningFixtures.chain(["s1", "s2"])], MeaningFixtures.flags())
	hero.endings = PackedStringArray(["e1"])
	return hero


func _snapshot(hero: HeroData, issues: Array[DataIssue]) -> ReleasedIds.Snapshot:
	return ReleasedIds.read(ReleasedIds.freeze(hero, "2026-11-16"), "t", issues)


func test_read_gives_typed_ids_and_the_date() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var snapshot: ReleasedIds.Snapshot = _snapshot(_hero(), issues)
	# Assert
	assert_array(issues).is_empty()
	assert_str(snapshot.released_at).is_equal("2026-11-16")
	assert_array(snapshot.ids["scenes"]).is_equal(PackedStringArray(["s1", "s2"]))


func test_read_of_another_version_gives_no_snapshot() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	# Act
	var snapshot: ReleasedIds.Snapshot = ReleasedIds.read({"schema_version": 2}, "t", issues)
	# Assert
	assert_object(snapshot).is_null()
	assert_int(GraphFixtures.count(issues, "DT-07")).is_equal(1)


func test_unchanged_is_true_for_the_same_ids() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var snapshot: ReleasedIds.Snapshot = _snapshot(_hero(), issues)
	# Act / Assert
	assert_bool(ReleasedIds.unchanged(_hero(), snapshot)).is_true()


func test_unchanged_is_false_when_the_data_has_a_new_id() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var snapshot: ReleasedIds.Snapshot = _snapshot(_hero(), issues)
	var grown: HeroData = MeaningFixtures.hero_of([MeaningFixtures.chain(["s1", "s2", "s3"])], MeaningFixtures.flags())
	grown.endings = PackedStringArray(["e1"])
	# Act / Assert
	assert_bool(ReleasedIds.unchanged(grown, snapshot)).is_false()


func test_compare_names_the_lost_id() -> void:
	# Arrange
	var issues: Array[DataIssue] = []
	var snapshot: ReleasedIds.Snapshot = _snapshot(_hero(), issues)
	snapshot.ids["scenes"].append("s9")
	# Act
	var lost: Array[DataIssue] = ReleasedIds.compare(_hero(), snapshot, "t/ids")
	# Assert
	assert_int(lost.size()).is_equal(1)
	assert_str(lost[0].object_id).is_equal("s9")
