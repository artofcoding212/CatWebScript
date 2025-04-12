require("json")

local Opcode = {
    -- events
    OnWebLoad="0",
    OnBtnPressed="1",
    OnBtnMouseEnter="3",
    OnBtnMouseLeave="5",
    OnKeypress="2",
    OnMessageReceive="4",
    OnDonationBought="7",

    -- functions
    DefineFunction="6",
    RunFunction="63",
    AwaitFunction="87",

    -- control flow
    IfEquals="18",
    IfNotEquals="19",
    IfGreater="20",
    IfLower="21",
    IfContains="37",
    IfNotContains="38",
    IfExists="92",
    IfNotExists="93",
    IfAnd="44",
    IfOr="45",
    IfNor="46",
    IfXor="47",
    Repeat="22",
    RepeatForever="23",
    Break="24",
    End="25",
    EndFn="IR1",

    -- objects
    ObjectInvisible="8",
    ObjectVisible="9",
    ObjectSetText="10",
    ObjectSet="31",
    ObjectGet="32",
    ObjectDelete="50",
    ObjectParent="58",
    ObjectTween="88",

    -- web
    WebRedirect="4",
    WebGetQueryParam="67",
    WebBroadcastPage="32",
    WebBroadcastSite="33", 
    WebGetLocalUser="51",
    WebGetLocalId="52",
    WebGetViewsize="84",

    -- audio
    AudioPlay="5",
    AudioPlayLooped="26",
    AudioSetVolume="27",
    AudioSetSpeed="77",
    AudioSet="94",
    AudioGet="95",
    AudioStop="74",
    AudioResume="76",
    AudioStopAll="7",

    -- console
    ConsoleLog="0",
    ConsoleWarn="1",
    ConsoleErr="2",

    -- math
    VarSet="11",
    VarIncrease="12",
    VarDecrease="13",
    VarMultiply="14",
    VarDivide="15",
    VarPower="40",
    VarModulo="41",
    VarRound="16",
    VarFloor="17",
    VarCeil="18",
    VarDelete="96",
    MathFunc="86",
    MathRand="27",

    -- time
    TimeStamp="68",
    TimeTick="83",
    TimeFormatDT="71",
    TimeFormatUnix="72",

    -- mouse
    MouseLMBDown="79",
    MouseMBDown="80",
    MouseRMBDown="81",
    MouseKeydown="82",
    MouseCursorPos="85",

    -- cookie
    CookieSet="34",
    CookeIncrease="35",
    CookieGet="36",
    CookieDelete="62",

    -- string
    StringSub="42",
    StringReplace="43",
    StringLen="48",
    StringSplit="57",
    StringLower="69",
    StringUpper="70",

    -- table
    TableCreate="54",
    TableSet="55",
    TableSetObject="56",
    TableGet="56",
    TableDeleteEntry="90",
    TableInsert="89",
    TableRemoveEntry="91",
    TableLength="59",
    TableIterate="61",
}
_G.Opcode = Opcode

--- @alias IrNodeType "opcode"|"object"|"any"|"number"|"string"
--- @alias IrNode {t:IrNodeType, val:string}

local generateStart = 10

--- @class Ir
--- @field ast AstNode[]
--- @field out IrNode[]
--- @field variableLu table<string, {alternate: string, t:string}>
--- @field lastGen number
local Ir = {}
Ir.__index = Ir

--- @param ast AstNode[]
--- @return Ir
--- Create a new IR class.
function Ir.new(ast)
    return setmetatable({
        ast=ast,
        out={},
        variableLu={},
        lastGen=generateStart,
    }, Ir)
end

--- @param ...IrNode
--- Output the given IR.
function Ir:output(...)
    for k=1,select("#",...) do
        local v = select(k,...)
        table.insert(self.out, v)
    end
end

--- @param msg string
--- Throw a new IR exception formatted properly.
function Ir:error(msg)
    error(string.format(
        "\ncompiler EXCEPTION:\n\t%s",
        msg
    ), 0)
end

local typeConvert = {
    ["Any"]="any",
    ["Number"]="number",
    ["Num"]="number",
    ["String"]="string",
    ["Str"]="string",
    ["Table"]="any",
    ["Function"]="any",
}

--- @param id string
--- @param t string
--- Define the variable "id" with the type "t". Coerces "id" into a tagging-avoidable string.
function Ir:makeId(id,t)
    self.lastGen = self.lastGen+1
    ---@diagnostic disable-next-line: deprecated
    --self.variableLu[id] = {alternate=string.char(unpack(self.lastGen)),t=t}
    self.variableLu[id] = {alternate=tostring(self.lastGen),t=t}
