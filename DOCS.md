# Documentation
The documentation for CatWebScript.

# Syntax

* Variables\
To define a variable, use the following syntax:\
```x = y```\
Where the left side of it is the varaiable name, and the right side is the value to assign it to.
This is also the syntax for reassigning variables.\
Variable names *cannot* be censored thanks to a trick in the compiler.
* Literal Expressions\
Numbers can be written using the characters 0-9 and can have decimal portions.\
Strings are written with the `"string"` syntax.\
Booleans are written with 1 being true and 0 being false. Feel free to define your own utility variables for this.\
You can get the inner value of a variable with the `varname` syntax.
* Mathematical Expressions\
You can use mathematical operations with the `l op r` syntax, where the following operators exist:
    * *Regular Mathematical Operations*
    * `+`, addition
    * `-`, subtraction
    * `*`, multiplication
    * `/`, division
    * `%`, modulo
    * `^`, raise to the power
    * *Conditionals* (gives 1 if true, 0 if false)
    * `>=`, greater than or equal to
    * `>`, greater than
    * `<=`, less than or equal to
    * `<` less than
    * `==`, equals
    * `!=`, does not equal
    * `&&`, x and y
    * `||`, x or y
    * *Misc*
    * `..`, concatenate strings
* `If` statements\
    You can determine if something is `true`, or 1, via the `if condition {}` syntax.\
    Within the curly braces is the logic that will happen if the given condition equates to 1.\
    However, if it equates to 0, or something other than 1, then nothing happens, unless you add an `else` block after it, and if you want, you can add even more ifs and elses after the `else` keyword.\
    Take this example:
    ```
    username = "not loaded"
    if username != "not loaded" {
        console.log("Greetings!")
    } else if username == "admin" {
        console.log("Hey there, admin!")
    } else {
        console.log("You're not loaded yet.")
    }
    ```
    In this example, if the username is loaded, it'll move on to that branch. Otherwise, it'll go and check if the username is "admin". If it's not, then it'll log "You're not loaded yet". Think about what it should log. Did you say "You're not loaded yet."? If you did, you'd be correct!
* `fn` statements, function calling, and function returnages\
    Your code can't immediately run from the file scope like in Python. You must define an *entry point*, which is where your code first runs when it's executing. In CatWebScript, you can have multiple entry points. To define an entry point, you can use the `fn` syntax, but provide the name to be "main".\
    The function definition syntax is similar to that of Rust's:
    ```
    fn hi(arg1,arg2){
        # your code here
    }
    ```
    First, it starts with the `fn keyword`. Then comes the function name. Then, in parenthesis, comes your function arguments. Finally comes the inner logic of your function.\
    You can *call* functions, or run the inner logic of the function, via the `name(arg)` syntax, and can return with the `return` syntax.\
    Here's a quick example:
    ```
    fn main(){
        console.log(greet("Dee")) # Hey, Dee!
    }

    fn greet(msg){
        return "Hey, "..msg.."!"
    }
    ```
# Libraries
CatWeb comes with a vast amount of things you can do in its block language, and it's hard to implement them as statements. So, our solution is to implement them as *libraries*, or in some cases as direct callables.
* `console` library
    * `console.log(msg: any)` Writes `msg` to the F9 console or in the Editor console.\
    Example:
        ```
        console.log("Hello, world!")
        ```
    * `console.warn(msg: any)` Writes `msg` to the F9 console or in the Editor console in orange text.\
    Example:
        ```
        console.warn("Something went wrong.")
        ```
    * `console.error(msg: any)` Halt code execution and throw a new exception, `msg`.\
    Example:
        ```
        console.error("Code 404")
        ```
* `string` "library"
    * `.split(splitter: string) -> array<string>` Splits the given string by the `splitter`. An example would be splitting `dog` by `o`, which would give `["d","g"]`.\
    Example:
        ```
        split = "dog".split("o")
        console.log(split[1]) # d
        console.log(split[2]) # g
        ```
    * `.length() -> number` Gets the length of the string.\
    Example:
        ```
        console.log("a".length()) # 1
        ```
* `table` "library"
    * `Array(...any) -> array<any>` Create a new Array with the given elements.\
    Example:
        ```
        hi = Array(1,2,3)
        console.log(hi[1]..hi[2]..hi[3]) # 123
        ```
    * `.insert(element: any, optional position: number?)` Insert the given element to the end of the array or at the given index, which is an optional parameter.\
    Example:
        ```
        hi = Array(1,2)
        hi.insert(3)
        console.log(hi[3]) # 3
        ```
    * `.removeKey(key: any)` Remove the entry at the key. See `remove` for arrays.\
    Example:
        ```
        hi = {x: 1, y: 2}
        hi.removeKey("x")
        console.log(hi.keys().count()) # 1
        ```
    * `.remove(optional index: number?)` Remove the index at the array, shifting the elements accordingly. See `removeKey` for dictionaries.\
    Example:
        ```
        hi = Array(1,2,3)
        hi.remove(2)
        console.log(hi.count()) # 2
        ```
    * `.pop() -> any` Pops off the end of the given array by removing the entry at the length of the table. Returns the entry.\
    Example:
        ```
        hi = Array(1,82)
        console.log(hi.pop()) # 82
        console.log(hi.count()) # 1
        ```
    * `.count() -> number` Return the number of elements in the array.\
    Example:
        ```
        hi = Array(1,2,3)
        console.log(hi.count()) # 3
        ```
    * `.keys() -> array<any>` Return the keys of the table/dictionary.\
    Example:
        ```
        hi = { x: 2, y: 3 }
        # hi.keys() == ["x","y"]
        console.log(hi.keys().count()) # 2
        ```
    * `.values() -> array<any>` Return the values of the table/dictionary.\
    Example:
        ```
        hi = Array(2,3)
        # hi.values() == [2,3]
        console.log(hi.values().count()) # 2
        # ^ Note: .values() on an array is useless and is bad practice as it just returns the same array with overhead. It could potentially clone the array, though you shouldn't need to do that.
        ```