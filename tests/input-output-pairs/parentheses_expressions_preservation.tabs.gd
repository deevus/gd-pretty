class X:
	func foo(ev):
		var x = not (ev is InputEventMouseButton and (ev.button_index == BUTTON_WHEEL_DOWN or ev.button_index == BUTTON_WHEEL_UP))