require("frontend")

local grammar = ParseRules.new()
grammar:newToken("+","Plus")
grammar:newToken("-","Minus")
grammar:newToken("*","Star")
grammar:newToken("/","Slash")
grammar:newToken("%","Percent")
grammar:newToken("^","Up")
grammar:newToken(",","Comma")
grammar:newToken(".","Dot")
grammar:newToken("..","DotDot")
grammar:newToken(":","Colon")
grammar:newToken("(","LeftParen")
grammar:newToken(")","RightParen")
grammar:newToken("{","LeftBrace")
grammar:newToken("}","RightBrace")
grammar:newToken("[","LeftBrack")
grammar:newToken("]","RightBrack")
grammar:newToken(">","Greater")
grammar:newToken(">=","GreaterEqs")
grammar:newToken("<","Less")
grammar:newToken("<=","LessEqs")
grammar:newToken("==","EqualsEquals")
grammar:newToken("!=","NotEquals")
grammar:newToken("&&","And")
grammar:newToken("||","Or")

--? statements

--- @param parser Parser
--- @param typed boolean
--- @return AstNode[]
--- Parse a list of arguments (i.e. "(1, 2, 3, test)"). When `typed` is true, parses as "(x: Type, y:Type)".
local function parseArgs(parser,typed)
    local args = {}

    if typed then
        while parser.curr.t~="RightParen" do
            parser:consume("Id")
            local name = parser.prev.val
            --parser:consume("Colon")
            --parser:consume("Id")
            --table.insert(args,{name=name,t=parser.prev.val})
            table.insert(args,{name=name,t="Any"})
            if parser.curr.t~="RightParen" then
                parser:consume("Comma")
            end
        end
    else
        while parser.curr.t~="RightParen" do
            parser:expr()
            table.insert(args,table.remove(parser.output,#parser.output))
            if parser.curr.t~="RightParen" then
                parser:consume("Comma")
            end
        end
    end

    parser:consume("RightParen")
    return args
end

--- @param parser Parser
--- @return AstNode[]
--- Parses a block of statements (i.e. "{ x = 2+2 }")
local function parseBlock(parser)
    local body = {}
    parser:consume("LeftBrace")

    while parser.curr.t~="RightBrace" do
        parser:stmt()
        table.insert(body, table.remove(parser.output,#parser.output))
    end

    parser:consume("RightBrace")
    return body
end

--- @param parser Parser
grammar:stmt("fn", function(parser)
    parser:consume("Id")
    local name = parser.prev.val
    parser:consume("LeftParen")
    table.insert(parser.output, {type="Function", value={ name=name, col=parser.prev.col, ln=parser.prev.ln, args=parseArgs(parser,true), body=parseBlock(parser) }})
end)

--- @param parser Parser
grammar:stmt("return", function(parser)
    parser:expr()
    table.insert(parser.output, {type="Return", value=table.remove(parser.output,#parser.output)})
end)

--- @param parser Parser
grammar:stmt("if", function(parser)
    parser:expr()
    --- @type AstNode
    local ifNode = {type="If", value={condition=table.remove(parser.output,#parser.output),body=parseBlock(parser),otherwise=nil}}
    local writeNode = ifNode

    while parser.curr.val == "else" do
        parser:adv()
        local node = writeNode
        if parser.curr.val == "if" then
            parser:adv()
            parser:expr()
            node.value.otherwise = {type="If", value={condition=table.remove(parser.output,#parser.output),body=parseBlock(parser),otherwise=nil}}
            writeNode = node.value.otherwise
            goto continue
        end
        node.value.otherwise = {type="Else", value=parseBlock(parser)}
        writeNode = node.value
        ::continue::
    end
    
    table.insert(parser.output, ifNode)
end)

--? expressions

local prec = {
    None=0,
    Assignment=1,
    Or=2,
    And=3,
    Equality=4,
    Comparison=5,
    Object=6,
    Term=7,
    Factor=8,
    Unary=9,
    Power=10,
    Call=11,
    Primary=12,
    Member=13,
}

grammar:expr(prec.None, "Number", {
    --- @param parser Parser
    --- @param utils ParserUtils
    prefix=function(parser,utils)
        table.insert(parser.output, {type="Number",value=tonumber(parser.prev.val) or 0,col=parser.currIdx,ln=parser.currLn})
    end,
})

grammar:expr(prec.None, "String", {
    --- @param parser Parser
    --- @param utils ParserUtils
    prefix=function(parser,utils)
        table.insert(parser.output, {type="String",value=parser.prev.val,col=parser.currIdx,ln=parser.currLn})
    end,
})

grammar:expr(prec.None, "Id", {
    --- @param parser Parser
    --- @param utils ParserUtils
    prefix=function(parser,utils)
        local name = parser.prev.val
        if utils.canAssign and parser:match("Equals") then
            parser:expr()
            table.insert(parser.output, {type="Assignment",value={
                name=name,
                right=table.remove(parser.output, #parser.output),
            },col=parser.currIdx,ln=parser.currLn})
        else
            table.insert(parser.output, {type="Id",value=name,col=parser.currIdx,ln=parser.currLn})
        end
    end,
})

grammar:expr(prec.Call, "Dot", {
    --- @param parser Parser
    --- @param utils ParserUtils
    infix=function(parser,utils)
        local left = table.remove(parser.output,#parser.output)
        parser:consume("Id")
        local right = parser.prev
        if utils.canAssign and parser:match("Equals") then
            parser:expr()
            table.insert(parser.output, {type="Assignment",value={
                name=left,
                right=table.remove(parser.output,#parser.output),
            },col=parser.currIdx,ln=parser.currLn})
        else
            table.insert(parser.output, {type="Member",value={
                left=left,
                right={type=right.t,value=right.val},
            },col=parser.currIdx,ln=parser.currLn})
        end
    end,
})

grammar:expr(prec.Call, "LeftBrack", {
    --- @param parser Parser
    --- @param utils ParserUtils
    infix=function(parser,utils)
        local left = table.remove(parser.output,#parser.output)
        parser:expr()
        local right = table.remove(parser.output,#parser.output)
        parser:consume("RightBrack")
        if utils.canAssign and parser:match("Equals") then
            parser:expr()
            table.insert(parser.output, {type="Assignment",value={
                name={type="ComputedMember",value={
                    left=left,
                    right=right,
                }},
                right=table.remove(parser.output,#parser.output),
            },col=parser.currIdx,ln=parser.currLn})
        else
            table.insert(parser.output, {type="ComputedMember",value={
                left=left,
                right=right,
            },col=parser.currIdx,ln=parser.currLn})
        end
    end,
})

grammar:expr(prec.Call, "LeftParen", {
    --- @param parser Parser
    --- @param utils ParserUtils
    infix=function(parser,utils)
        local callee = table.remove(parser.output,#parser.output)
        table.insert(parser.output, {type="Call",value={
            left=callee,
            args=parseArgs(parser,false),
        },col=parser.currIdx,ln=parser.currLn})
    end,
})

grammar:expr(prec.None, "LeftBrace", {
    --- @param parser Parser
    --- @param utils ParserUtils
    prefix=function(parser,utils)
        local tbl = {}
        while parser.curr.t~="RightBrace" and parser.curr.t~="EndOfFile" do
            parser:consume("Id")
            local name = parser.prev.val
            parser:consume("Colon")
            parser:expr()
            if parser.curr.t ~= "RightBrace" then
                parser:consume("Comma")
            end
            tbl[name] = table.remove(parser.output,#parser.output)
        end
        parser:match("Comma") --? trailing comma
        parser:consume("RightBrace")
        table.insert(parser.output, {type="Object",value=tbl,col=parser.currIdx,ln=parser.currLn})
    end,
})

--- @param parser Parser
--- @param utils ParserUtils
local function binary(parser,utils,t)
    local b = table.remove(parser.output, #parser.output)
    local op = parser.prev.t
    local rule = parser.rules.exprs[op]
    parser:expr(rule.prec+1)
    local a = table.remove(parser.output, #parser.output)
    table.insert(parser.output, {type="Binary", value={left=b,right=a,op=op}})
end

--- @param parser Parser
--- @param utils ParserUtils
local function cmp(parser,utils,t)
    local b = table.remove(parser.output, #parser.output)
    local op = parser.prev.t
    local rule = parser.rules.exprs[op]
    parser:expr(rule.prec+1)
    local a = table.remove(parser.output, #parser.output)
    table.insert(parser.output, {type="Comparison", value={left=b,right=a,op=op}})
end

grammar:expr(prec.Term,   "Plus",    {infix=binary})
grammar:expr(prec.Term,   "Minus",   {infix=binary})
grammar:expr(prec.Factor, "Star",    {infix=binary})
grammar:expr(prec.Factor, "Slash",   {infix=binary})
grammar:expr(prec.Factor, "Percent", {infix=binary})
grammar:expr(prec.Factor, "Up",      {infix=binary})
grammar:expr(prec.Factor, "DotDot",  {infix=binary})
grammar:expr(prec.Factor, "Greater",      {infix=cmp})
grammar:expr(prec.Factor, "GreaterEqs",   {infix=cmp})
grammar:expr(prec.Factor, "Less",         {infix=cmp})
grammar:expr(prec.Factor, "LessEqs",      {infix=cmp})
grammar:expr(prec.Factor, "EqualsEquals", {infix=cmp})
grammar:expr(prec.Factor, "NotEquals",    {infix=cmp})
grammar:expr(prec.And,    "And",          {infix=cmp})
grammar:expr(prec.Or,     "Or",           {infix=cmp})

_G.Grammar = grammar