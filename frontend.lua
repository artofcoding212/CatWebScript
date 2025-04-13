--- @alias Token {t:string, val:string, col:number, ln:number}
--- @alias ExprRule {prefix:function?,infix:function?,prec:number}
--- @alias TokenEntry Token|{match:string,val:TokenEntry}
--- @alias ParserUtils {canAssign:boolean}
--- @alias AstNode {type:string,value:any,col:number,ln:number}

--- @param t string
--- @param val string
--- @param col number
--- @param ln number
--- @return Token
local function newToken(t, val, col, ln)
    return setmetatable({t=t,val=val}, {
        __tostring=function(self)
            return string.format("%s('%s') at ln %d, col %d", t, val, ln, col)
        end,
    })
end

local defPrec = {
    none=0,
    assignment=1,
    _or=2,
    _and=3,
    equality=4,
    comparison=5,
    object=6,
    term=7,
    factor=8,
    unary=9,
    power=10,
    call=11,
    primary=12,
}

--- @class ParseRules
--- @field stmts table<string, function>
--- @field exprs table<string, ExprRule>
--- @field tokens table<string, TokenEntry[]>
--- @field parser Parser?
--- @field precedence table<string,number>
local ParseRules = {}
ParseRules.__index = ParseRules

--- @alias RuleToken string|{type:string?,value:string?}

--- @return ParseRules
--- Create new ParseRules, which is where you can define your language grammar. Parsing is done with the Pratt Parsing method.
function ParseRules.new()
    return setmetatable({
        stmts={},
        exprs={
            ["EndOfFile"]={prefix=nil,infix=nil,prec=-1},
        },
        tokens={
            ["="]={{
                t="Equals",
                val="=",
            }},
        },
        parser=nil,
        precedence=defPrec,
    }, ParseRules)
end

--- @param char string
--- @param type string
--- Establishes a new token.\
--- Note that literal tokens are pre-established, denoted with the types `Id`, `Number`, and `String`, as well as
--- the `Equals` token ('=') for sake of assignment expressions.\
--- To encourage more user-friendly grammars, a maximum of two characters per token has been established. 
--- Going over this will trigger *undefined behavior*.
function ParseRules:newToken(char, type)
    if not self.exprs[type] then
        self.exprs[type]={prefix=nil,infix=nil,prec=-1}
    end

    local len = char:len()
    if not self.tokens[char:sub(1,1)] then
        self.tokens[char:sub(1,1)] = {}
    end

    if len==1 then
        table.insert(self.tokens[char], {t=type, val=char})
        return
    elseif len==2 then
        table.insert(self.tokens[char:sub(1,1)], {match=char:sub(1,1),val={match=char:sub(2,2),val={t=type,val=char}}})
        return
    end
    --- @type TokenEntry
    local buf = {match=char:sub(2,2)}
    for i=3,char:len() do
        if i==len then
            buf.val = {t=type, val=char}
            goto loopEnd
        end
        buf.val = {match=char:sub(i,i)}
    end
    ::loopEnd::
    table.insert(self.tokens[char], buf)
end

--- Establish a new statement that starts with the given keyword or literal buffer of the token.
function ParseRules:stmt(keyword, handler)
    self.stmts[keyword]=handler
end

