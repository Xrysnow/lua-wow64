--
local M = {}
local lex = require('lexers.ansi_c')
local helper = require('helper')
local var = require('AsmVariant')

local function removeComment(t)
    local ret = {}
    for i, v in ipairs(t) do
        if v[1] ~= 'comment' then
            table.insert(ret, v)
        end
    end
    ret.comment = t.comment
    return ret
end

function M.parse(code)
    local tokens = lex:lex(code)
    local segments = {}
    local seg_no_space = {}
    local n = #tokens / 2
    local cur = 1
    for i = 1, n do
        local type = tokens[(i - 1) * 2 + 1]
        local idx = tokens[i * 2]
        local s = code:sub(cur, idx - 1)
        -- shared in 2 tables
        local seg = { type, s }
        table.insert(segments, seg)
        if type ~= 'whitespace' then
            table.insert(seg_no_space, seg)
        end
        cur = idx
    end
    local semicolon_split = {}
    cur = 1
    local brace = 0
    for i = 1, #seg_no_space do
        local si = seg_no_space[i]
        if si[1] == 'operator' and si[2] == ';' and brace == 0 then
            local t = {}
            for j = cur, i - 1 do
                local tj, tj1 = seg_no_space[j][1], seg_no_space[j + 1][1]
                if tj ~= 'comment' or tj1 ~= 'comment' then
                    if tj == 'comment' then
                        if seg_no_space[j][2]:sub(1, 2) == '/*' then
                            t.comment = seg_no_space[j][2]
                        end
                    else
                        table.insert(t, seg_no_space[j])
                    end
                end
            end
            cur = i + 1
            table.insert(semicolon_split, t)
        elseif si[1] == 'operator' and si[2] == '{' then
            brace = brace + 1
        elseif si[1] == 'operator' and si[2] == '}' then
            brace = brace - 1
            assert(brace >= 0)
        end
    end
    local ret = {}
    for i = 1, #semicolon_split do
        local si = semicolon_split[i]
        if si[1][1] == 'keyword' and si[1][2] == 'typedef' then
            -- typedef
            if si[#si][2] == ')' then
                -- func pointer
                local ty = 'void*'
                local identifier
                for _, v in ipairs(si) do
                    if v[1] == 'identifier' then
                        -- use first identifier
                        identifier = v[2]
                        break
                    end
                end
                assert(identifier)
                table.insert(ret, { 'typedef', ty, identifier, doc = si.comment })
            else
                assert(si[#si][1] == 'identifier')
                local identifier = si[#si][2]
                local ty = {}
                for j = 2, #si - 1 do
                    table.insert(ty, si[j][2])
                end
                ty = table.concat(ty, ' ')
                assert(ty ~= '')
                table.insert(ret, { 'typedef', ty, identifier, doc = si.comment })
            end
        elseif si[1][1] == 'type' and si[1][2] == 'struct' then
            -- struct
            -- not supported
            --assert(si[#si][2] == '}')
            --assert(si[2][1] == 'identifier')
            --local identifier = si[2][2]
            --local body = {}
        elseif si[1][1] == 'type' and si[1][2] == 'enum' then
            -- enum
            assert(si[#si][2] == '}')
            assert(si[2][1] == 'identifier')
            local identifier = si[2][2]
            table.insert(ret, { 'enum', identifier, doc = si.comment })
        elseif si[#si][2] == ')' then
            -- func
            local retType = {}
            local identifier
            local args = {}
            si = removeComment(si)
            local start
            for j = 1, #si do
                if si[j][1] == 'identifier' and si[j + 1][2] == '(' then
                    identifier = si[j][2]
                    for k = 1, j - 1 do
                        table.insert(retType, si[k][2])
                    end
                    start = j + 2
                    break
                end
            end
            assert(identifier)
            retType = table.concat(retType, ' ')
            assert(retType ~= '')
            if si[start][2] == 'void' and si[start + 1][2] == ')' then
                start = #si + 1
            end
            if si[start][2] == ')' then
                start = #si + 1
            end
            local curr = start
            for j = start, #si do
                if si[j][2] == ',' or j == #si then
                    assert(si[j - 1][1] == 'identifier', stringify(si))
                    local arg_id = si[j - 1][2]
                    local arg_t = {}
                    for k = curr, j - 2 do
                        table.insert(arg_t, si[k][2])
                    end
                    curr = j + 1
                    arg_t = table.concat(arg_t, ' ')
                    assert(arg_t ~= '')
                    table.insert(args, { arg_t, arg_id })
                end
            end
            table.insert(ret, { 'func', identifier, args, retType, doc = si.comment })
        else
            error('not supported')
        end
    end
    return ret
end

function M.convertComment(str, arg, ret)
    if str == '' then
        return ''
    end
    local function findType(name)
        if arg then
            for _, v in ipairs(arg) do
                if v[2] == name then
                    return var.lua_type(v[1]), v[1]
                end
            end
        end
    end
    local lines = helper.stringSplit(str, '\n')
    for i = 1, #lines do
        local line = lines[i]
        line = helper.stringTrim(line)
        if i == 1 then
            if line:sub(1, 4) == '/*! ' then
                line = line:sub(5, -1)
            elseif line:sub(1, 3) == '/*!' then
                line = line:sub(4, -1)
            elseif line:sub(1, 2) == '/*' then
                line = line:sub(3, -1)
            end
        end
        if i == #lines then
            if line:sub(-3, -1) == ' */' then
                line = line:sub(1, -4)
            elseif line:sub(-2, -1) == '*/' then
                line = line:sub(1, -3)
            end
        end
        line = helper.stringTrim(line)
        --if line:sub(1, 3) == ' * ' then
        --    line = line:sub(4, -1)
        --elseif line:sub(1, 2) == '* ' then
        --    line = line:sub(3, -1)
        --elseif line == ' *' then
        --    line = ''
        --end
        if line:sub(1, 2) == '* ' then
            line = line:sub(3, -1)
        elseif line:sub(1, 1) == '*' then
            line = line:sub(2, -1)
        end
        if line:sub(1, 1) == '\\' then
            if line:sub(2, 7) == 'param ' then
                local split = helper.stringSplit(line, ' ')
                local pname = split[2]
                local ptype, real_type = findType(pname)
                if ptype then
                    table.insert(split, 3, ptype)
                    table.insert(split, 4, '@(' .. real_type .. ')')
                    line = table.concat(split, ' ')
                end
            elseif line:sub(2, 8) == 'return ' and ret then
                local split = helper.stringSplit(line, ' ')
                local ptype = var.lua_type(ret)
                if ptype then
                    table.insert(split, 2, ptype)
                    table.insert(split, 3, '@(' .. ret .. ')')
                    line = table.concat(split, ' ')
                end
            end
            line = '---@' .. line:sub(2, -1)
        else
            line = '--- ' .. line
        end
        lines[i] = line
    end
    return table.concat(lines, '\n')
end

function M.generate(parsed)
    local s = ''
    local function line(str)
        str = str or ''
        s = s .. str .. '\n'
    end
    local function append(str)
        s = s .. str
    end
    line('--')
    line('local M = {}')
    line([[local _TYPEDEF = require('AsmVariant').typedef]])
    line([[local _ENUMDEF = require('AsmVariant').enumdef]])
    line([[local _CALL = require('proc').call]])
    line([[local _FUNCDEF = require('proc').addDef]])
    for i = 1, #parsed do
        line()
        line('--')
        line()
        local p = parsed[i]
        if p[1] == 'typedef' then
            if p.doc then
                local doc = M.convertComment(p.doc)
                append(doc)
                append('\n')
            end
            line(string.format('_TYPEDEF(%q, %q)', p[3], p[2]))
            var.typedef(p[3], p[2])
        elseif p[1] == 'enum' then
            if p.doc then
                local doc = M.convertComment(p.doc)
                append(doc)
                append('\n')
            end
            line(string.format('_ENUMDEF(%q)', p[2]))
            var.enumdef(p[2])
        elseif p[1] == 'func' then
            local name = p[2]
            local types, args = {}, {}
            local types_ = {}
            for _, v in ipairs(p[3]) do
                table.insert(types, v[1])
                table.insert(types_, string.format('%q', v[1]))
                table.insert(args, v[2])
            end
            local types_str = table.concat(types_, ', ')
            --
            if p.doc then
                local doc = M.convertComment(p.doc, p[3], p[4])
                append(doc)
                append('\n')
            end
            --
            local arg_str = table.concat(args, ', ')
            line(string.format([[function M.%s(%s)]], name, arg_str))
            if arg_str == '' then
                line(string.format([[    return _CALL(%q)]], name))
            else
                line(string.format([[    return _CALL(%q, %s)]], name, arg_str))
            end
            line('end')
            line(string.format([[_FUNCDEF(%q, { %s }, %q)]], name, types_str, p[4]))
        else
            error('not supported')
        end
    end
    line()
    line('--')
    line()
    line('return M')
    line()
    return s
end

return M
