func foo():
	for i in range(10):
		pass
	for item in [1, 2, 3]:
		print(item)
	for key in dictionary:
		print(key)

func bar():
	for i in range(10): # inline comment
		pass

func typed():
	for i: int in [1, 2, 3]:
		print(i)

func nested():
	for i in range(3):
		for j in range(3):
			print(i, j)

func with_body():
	for i in range(5):
		if i > 2:
			break
		print(i)
		continue