--- @param prec number
--- @param type string
--- @param fns {prefix:function?,infix:function?}
--- Establish a new expression with the given precedence (ParseRule's builtin .precedence field is recommended),
--- starting token type, as well as functions. An example would be the + operator having no prefix, an infix of a binary handler,
--- and a precedence of precedence.term.
function ParseRules:expr(prec, type, fns)
    self.exprs[type] = {prefix=fns.prefix, infix=fns.infix, prec=prec}
end

--- @class Parser
--- @field src string[]
--- @field prev Token
--- @field curr Token
--- @field rules ParseRules
--- @field currChar string
--- @field currIdx number
--- @field currLn number
--- @field output AstNode[]
local Parser = {}
Parser.__index = Parser

--- @param src string
--- @param rules ParseRules
--- @return Parser
--- Make a new Parser with the given source code and ParseRules.
function Parser.new(src,rules)
    local buf = {}
    for i=1,src:len() do
        table.insert(buf, src:sub(i,i))
    end
    local self = setmetatable({
        src=buf,
        currChar=buf[1],
        currIdx=1,
        rules=rules,
        currLn=1,
        curr=nil,
        output={},
    }, Parser)
    self:whitespace()
    rules.parser=self

    return self
end

--- @param msg string
--- Throw a new parsing exception formatted properly.
function Parser:error(msg)
    error(string.format(
        "\nparser EXCEPTION at ln %d, col %d:\n\t%s",
        self.currLn, self.currIdx, msg
    ), 0)
end

--- Advance past whitespaces if any.
function Parser:whitespace()
    while self.currChar==" "  or self.currChar=="\t" or
          self.currChar=="\r" or self.currChar=="\n" or self.currChar == "#"
    do
        if self.currChar == "#" then
            while self.currChar ~= "\n" and self.currChar ~= "\0" do
                self:singlyAdvance()
            end
            self.currLn = self.currLn + 1
            goto continue
        end
        if self.currChar=="\n" then
            self.currLn = self.currLn+1
        end
        self:singlyAdvance()
        ::continue::
    end
end

--- Advance by a single character with whitespaces. See `adv` to advance with a full token.
function Parser:advChar()
    if self.currChar=="\0" then
        return
    end
    self:whitespace()
    self.currIdx = self.currIdx+1
    self.currChar = self.src[self.currIdx] or "\0"
end

--- Advance by only one character, with no whitespace parsing.
function Parser:singlyAdvance()
    if self.currChar=="\0" then
        return
    end
    self.currIdx = self.currIdx+1
    self.currChar = self.src[self.currIdx] or "\0"
end

--- @param ch string
--- @return boolean
local function isAlpha(ch)
    local c = string.byte(ch)
    return (c>64 and c<91) or (c>96 and c<123) or c==95
end

local function isDigit(ch)
    local c = string.byte(ch)
    return c>47 and c<58
end

--- @return Token
--- Advance by a set amount of characters depending on the current character, and returns a Token. Throws if character is invalid.
function Parser:adv()
    self.prev = self.curr
    self:whitespace()
    local start, startCol, startLn = self.currChar, self.currIdx, self.currLn

    if start=="\0" or start==nil then
        local out = newToken("EndOfFile", "\0", self.currIdx, self.currLn)
        self.curr = out
        return out
    end

    if isAlpha(start) then
        local buf = start
        self:advChar()

        while isAlpha(self.currChar) do
            buf = buf..self.currChar
            self:advChar()
        end

        local out = newToken("Id", buf, startCol, startLn)
        self.curr = out
        return out
    end

    if isDigit(start) then
        local buf = start
        self:advChar()

        while isDigit(self.currChar) do
            buf = buf..self.currChar
            self:advChar()
        end

        if self.currChar=="." then
            buf = buf.."."
            self:advChar()

            while isDigit(self.currChar) do
                buf = buf..self.currChar
                self:advChar()
            end
        end

        local out = newToken("Number", buf, startCol, startLn)
        self.curr = out
        return out
    end

    if start=='"' then
        local buf = ""
        self:singlyAdvance()

        while self.currChar~='"' and self.currChar~='\0' do
            buf = buf..self.currChar
            self:singlyAdvance()
        end

        if self.currChar~='"' then
            self:error("encountered unterminated string")
        end

        self:singlyAdvance()
        local out = newToken("String", buf, startCol, startLn)
        self.curr = out
        return out
    end

    local rules = self.rules.tokens[start]

    --? multicharacter tokens are discribed as {match:char1, val:{match:char2, val:{t=tokentype, val=char1..char2}}}
    --? this allows for recursive lookups when reaching these 

    --- @param match string
    --- @return Token?
    local function recurseRule(match,val)
        if self.currChar~=match then
            return nil
        end
        self:advChar()
        if val.t then
            return newToken(val.t, val.val, startCol, startLn)
        end
        return recurseRule(val.match,val.val)
    end

    if rules then
        --? ensure that the longest matched rule is parsed over the lesser rules

        --- @type Token?
        local eval = nil
        --- @type number?
        local evalLen = nil
        local newEval, newEvalLen = nil,nil

        for _, rule in ipairs(rules) do
            self.currIdx = startCol
            self.currLn = startLn
            self.currChar = start
            if rule.t then
                ---@diagnostic disable-next-line: param-type-mismatch
                newEval = newToken(rule.t, rule.val, startCol, startLn)
                goto continue
            end

            newEval = recurseRule(rule.match,rule.val)
            ::continue::
            if newEval then
                newEvalLen = newEval.val:len()
                if evalLen==nil or newEvalLen>evalLen then
                    evalLen = newEvalLen
                    eval = newEval
                end
            end
        end

        if eval then
            self.currIdx = startCol+eval.val:len()
            self.currChar = self.src[self.currIdx]
            self.curr = eval
            return eval
        end
    end

    self:error(string.format("unknown character '%s'", start))
    error()
end

--- @param type string
--- @return boolean
--- Returns true and advances if the current token is the given type.
function Parser:match(type)
    if self.curr.t~=type then
        return false
    end
    self:adv()
    return true
end

--- @param type string
--- Errors if the current token is not of the given type and advances.
function Parser:consume(type)
    if self.curr.t~=type then
        self:error(string.format("expected token of type %s, received %s", type, self.curr))
    end
    self:adv()
end

--- @param prec number?
function Parser:expr(prec)
    prec = prec or 1
    self:adv()
    local pfx = self.rules.exprs[self.prev.t].prefix
    if not pfx then
        self:error(string.format("expected expression, got %s", self.prev.t))
        error()
    end

    local canAssign = prec<=1
    pfx(self, {
        canAssign=canAssign,
    })

    while prec<=self.rules.exprs[self.curr.t].prec do
        self:adv()
        self.rules.exprs[self.prev.t].infix(self, {
            canAssign=canAssign,
        })
    end

    if canAssign and self:match("Equals") then
        self:error("invalid assignment target")
    end
end

function Parser:stmt()
    local case = self.rules.stmts[self.curr.val]
    if case then
        self:adv()
        case(self)
        return
    end
    self:expr()
end

function Parser:parse()
    self:adv()
    while not self:match("EndOfFile") do
        self:stmt()
    end
end

_G.Parser,_G.ParseRules = Parser,ParseRules