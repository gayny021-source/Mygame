extends GdUnitTestSuite
## Boot scene smoke: it instantiates and carries a non-empty title label.
## The scene is not added to the tree and the Back notification is never sent,
## so boot.gd cannot call quit().

const BOOT_SCENE := "res://src/boot/boot.tscn"
const TITLE_PATH := "Safe/Title"


func test_boot_scene_instantiated_contains_title_label() -> void:
	# Arrange
	var packed: PackedScene = load(BOOT_SCENE)
	assert_object(packed).is_not_null()

	# Act
	var boot: Control = auto_free(packed.instantiate())
	var title := boot.get_node_or_null(TITLE_PATH) as Label

	# Assert
	assert_object(title).is_not_null()
	assert_str(title.text).is_not_empty()
