func test_nested_while_loops():
	# Simple nested while loops
	var i = 0
	while i < 3:
		var j = 0
		while j < 3:
			print("i:", i, " j:", j)
			j += 1
		i += 1

	# Deeply nested while loops
	var x = 0
	while x < 2:
		var y = 0
		while y < 2:
			var z = 0
			while z < 2:
				print("Coordinates: ", x, y, z)
				z += 1
			y += 1
		x += 1

	# Mixed control flow with while loops
	var count = 0
	while count < 5:
		if count % 2 == 0:
			var temp = 0
			while temp < count:
				print("Even iteration:", temp)
				temp += 1
		else:
			for k in range(count):
				print("Odd iteration:", k)
		count += 1

	# While loop inside function inside while loop
	var outer = 0
	while outer < 3:
		var process_inner = func():
			var inner = 0
			while inner < 2:
				print("Inner:", inner, "Outer:", outer)
				inner += 1
		process_inner.call()
		outer += 1
