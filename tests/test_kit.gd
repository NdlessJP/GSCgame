class_name TestKit
extends RefCounted
## Tiny assertion helper shared by the test suites.

class Result:
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []

	func ok(condition: bool, message: String) -> void:
		if condition:
			passed += 1
		else:
			failed += 1
			failures.append(message)

	func approx(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
		ok(absf(actual - expected) <= tolerance, "%s (expected %.4f, got %.4f)" % [message, expected, actual])

	func merge(other: Result) -> void:
		passed += other.passed
		failed += other.failed
		for failure: String in other.failures:
			failures.append(failure)
