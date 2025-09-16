func test_while_loops_with_comments():
	# While loop with inline comment after colon
	while true: # This comment should be preserved
		print("loop body")
		break

	# While loop with comment before condition
	# This is a counter loop
	var i = 0
	while i < 10: # Loop until we reach 10
		print(i) # Print current value
		i += 1 # Increment counter

	# While loop with multiline comments
	"""
	Complex while loop with comments everywhere
	"""
	var running = true
	while running: # Main game loop
		# Process input
		handle_input()

		# Update game state
		update_game() # Core update logic

		# Render frame
		render() # Draw everything

		# Check exit condition
		if should_exit(): # Time to quit?
			running = false # Set flag to exit

	# While loop with comment between condition and body
	while is_active():
		# Important: this comment should be preserved
		do_work()

	# While loop with comment after body
	while has_work():
		process_work()
	# End of work processing

func handle_input():
	pass

func update_game():
	pass

func render():
	pass

func should_exit() -> bool:
	return false

func is_active() -> bool:
	return true

func do_work():
	pass

func has_work() -> bool:
	return false

func process_work():
	pass