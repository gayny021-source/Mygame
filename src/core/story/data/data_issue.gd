class_name DataIssue
extends RefCounted
## One finding about story data: a loader code DT-NN or a graph code BS-NN (ADR-0001, Key Interfaces).

const ERROR := "error"

var code: String
var severity: String = ERROR
var path: String
var object_id: String
var message: String


func _init(issue_code: String, issue_path: String, issue_object_id: String, issue_message: String) -> void:
	code = issue_code
	path = issue_path
	object_id = issue_object_id
	message = issue_message
