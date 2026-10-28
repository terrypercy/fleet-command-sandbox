extends GdUnitTestSuite

## Proves the gdUnit4 runner discovers and executes suites under tests/.
## Not a gameplay test: delete it once real unit tests exist.


func test_runner_executes_suite_returns_expected_sum() -> void:
	# Arrange
	var first: int = 2
	var second: int = 3

	# Act
	var total: int = first + second

	# Assert
	assert_int(total).is_equal(5)
