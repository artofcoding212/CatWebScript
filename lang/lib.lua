require("lang.grammar")
require("lang.ir")

--- @param x any
--- Deep prints `x`.
function _G.dump(x)
    if type(x)=="string" then
        io.write(string.format('"%s"', x))
        return
    end

    if type(x)~="table" then
        io.write(tostring(x))
        return
    end

    io.write("{ ")
    for k,v in pairs(x) do
        dump(k)
        io.write(": ")
        dump(v)
        io.write(", ")
    end
    io.write("}")
end

--- @type table<string,function>
local tests = {
    parsing=function()
        local p = Parser.new('fn main(){ if x == 2 {} else { 2+2 } }', Grammar)
        p:parse()
        dump(p.output)
        print()
    end,
    irGen=function()
        local p = Parser.new('fn main(){ a = 1 b = 2 if a==b { console.log("hi") console.log("test") } else { console.log("hi") console.log("test") }}',Grammar)
        p:parse()
        local ir = Ir.new(p.output)
        ir:gen()
        dump(ir.out)
        print()
    end,
    compilation=function()
        local p = Parser.new('fn main(){console.log("hi") console.log("test")}',Grammar)
        p:parse()
        local ir = Ir.new(p.output)
        ir:gen()
        print(ir:compile())
    end,
}

return {
    runUnitTests=function()
        print("RUNNING CATWEBSCRIPT UNIT TESTS")
        local f,s=0,0
        for name, fn in pairs(tests) do
            io.write(string.format("| test %s.. ", name))
            local succ, err = pcall(fn)
            if not succ then
                f = f+1
                print(string.format("\n  | FAIL:\n\t%s",err))
                goto continue
            end
            s = s+1
            print("  | OK")
            ::continue::
        end
        print(string.format("| %d test(s) passed, %s test(s) failed", s,f))
    end,
}