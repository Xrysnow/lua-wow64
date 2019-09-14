---@class AsmVariant
---@field value any
---@field type string
---@field ctype string
---@field size number
---@field raw cdata
---@field T table
---@field remote cdata
local M = {}
local lib = require('libBlackBone')
local ffi = require('ffi')
local toWideChar = require('helper').toWideChar
local fromWideChar = require('helper').fromWideChar
local tostring = tostring
---@type fun(o):number
local sizeof = ffi.sizeof
local function proc()
    return require('proc')
end

local _type = ffi.metatype(ffi.typeof('AsmVariant'), M)
local _field = {}

---@return AsmVariant
local function create(...)
    local ret = ffi.gc(_type(), function(o)
        if not o:_getProp('detach_remote') then
            o:releaseRemote()
        end
        _field[tostring(o)] = nil
        lib.AsmVariant_dtor(o)
    end)
    lib.AsmVariant_ctor(ret)
    _field[tostring(ret)] = {}
    return ret
end

function M:_setProp(k, v)
    _field[tostring(self)][k] = v
end
function M:_getProp(k)
    return _field[tostring(self)][k]
end
function M:_setType(ty)
    self:_setProp('type', ty)
    return self
end
function M:_getType()
    return self:_getProp('type')
end
function M:_setValue(v)
    self:_setProp('value', v)
    self:_updateRemote()
    return self
end
function M:_getValue()
    return self:_getProp('value')
end
function M:_setCType(ty)
    self:_setProp('ctype', ty)
    return self
end
function M:_getCType()
    return self:_getProp('ctype')
end
function M:_getSize()
    return sizeof(self:_getValue())
end
function M:_updateRemote(force)
    local r = self:_getProp('remote')
    if not r then
        if not force then
            return
        end
        r = proc().alloc(self:_getSize())
        self:_setProp('remote', r)
    end
    proc().memWrite(self:_getValue(), r, self:_getSize())
end
function M:_getRemote()
    local r = self:_getProp('remote')
    if not r then
        self:_updateRemote(true)
        return self:_getProp('remote')
    else
        return r
    end
end
function M:releaseRemote()
    local r = self:_getProp('remote')
    if r then
        proc().free(r)
        self:_setProp('remote', nil)
    end
end
function M:detachRemote()
    local r = self:_getProp('remote')
    if r then
        self:_setProp('detach_remote', true)
    end
end

function M:__index(k)
    if k == 'type' then
        return self:_getType().name
    elseif k == 'value' then
        return self:_getType().get(self)
    elseif k == 'size' then
        return self:_getSize()
    elseif k == 'raw' then
        return self:_getValue()
    elseif k == 'ctype' then
        return self:_getCType()
    elseif k == 'T' then
        return self:_getType()
    elseif k == 'remote' then
        return self:_getRemote()
    elseif type(k) == 'number' then
        if self:_getType() == 'pointer' then
            return M.deref()
        end
    else
        return M[k]
    end
end

function M.is_var(v)
    return ffi.istype('AsmVariant', v)
end

local _signed_name = {
    [1] = 'int8_t',
    [2] = 'int16_t',
    [4] = 'int32_t',
    [8] = 'int64_t',
}
local _unsigned_name = {
    [1] = 'uint8_t',
    [2] = 'uint16_t',
    [4] = 'uint32_t',
    [8] = 'uint64_t',
}

---@return fun():AsmVariant
local function make_int(size, unsigned)
    local name
    if unsigned then
        name = _unsigned_name[size]
    else
        name = _signed_name[size]
    end
    assert(name)
    local t = { name = name }
    t.set = function(var, v)
        if type(v) == 'boolean' then
            v = v and 1 or 0
        elseif v == nil then
            v = 0
        end
        if M.is_var(v) then
            v = v.value
        end
        local v_ = ffi.new(name .. '[1]', v)
        lib.AsmVariant_set_integer(var, v_[0], size, not unsigned)
        var:_setValue(v_)
    end
    t.get = function(var)
        return var:_getValue()[0]
    end
    setmetatable(t, {
        __call  = function(_, v)
            local var = create()
            t.set(var, v)
            var:_setType(t):_setCType(name)
            return var
        end,
        __index = function(_, k)
            return M.array(name, k)
        end,
    })
    return t
end

M.int8_t = make_int(1)
M.uint8_t = make_int(1, true)
M.int16_t = make_int(2)
M.uint16_t = make_int(2, true)
M.int32_t = make_int(4)
M.uint32_t = make_int(4, true)
M.int64_t = make_int(8)
M.uint64_t = make_int(8, true)

---@type fun():AsmVariant
M.float = setmetatable(
        { name = 'float',
          set  = function(var, v)
              if M.is_var(v) then
                  v = v.value
              end
              local v_ = ffi.new('float[1]', v)
              lib.AsmVariant_set_float(var, v_[0])
              var:_setValue(v_)
          end,
          get  = function(var)
              return var:_getValue()[0]
          end
        },
        { __call  = function(_, v)
            local var = create()
            M.float.set(var, v)
            var:_setType(M.float):_setCType('float')
            return var
        end,
          __index = function(_, k)
              return M.array('float', k)
          end,
        }
)

