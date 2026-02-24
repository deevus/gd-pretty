func test_basic_while_loops():
    # Simple while loop with basic condition
    while true:
        print("infinite loop")
        

        # While loop with variable condition
    var counter = 0
    while counter < 10:
        print(counter)
        counter += 1

        # While loop with complex boolean condition
    var running = true
    var health = 100
    while running and health > 0:
        health -= 1
        if health == 50:
            running = false

    # While loop with method call condition
    while is_valid():
        process_frame()

        # While loop with property access condition
    while player > 0:
        player.take_damage(1)
func is_valid() -> bool:
    return true
func process_frame():
    pass
class Player:
    var health: int = 100

    func take_damage(amount: int):
        health -= amount
var player = Player.new()