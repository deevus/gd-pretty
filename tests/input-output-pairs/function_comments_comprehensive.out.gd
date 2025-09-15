# Comprehensive function comment test cases

# Basic function with inline comment

func foo(): # comment
    pass
# Function with parameters and inline comment

func bar(x: int, y: String): # parameter comment
    pass
# Static function with inline comment

static func example(): # static comment
    pass
# Function with return type and inline comment

func baz() -> int: # return comment
    return 42
# Function with empty comment

func test(): #
    pass
# Function with special characters in comment

func special(): # Unicode: 你好, symbols: @#$%^&*(), code: `print("hello")`
    pass
# Multiple comments between signature and body

func multiple():
    # first comment
    # second comment

    pass
# Class method with inline comment

class TestClass:
    func method(): # method comment
        pass
    static func static_method(param: int) -> String: # static method with return type
        return "test"
# Function overloading with different signatures and comments

func overloaded(): # no params
    pass
func overloaded(x: int): # one param
    pass
func overloaded(x: int, y: String): # two params
    pass