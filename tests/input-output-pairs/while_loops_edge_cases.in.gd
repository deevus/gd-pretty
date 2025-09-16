func test_while_loop_edge_cases():
	# While loop with empty body
	while false:
		pass

	# While loop with single statement body
	var counter = 5
	while counter > 0:
		counter -= 1

	# While loop with complex condition expression
	var a = 10
	var b = 20
	var c = 30
	while (a * b) < (c * 2) and not (a > b or b > c):
		a += 1
		b += 2
		c += 3

	# While loop with lambda in condition
	var condition_func = func() -> bool: return true
	while condition_func.call():
		break

	# While loop with array/dictionary access in condition
	var data = {"running": true, "count": 0}
	var items = [1, 2, 3, 4, 5]
	while data["running"] and data["count"] < items.size():
		print("Item:", items[data["count"]])
		data["count"] += 1
		if data["count"] >= 3:
			data["running"] = false

	# While loop with method chaining in condition
	var obj = ComplexObject.new()
	while obj.get_state().is_valid().check():
		obj.update().process()

	# While loop with continue and break
	var num = 0
	while num < 10:
		num += 1
		if num % 3 == 0:
			continue
		if num > 7:
			break
		print("Number:", num)

	# While loop with try-catch equivalent (using error handling)
	var attempts = 0
	while attempts < 5:
		var result = risky_operation()
		if result.is_ok():
			break
		attempts += 1
		print("Attempt", attempts, "failed")

func risky_operation():
	return {"is_ok": func(): return true}

class ComplexObject:
	func get_state():
		return self

	func is_valid():
		return self

	func check() -> bool:
		return true

	func update():
		return self

	func process():
		pass