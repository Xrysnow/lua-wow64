local M = {}
local lib = require('libBlackBone')
local ffi = require('ffi')
local toWideChar = require('helper').toWideChar

--local _type = ffi.metatype(ffi.typeof('AsmVariant'), M)
M.__index = M

local function create(...)
    local ret = ffi.gc(ffi.new('AsmVariant'), function(o)
        lib.AsmVariant_dtor(o)
    end)
    lib.AsmVariant_ctor(ret)
    return ret
end

setmetatable(M, {
    __call = function(_, ...)
        return create(...)
    end
})

function M.pointer(v)
    if v == 0 then
        v = nil
    end
    local var = create()
    lib.AsmVariant_set_pointer(var, v)
    return var
end

M.nullptr = M.pointer(nil)

function M.integer(v, byteSize, isUnsigned)
    byteSize = byteSize or 8
    isUnsigned = isUnsigned or false
    local var = create()
    lib.AsmVariant_set_integer(var, v, byteSize, not isUnsigned)
    return var
end

function M.int8_t(v)
    return M.integer(v, 1)
end
function M.uint8_t(v)
    return M.integer(v, 1, true)
end
function M.int16_t(v)
    return M.integer(v, 2)
end
function M.uint16_t(v)
    return M.integer(v, 2, true)
end
function M.int32_t(v)
    return M.integer(v, 4)
end
function M.uint32_t(v)
    return M.integer(v, 4, true)
end
function M.int64_t(v)
    return M.integer(v, 8)
end
function M.uint64_t(v)
    return M.integer(v, 8, true)
end

function M.float(v)
    local var = create()
    lib.AsmVariant_set_float(var, v)
    return var
end

function M.double(v)
    local var = create()
    lib.AsmVariant_set_double(var, v)
    return var
end

function M.bool(v)
    return M.int32_t(v and 1 or 0)
end

function M.string(v)
    local var = create()
    lib.AsmVariant_set_string(var, v)
    return var
end

function M.wstring(v)
    if type(v) == 'string' then
        v = toWideChar(v)
    end
    local var = create()
    lib.AsmVariant_set_wstring(var, v)
    return var
end

function M.array(cdata_or_type, size)
    local var = create()
    if type(cdata_or_type) == 'cdata' then
        size = size or ffi.sizeof(cdata_or_type)
    elseif type(cdata_or_type) == 'string' then
        cdata_or_type = ffi.new(cdata_or_type .. '[?]', size)
        size = ffi.sizeof(cdata_or_type)
    else
        error('wrong param')
    end
    lib.AsmVariant_set_arbitrary_pointer(var, cdata_or_type, size)
    return var, cdata_or_type
end

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
    ['short']              = M.int16_t,
    ['signed short']       = M.int16_t,
    ['unsigned short']     = M.uint16_t,
    ['int']                = M.int32_t,
    ['signed int']         = M.int32_t,
    ['unsigned int']       = M.uint32_t,
    ['long']               = M.int32_t,
    ['signed long']        = M.int32_t,
    ['unsigned long']      = M.uint32_t,
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
    assert(f)
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
    elseif ty == 'string' or ty == 'wtring' then
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

return M
