local lib = require("lang.lib")

local function usageError()
    error("USAGE: catwebscript [file]")
end

if #arg==1 and arg[1]=="test" then
    lib.runUnitTests()
    return
elseif #arg<=0 then
    usageError()
end

local file = io.open(arg[1], "r")
if file == nil then
    usageError()
    error()
end

local contents = file:read("a")
file:close()

local p = Parser.new(contents, Grammar)
p:parse()
local ir = Ir.new(p.output)
ir:gen()

local json = ir:compile()

file = io.open(arg[1]..".json", "w")
if file == nil then
    error("\nunable to write to JSON file:\n"..json)
end
file:write(json)