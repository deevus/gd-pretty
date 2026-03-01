func foo():
	if true:
		pass
	if x==1:
		var a=1
	elif x==2:
		var b=2
	else:
		var c=3
	if x>0 and y<10:
		return x
	elif x==0:
		return 0
	elif x<0:
		return -1
	else:
		return -2

func bar():
	if condition: # inline comment
		pass
	elif other: # another comment
		pass
	else: # final comment
		pass

func nested():
	if a:
		if b:
			pass
		else:
			pass
	elif c:
		if d:
			pass
	else:
		pass
