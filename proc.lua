--
local M = {}
local ffi = require('ffi')
local var = require('AsmVariant')
local lib = require('libBlackBone')
local helper = require('helper')
local L = helper.toWideChar

local _def = {}
local _proc
local _mod
local ReturnType = {
    rt_int32  = 4, -- 32bit value
    rt_int64  = 8, -- 64bit value
    rt_float  = 1, -- float value
    rt_double = 2, -- double value
    rt_struct = 3, -- structure returned by value
}
local _exit_task = {}

local function check(ok)
    if ok < 0 then
        error(string.format('error: %d', ok))
    end
end

function M.start(path)
    path = path or 'dummy_proc.exe'
    if not _proc then
        _proc = ffi.gc(ffi.new('Process[1]'), function(o)
            for _, task in ipairs(_exit_task) do
                task()
            end
            lib.Process_Terminate(o, 0)
            lib.Process_dtor(o)
        end)
        lib.Process_ctor(_proc)
        path = helper.toWideChar(path)
        local status = lib.Process_CreateAndAttach(
                _proc, path, true, true, helper.toWideChar(''), nil, nil)
        assert(status >= 0)
        lib.Process_Resume(_proc)
        helper.sleep(100)
        M.LoadLibrary('msvcrt.dll')
    end
end

function M.atexit(f)
    table.insert(_exit_task, f)
end

function M.setMod(v)
    _mod = require('helper').toWideChar(v)
end

function M.addDef(name, argTypes, retType)
    _def[name] = { argTypes, retType }
end

function M.call(name, ...)
    assert(_proc and _mod)
    local def = _def[name]
    assert(def)
    local retType = def[2]
    local retVal, rawType
    local retT = ReturnType.rt_int32
    if retType == 'void' then
        retVal = ffi.new('int32_t[1]')
    else
        rawType = var.raw_type(retType)
        if rawType == 'pointer' then
            retVal = ffi.new('uint64_t[1]')
        elseif rawType == 'bool' then
            retVal = ffi.new('int32_t[1]')
        elseif rawType == 'string' then
            retVal = ffi.new('uint64_t[1]')
        elseif rawType == 'wstring' then
            retVal = ffi.new('uint64_t[1]')
        else
            retVal = ffi.new(string.format('%s[1]', rawType))
        end
    end
    local retSize = ffi.sizeof(retVal)
    assert(retSize <= 8)
    if rawType == 'float' then
        retT = ReturnType.rt_float
    elseif rawType == 'double' then
        retT = ReturnType.rt_double
    elseif retSize == 8 then
        retT = ReturnType.rt_int64
    end
    local values = { ... }
    local args, argv, argc = var.pack(def[1], values)
    local ok = lib.RemoteCall(
            _proc, _mod, name, 1, argv, argc,
            retVal, retSize, retT, false)
    check(ok)
    return retVal[0]
end

function M.caller(modName)
    return function(fName, ...)
        M.setMod(modName)
        return M.call(fName, ...)
    end
end

local function cstd()
    return require('cstd')
end

local function pointer_value(p)
    if ffi.istype('AsmVariant', p) then
        p = p.value
    end
    assert(ffi.istype('uint64_t', p))
    return p
end

function M.alloc(size)
    assert(size > 0, 'wrong param')
    local p = lib.Process_MemoryAllocate(_proc, size)
    assert(p ~= 0, 'failed to alloc')
    return p
end

function M.free(p)
    p = pointer_value(p)
    assert(ffi.istype('uint64_t', p))
    if p == 0 then
        return
    end
    assert(lib.Process_MemoryFree(_proc, p))
end

function M.memRead(src, dst, size)
    assert(size > 0, 'wrong param')
    src = pointer_value(src)
    if dst == nil then
        dst = ffi.new(string.format('char[%d]', size))
    elseif ffi.istype('AsmVariant', dst) then
        dst = dst.value
    end
    assert(lib.Process_MemoryRead(_proc, src, dst, size))
    return dst
end

function M.memWrite(src, dst, size)
    assert(size > 0, 'wrong param')
    if ffi.istype('AsmVariant', src) then
        src = src.value
    end
    dst = pointer_value(dst)
    assert(lib.Process_MemoryWrite(_proc, src, dst, size))
end

function M.getRemoteString(src)
    src = pointer_value(src)
    assert(src ~= 0)
    local len = cstd().strlen(src) + 1
    local dst = ffi.new('char[?]', len)
    M.memRead(dst, src, len)
    return ffi.string(dst)
end

function M.derefRemotePointer(src)
    src = pointer_value(src)
    assert(src ~= 0)
    local dst = ffi.new('uint64_t[1]')
    M.memRead(src, dst, 8)
    return dst[0]
end

function M.refRemotePointer(src)
    src = pointer_value(src)
    local p = M.alloc(8)
    local buf = ffi.new('uint64_t[1]')
    buf[0] = src
    M.memWrite(buf, p, 8)
    return p
end

function M.indexRemotePointer(src, index, dst, itemSize)
    index = ffi.new('uint64_t', index)
    src = pointer_value(src)
    if not dst then
        dst = ffi.new(string.format('char[%d]', itemSize))
    elseif type(dst) == 'string' then
        dst = ffi.new(dst .. '[1]')
        itemSize = itemSize or ffi.sizeof(dst)
    else
        assert(type(dst) == 'cdata')
        itemSize = itemSize or ffi.sizeof(dst)
    end
    M.memRead(src + index * itemSize, dst, itemSize)
    return dst
end

--

function M.LoadLibrary(path)
    local args, argv, argc = var.pack_va('const wchar_t*', path)
    local ret = ffi.new('uint64_t[1]')
    local mod = L 'kernel32.dll'
    local ok = lib.RemoteCall(
            _proc, mod, 'LoadLibraryW', 1, argv, argc,
            ret, 8, ReturnType.rt_int64, false)
    check(ok)
    return ret[0]
end

function M.GetLastError()
    local ret = ffi.new('uint32_t[1]')
    local mod = L 'kernel32.dll'
    local ok = lib.RemoteCall(
            _proc, mod, 'GetLastError', 1, nil, 0,
            ret, 4, ReturnType.rt_int32, false)
    check(ok)
    return ret[0]
end

function M.SetCurrentDirectory(path)
    local ret = ffi.new('uint32_t[1]')
    local mod = L 'kernel32.dll'
    local args, argv, argc = var.pack_va('const wchar_t*', path)
    local ok = lib.RemoteCall(
            _proc, mod, 'SetCurrentDirectoryW', 1, argv, argc,
            ret, 4, ReturnType.rt_int32, false)
    check(ok)
    return ret[0]
end

function M.GetCurrentDirectory()
    local ret = ffi.new('uint32_t[1]')
    local buf = var.array('wchar_t', 260)
    local mod = L 'kernel32.dll'
    local args, argv, argc = var.pack_va('int32_t', 260, 'wchar_t*', buf)
    local ok = lib.RemoteCall(
            _proc, mod, 'GetCurrentDirectoryW', 1, argv, argc,
            ret, 4, ReturnType.rt_int32, false)
    check(ok)
    if ret[0] == 0 then
        print('error in GetCurrentDirectory:', M.GetLastError())
        return
    end
    return helper.fromWideChar(buf.value)
end

return M
