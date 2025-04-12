--- @class JSONLib
local JSON = {}

--- @param t any
--- @return string
--- Stringifies the given value `t` following JSON syntax rules.
function JSON.stringify(t)
    local buf = ""

    if type(t)=="table" then
        if t[1] and #t>0 then --? array
            buf = buf.."["
            local len = #t
            for i,v in ipairs(t) do
                buf = buf..JSON.stringify(v)
                if i<len then
                    buf = buf..","
                end
            end
            buf = buf.."]"
        else --? dictionary
            buf = buf.."{"
            local i = 0
            for k,v in pairs(t) do
                i = i+1
                buf = buf..string.format('%s: %s,', JSON.stringify(k), JSON.stringify(v))
            end
            buf = (i>0 and buf:sub(1,buf:len()-1) or buf).."}" --? remove trailing comma if any
        end
    elseif type(t)=="boolean" then --? bool
        buf = buf..string.format('"%s"', t and "true" or "false")
    elseif t==nil then --? null
        buf = buf.."null"
    else --? other
        buf = buf..string.format('"%s"', tostring(t))
    end

    return buf
end

_G.JSON = JSON