---@type fun():AsmVariant
M.double = setmetatable(
        { name = 'double',
          set  = function(var, v)
              if M.is_var(v) then
                  v = v.value
              end
              local v_ = ffi.new('double[1]', v)
              lib.AsmVariant_set_double(var, v_[0])
              var:_setValue(v_)
          end,
          get  = function(var)
              return var:_getValue()[0]
          end
        },
        { __call  = function(_, v)
            local var = create()
            M.double.set(var, v)
            var:_setType(M.double):_setCType('double')
            return var
        end,
          __index = function(_, k)
              return M.array('double', k)
          end,
        }
)

---@type fun():AsmVariant
M.bool = setmetatable(
        { name = 'bool',
          set  = M.int32_t.set,
          get  = function(var)
              return var:_getValue()[0] ~= 0
          end
        },
        { __call  = function(_, v)
            if type(v) == 'boolean' then
                v = v and 1 or 0
            end
            local var = M.int32_t(v)
            var:_setType(M.bool):_setCType('bool')
            return var
        end,
          __index = function(_, k)
              return M.array('bool', k)
          end,
        }
)

---@type fun():AsmVariant
M.pointer = setmetatable(
        { name = 'pointer',
          set  = M.uint64_t.set,
          get  = M.uint64_t.get,
        },
        { __call  = function(_, v, ctype)
            assert(ffi.istype('uint64_t', v) or v == 0 or v == nil)
            if v == nil then
                v = 0
            end
            ctype = ctype or 'void'
            local var = M.uint64_t(v)
            var:_setType(M.pointer):_setCType(ctype .. '*')
            return var
        end,
          __index = function(_, k)
              return M.array('pointer', k)
          end,
        }
)

M.nullptr = M.pointer()

---@type fun():AsmVariant
M.string = setmetatable(
        { name = 'string',
          set  = function(var, v)
              local buf, len
              if M.is_var(v) then
                  v = v:_getValue()
              elseif type(v) == 'string' then
                  len = #v + 1
              else
                  -- cdata
              end
              len = len or ffi.sizeof(v)
              buf = ffi.new(string.format('char[%d]', len))
              ffi.copy(buf, v, len)
              var:_setValue(buf)
              lib.AsmVariant_set_string(var, buf)
          end,
          get  = function(var)
              return ffi.string(var:_getValue())
          end,
        },
        { __call  = function(_, v)
            local var = create()
            M.string.set(var, v)
            var:_setType(M.string):_setCType('char*')
            return var
        end,
          __index = function(_, k)
              return M.array('string', k)
          end,
        }
)

---@type fun():AsmVariant
M.wstring = setmetatable(
        { name = 'wstring',
          set  = function(var, v)
              local buf, len
              if M.is_var(v) then
                  v = v:_getValue()
              elseif type(v) == 'string' then
                  v = toWideChar(v)
              else
                  -- cdata
              end
              len = ffi.sizeof(v)
              buf = ffi.new(string.format('wchar_t[%d]', len))
              ffi.copy(buf, v, len)
              var:_setValue(buf)
              lib.AsmVariant_set_wstring(var, buf)
          end,
          get  = function(var)
              return ffi.string(fromWideChar(var:_getValue()))
          end,
        },
        { __call  = function(_, v)
            local var = create()
            M.wstring.set(var, v)
            var:_setType(M.wstring):_setCType('wchar_t*')
            return var
        end,
          __index = function(_, k)
              return M.array('wstring', k)
          end,
        }
)

---@type fun(cdata_or_ctype:any, size:number):AsmVariant
M.array = setmetatable(
        { name = 'array',
          get  = function(var)
              return var:_getValue()
          end,
        },
        { __call = function(_, ctype, size)
            local var = create()
            local cdata
            if type(ctype) == 'string' then
                cdata = ffi.new(string.format('%s[%d]', ctype, size))
            else
                error('wrong param')
            end
            size = ffi.sizeof(ctype)
            lib.AsmVariant_set_arbitrary_pointer(var, cdata, size)
            var:_setType(M.array):_setValue(cdata):_setCType(ctype .. '*')
            return var
        end,
        }
)

function M.buffer(size)
    return M.array('char', size)
end

function M.ref(v)
    return M.pointer(require('proc').refRemotePointer(v))
end

function M.deref(v)
    return M.pointer(require('proc').derefRemotePointer(v))
end

function M.index_pptr(v, i)
    return M.pointer(require('proc').indexRemotePointer(v, i, 'uint64_t'))
end

--

