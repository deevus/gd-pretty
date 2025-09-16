class Example:
    # Comment at start of class body
    var x = 1 

    # Comment between statements
    var y = 2 

    func first():
        # Comment at start of function body
        var a = 1 
        # Comment between statements in function
        var b = 2 
        # Comment at end of function body

    # Comment between functions
    func second():
        pass

    # Comment at end of class body
# Comments with special content
func unicode_test():
    # Unicode: 你好, symbols: @#$%^&*, code: var x = "hello"
    var z = 3 
# Multiple consecutive comments
func multiple_comments():
    # First comment
    # Second comment
    # Third comment
    var result = 42 
# Empty comments
func empty_comments():
    #
    var data = [] 
    #
# Mixed inline and standalone comments
func mixed_comments():
    var start = 0  # inline comment
    # standalone comment
    var end = 100  # another inline comment
    # final standalone comment