end

--- @param id string
--- @return string
--- Coerces the given ID into its alternative to avoid Roblox's tagging, otherwise creates a new one.
function Ir:convertId(id)
    if not self.variableLu[id] then
        self:makeId(id,"Any")
    end

    return self.variableLu[id].alternate
end

--[[

 IR-Utilized Variable Lookup
 r: Right-hand side of binary expressions
 e: Function return destination
 a: Expression destination
 y: If statement conditional destination

]]

--- @param node AstNode
--- @param dst string
--- Generate IR for the given node into the given temporary variable.
function Ir:genNode(node, dst)
    --- @type table<string, function>
    local cases = {
        --? statements
        ["Function"]=function()
            self:output({t="opcode",val=Opcode.DefineFunction},{t="string",val=node.value.name=="main" and "main" or self:convertId(node.value.name)})
            for i, arg in ipairs(node.value.args) do
                self.variableLu[arg.name] = {alternate=string.char(64+i),t=arg.t}
            end
            for _, block in ipairs(node.value.body) do
                self:genNode(block, "a")
            end
            self:output({t="opcode",val=Opcode.VarSet},{t="string",val="e"},{t="any",val="nil"})
            self:output({t="opcode",val=Opcode.EndFn})
        end,
        ["Return"]=function()
            self:genNode(node.value, dst)
            self:output({t="opcode",val=Opcode.VarSet},{t="string",val="e"},{t="string",val='{'..dst..'}'},{t="opcode",val=Opcode.Break})
        end,
        ["If"]=function()
            --- @param cond AstNode
            local function brh(cond)
                if cond.type == "Else" then
                    for _, block in ipairs(cond.value) do
                        self:genNode(block, "a")
                    end
                    return
                end

                self:genNode(cond.value.condition, "y")
                self:output({t="opcode",val=Opcode.IfEquals},{t="string",val="{y}"},{t="string",val="1"})
                for _, block in ipairs(cond.value.body) do
                    self:genNode(block, "a")
                end
                self:output({t="opcode",val=Opcode.Break},{t="opcode",val=Opcode.End})

                if cond.value.otherwise then
                    brh(cond.value.otherwise)
                end
            end
            self:output({t="opcode",val=Opcode.Repeat},{t="number",val="1"})
            brh(node)
            self:output({t="opcode",val=Opcode.End})
        end,
        --? expressions
        ["String"]=function()
            self:output({t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="string",val=node.value})
        end,
        ["Number"]=function()
            self:output({t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val=node.value})
        end,
        ["Id"]=function()
            self:output({t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="any",val='{'..self:convertId(node.value)..'}'})
        end,
        ["Binary"]=function()
            self:genNode(node.value.left, dst)
            self:genNode(node.value.right, "r")
            local binRef = {
                ["Plus"]=Opcode.VarIncrease,
                ["Minus"]=Opcode.VarDecrease,
                ["Star"]=Opcode.VarMultiply,
                ["Slash"]=Opcode.VarDivide,
            }
            self:output({t="opcode",val=binRef[node.value.op]},{t="string",val=dst},{t="string",val="{r}"})
        end,
        ["Comparison"]=function()
            self:genNode(node.value.left, "l")
            self:genNode(node.value.right, "r")
            local cmpRef = {
                ["Greater"]=Opcode.IfGreater,
                ["Less"]=Opcode.IfLower,
                ["EqualsEquals"]=Opcode.IfEquals,
                ["NotEquals"]=Opcode.IfNotEquals,
                ["And"]=Opcode.IfAnd,
                ["Or"]=Opcode.IfOr,
            }
            if node.value.op == "GreaterEqs" then
                self:output(
                    {t="opcode",val=Opcode.IfGreater},{t="string",val="{l}"},{t="string",val="{r}"},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="1"},
                    {t="opcode",val=Opcode.End},
                    {t="opcode",val=Opcode.IfEquals},{t="string",val="{l}"},{t="string",val="{r}"},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="1"},
                    {t="opcode",val=Opcode.End},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="0"},
                    {t="opcode",val=Opcode.End}
                )
            elseif node.value.op == "LessEqs" then
                self:output(
                    {t="opcode",val=Opcode.IfLower},{t="string",val="{l}"},{t="string",val="{r}"},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="1"},
                    {t="opcode",val=Opcode.End},
                    {t="opcode",val=Opcode.IfEquals},{t="string",val="{l}"},{t="string",val="{r}"},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="1"},
                    {t="opcode",val=Opcode.End},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="0"},
                    {t="opcode",val=Opcode.End}
                )
            elseif node.value.op == "And" then
                self:output(
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="0"},
                    {t="opcode",val=Opcode.IfAnd},{t="string",val="l"},{t="string",val="r"},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="1"},
                    {t="opcode",val=Opcode.End}
                )
            elseif node.value.op == "Or" then
                self:output(
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="0"},
                    {t="opcode",val=Opcode.IfOr},{t="string",val="l"},{t="string",val="r"},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="1"},
                    {t="opcode",val=Opcode.End}
                )
            else
                self:output(
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="0"},
                    {t="opcode",val=cmpRef[node.value.op]},{t="string",val="{l}"},{t="string",val="{r}"},
                    {t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="number",val="1"},
                    {t="opcode",val=Opcode.End}
                )
            end
        end,
        ["Assignment"]=function()
            self:genNode(node.value.right, dst)
            self:output({t="opcode",val=Opcode.VarSet},{t="string",val=self:convertId(node.value.name)},{t="any",val='{'..dst..'}'})
        end,
        ["Call"]=function()
            --? `console` library
            if
                node.value.left.type=="Member" and node.value.left.value.left.type=="Id" and
                node.value.left.value.left.value == "console" and node.value.left.value.right.type=="Id"
            then
                if node.value.left.value.right.value == "log" then
                    if #node.value.args~=1 then
                        self:error("console.log(msg: any) takes in only one parameter")
                    end
                    self:genNode(node.value.args[1],dst)
                    self:output({t="opcode",val=Opcode.ConsoleLog},{t="any",val='{'..dst..'}'})
                    return
                elseif node.value.left.value.right.value == "warn" then
                    if #node.value.args~=1 then
                        self:error("console.warn(msg: any) takes in only one parameter")
                    end
                    self:genNode(node.value.args[1],dst)
                    self:output({t="opcode",val=Opcode.ConsoleWarn},{t="any",val='{'..dst..'}'})
                    return
                elseif node.value.left.value.right.value == "error" then
                    if #node.value.args~=1 then
                        self:error("console.error(msg: any) takes in only one parameter")
                    end
                    self:genNode(node.value.args[1],dst)
                    self:output({t="opcode",val=Opcode.ConsoleErr},{t="any",val='{'..dst..'}'})
                    return
                end
            end
            for i, arg in ipairs(node.value.args) do
                self:genNode(arg,string.char(64+i))
            end
            if node.value.left.type=="Id" then
                self:output({t="opcode",val=Opcode.AwaitFunction},{t="string",val=self:convertId(node.value.left.value)})
            else
                self:error("can only call on singly identifier functions (ex. test() is supported but hi.test() isn't)")
            end
            self:output({t="opcode",val=Opcode.VarSet},{t="string",val=dst},{t="string",val="{e}"})
        end,
    }

    local c = cases[node.type]
    if not c then
        self:error("encountered unprecedented AST node "..node.type)
    end
    c()
