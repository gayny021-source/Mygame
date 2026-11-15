class_name LoadResult
extends RefCounted
## Result of a loader (ADR-0001 §4): `data` is the loaded structure, or null when `issues` is not empty.

var data: RefCounted
var issues: Array[DataIssue] = []
