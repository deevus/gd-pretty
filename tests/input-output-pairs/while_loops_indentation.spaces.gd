class IndentationTest:
    func test_while_in_class():
        # While loop at class method level
        var value = 0
        while value < 5:
            print("Class method loop:", value)
            value += 1

    class InnerClass:
        func inner_method():
            # While loop in nested class
            var inner_val = 0
            while inner_val < 3:
                print("Inner class loop:", inner_val)
                inner_val += 1

func test_deep_indentation():
    if true:
        if true:
            if true:
                # While loop deeply nested in conditions
                var deep_counter = 0
                while deep_counter < 2:
                    print("Deep indentation:", deep_counter)
                    deep_counter += 1

    # While loop with various indented constructs
    var data = [1, 2, 3]
    while data.size() > 0:
        var item = data.pop_back()
        if item > 1:
            match item:
                2:
                    print("Found two")
                3:
                    print("Found three")
                _:
                    print("Something else")

func test_lambda_with_while():
    # While loop inside lambda
    var processor = func():
        var count = 0
        while count < 3:
            print("Lambda while:", count)
            count += 1

    processor.call()

    # Lambda inside while loop
    var iterations = 0
    while iterations < 2:
        var temp_func = func(x): return x * 2
        print("Result:", temp_func.call(iterations))
        iterations += 1

func test_mixed_control_structures():
    # Complex mixing of while with other control structures
    for i in range(3):
        var j = 0
        while j < i:
            if j % 2 == 0:
                match j:
                    0:
                        print("Even zero")
                    2:
                        print("Even two")
            else:
                var temp = 0
                while temp < j:
                    print("Nested temp:", temp)
                    temp += 1
            j += 1