end

--- Generate all IR for the given AST.
function Ir:gen()
    while #self.ast>0 do
        self:genNode(table.remove(self.ast,1), "a")
    end
end

--- @return string
--- Compile the generated IR into Catweb-native JSON bytecode.
function Ir:compile()
    --- @type table
    local json = {{
        running=false,
        content={},
        alias="main",
        class="script",
    }}
    --- @type table,table
    local compilingActions,action = json[1].content,{}
    --- @type table[]
    local compilingStack = {}

    --- @type table<string, function>
    local opcLookup
    local function run()
        local opc = table.remove(self.out,1).val
        action = {
            id=opc,
            text={},
        }

        local fn = opcLookup[opc]
        if not fn then
            self:error("invalid opcode "..tostring(opc))
        end
        fn()
        table.insert(compilingActions, action)
    end
    opcLookup = {
        [Opcode.VarSet]=function()
            local dst = table.remove(self.out,1)
            local src = table.remove(self.out,1)
            table.insert(action.text, "Set variable")
            table.insert(action.text, {value=dst.val,l="variable",t=dst.t})
            table.insert(action.text, "to")
            table.insert(action.text, {value=src.val,l="any",t=src.t})
        end,
        [Opcode.Break]=function()
            action.text = {"Break"}
        end,
        [Opcode.AwaitFunction]=function()
            action.text = {"Run function", {value='<'..table.remove(self.out,1).val..'>',l="function",t="string"}, "and wait"}
        end,
        [Opcode.Repeat]=function()
            action.text = {"Repeat", {value=table.remove(self.out,1).val, t="number"}, "times"}
        end,
        [Opcode.End]=function()
            action.text = {"end"}
        end,
        [Opcode.IfEquals]=function()
            local a,b = table.remove(self.out,1),table.remove(self.out,1)
            action.text = {"If", {value=a.val,l="any",t=a.t}, "is equal to", {value=b.val,t=b.t}}
        end,
        [Opcode.IfNotEquals]=function()
            local a,b = table.remove(self.out,1),table.remove(self.out,1)
            action.text = {"If", {value=a.val,l="any",t=a.t}, "is not equal to", {value=b.val,t=b.t}}
        end,
        [Opcode.IfGreater]=function()
            local a,b = table.remove(self.out,1),table.remove(self.out,1)
            action.text = {"If", {value=a.val,l="any",t=a.t}, "is greater than", {value=b.val,t=b.t}}
        end,
        [Opcode.IfLower]=function()
            local a,b = table.remove(self.out,1),table.remove(self.out,1)
            action.text = {"If", {value=a.val,l="any",t=a.t}, "is lower than", {value=b.val,t=b.t}}
        end,
        [Opcode.IfAnd]=function()
            local a,b = table.remove(self.out,1),table.remove(self.out,1)
            action.text = {"If", {value=a.val,l="variable",t=a.t}, "AND", {value=b.val,t=b.t}}
        end,
        [Opcode.IfOr]=function()
            local a,b = table.remove(self.out,1),table.remove(self.out,1)
            action.text = {"If", {value=a.val,l="variable",t=a.t}, "OR", {value=b.val,t=b.t}}
        end,
        [Opcode.DefineFunction]=function()
            local name = table.remove(self.out,1).val
            table.insert(compilingStack,compilingActions)
            local actionTmp = {
                id=Opcode.DefineFunction,
                text={},
            }
            if name=="main" then
                actionTmp.id = Opcode.OnWebLoad
                actionTmp.text = {"When website loaded..."}
            else
                actionTmp.text = {"Define function", {value="<"..name..">",l="function",t="string"}}
            end
            actionTmp.x = "0"
            actionTmp.y = "0"
            actionTmp.width = "400"
            compilingActions = {}

            table.insert(compilingActions, { id=Opcode.Repeat, text={"Repeat", {value="1", t="number"}, "times"}})

            while self.out[1].t=="opcode" and self.out[1].val ~= Opcode.EndFn do
                run()
            end

            table.remove(self.out,1)
            table.insert(compilingActions, { id=Opcode.Break, text={"Break"} })
            table.insert(compilingActions, { id=Opcode.End, text={"end"} })

            action = actionTmp
            action.actions = compilingActions
            compilingActions = table.remove(compilingStack,#compilingStack)
        end,
        [Opcode.VarIncrease]=function()
            local dst = table.remove(self.out,1)
            local src = table.remove(self.out,1)
            action.text = {"Increase", {value=dst.val,t=dst.t,l="variable"}, "by", {l="number",t=src.t,value=src.val}}
        end,
        [Opcode.VarDecrease]=function()
            local dst = table.remove(self.out,1)
            local src = table.remove(self.out,1)
            action.text = {"Subtract", {value=dst.val,t=dst.t,l="variable"}, "by", {l="number",t=src.t,value=src.val}}
        end,
        [Opcode.VarMultiply]=function()
            local dst = table.remove(self.out,1)
            local src = table.remove(self.out,1)
            action.text = {"Multiply", {value=dst.val,t=dst.t,l="variable"}, "by", {l="number",t=src.t,value=src.val}}
        end,
        [Opcode.VarDivide]=function()
            local dst = table.remove(self.out,1)
            local src = table.remove(self.out,1)
            action.text = {"Divide", {value=dst.val,t=dst.t,l="variable"}, "by", {l="number",t=src.t,value=src.val}}
        end,
        [Opcode.ConsoleLog]=function()
            local src = table.remove(self.out,1)
            action.text = {"Log", {value=src.val,t=src.t,l="any"}}
        end,
        [Opcode.ConsoleWarn]=function()
            local src = table.remove(self.out,1)
            action.text = {"Warn", {value=src.val,t=src.t,l="any"}}
        end,
        [Opcode.ConsoleErr]=function()
            local src = table.remove(self.out,1)
            action.text = {"Error", {value=src.val,t=src.t,l="any"}}
        end,
    }

    while #self.out>0 do
        run()
    end

    return JSON.stringify(json)
end

_G.Ir = Ir