local _alias = {
    ['*']                  = M.pointer,
    ['p']                  = M.pointer,
    ['b']                  = M.bool,
    ['f']                  = M.float,
    ['d']                  = M.double,
    ['s']                  = M.string,
    ['const char*']        = M.string,
    ['const char *']       = M.string,
    ['w']                  = M.wstring,
    ['const wchar_t*']     = M.wstring,
    ['const wchar_t *']    = M.wstring,
    ['i8']                 = M.int8_t,
    ['u8']                 = M.uint8_t,
    ['i16']                = M.int16_t,
    ['u16']                = M.uint16_t,
    ['i32']                = M.int32_t,
    ['u32']                = M.uint32_t,
    ['i64']                = M.int64_t,
    ['u64']                = M.uint64_t,

    ['char']               = M.int8_t,
    ['signed char']        = M.int8_t,
    ['unsigned char']      = M.uint8_t,
    --
    ['short']              = M.int16_t,
    ['signed short']       = M.int16_t,
    ['unsigned short']     = M.uint16_t,
    ['wchar_t']            = M.int16_t,
    --
    ['int']                = M.int32_t,
    ['signed int']         = M.int32_t,
    ['unsigned int']       = M.uint32_t,
    ['long']               = M.int32_t,
    ['signed long']        = M.int32_t,
    ['unsigned long']      = M.uint32_t,
    ['long int']           = M.int32_t,
    ['signed long int']    = M.int32_t,
    ['unsigned long int']  = M.uint32_t,
    --
    ['long long']          = M.int64_t,
    ['signed long long']   = M.int64_t,
    ['unsigned long long'] = M.uint64_t,

    ['ssize_t']            = M.int64_t,
    ['size_t']             = M.uint64_t,

    ['enum']               = M.int32_t,
}

function M.typedef(newName, name)
    local f = M[name] or _alias[name]
    if not f then
        local last = name:sub(-1, -1)
        if last == '*' or last == '&' then
            f = M.pointer
        end
    end
    assert(f, name)
    _alias[newName] = f
end

function M.enumdef(name)
    _alias[name] = M.int64_t
end

function M.type_ctor(ty)
    assert(type(ty) == 'string')
    local f = M[ty] or _alias[ty]
    if not f then
        local last = ty:sub(-1, -1)
        if last == '*' or last == '&' then
            f = M.pointer
        end
    end
    if not f then
        if ty:sub(1, 6) == 'const ' then
            return M.type_ctor(ty:sub(7, -1))
        end
    end
    return f
end

function M.type_ctors(types)
    local ret = {}
    for i, v in ipairs(types) do
        ret[i] = assert(M.type_ctor(v))
    end
    return ret
end

function M.raw_type(ty)
    local f = M.type_ctor(ty)
    if not f then
        return
    end
    for k, v in pairs(M) do
        if v == f then
            return k
        end
    end
    if ty:sub(1, 6) == 'const ' then
        return M.raw_type(ty:sub(7, -1))
    end
end

local _numeric = {
    int8_t   = true,
    uint8_t  = true,
    int16_t  = true,
    uint16_t = true,
    int32_t  = true,
    uint32_t = true,
    int64_t  = true,
    uint64_t = true,
    float    = true,
    double   = true,
}

function M.lua_type(ty)
    if ty == 'void' then
        return nil
    end
    local _ty = ty
    ty = M.raw_type(ty)
    assert(ty, _ty)
    if _numeric[ty] then
        return 'number'
    end
    if ty == 'pointer' then
        return 'number'
    elseif ty == 'bool' then
        return 'boolean'
    elseif ty == 'string' or ty == 'wstring' then
        return 'string'
    end
    return ty
end

function M.pack(types, values)
    assert(#types == #values)
    local argc = #types
    if argc == 0 then
        return {}, nil, 0
    end
    local args = {}
    for i = 1, argc do
        local ty = types[i]
        local val = values[i]
        assert(type(ty) == 'string')
        local f = M.type_ctor(ty)
        if ffi.istype('AsmVariant', val) then
            args[i] = val
        else
            assert(f)
            args[i] = f(val)
        end
    end
    local argv = ffi.new('AsmVariant*[?]', argc)
    for i = 1, argc do
        argv[i - 1] = args[i]
    end
    -- args shoud not die before argv
    return args, argv, argc
end

function M.pack_va(...)
    local arg = { ... }
    local n = select('#', ...)
    assert(n % 2 == 0)
    local argc = n / 2
    if argc == 0 then
        return {}, nil, 0
    end
    local args = {}
    for i = 1, argc do
        local ty = arg[i * 2 - 1]
        local val = arg[i * 2]
        assert(type(ty) == 'string')
        local f = M.type_ctor(ty)
        if ffi.istype('AsmVariant', val) then
            args[i] = val
        else
            assert(f)
            args[i] = f(val)
        end
    end
    local argv = ffi.new('AsmVariant*[?]', argc)
    for i = 1, argc do
        argv[i - 1] = args[i]
    end
    -- args shoud not die before argv
    return args, argv, argc
end

--

function M.getStringArray(char_p_p, num)
    assert(M.is_var(char_p_p) and num > 0)
    local f = require('proc').getRemoteString
    local p = char_p_p.value
    local buf = ffi.new('uint64_t[?][1]', num)
    for i = 1, num do
        require('proc').indexRemotePointer(p, i - 1, buf[i - 1])
    end
    local ret = {}
    for i = 1, num do
        table.insert(ret, f(buf[i - 1][0]))
    end
    return ret
end

--
---@class cdata

return M
