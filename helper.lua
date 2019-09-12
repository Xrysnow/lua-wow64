--
local M = {}
local ffi = require('ffi')

function M.loadFileString(path)
    local f = io.open(path, 'rb')
    local s = f:read('a')
    f:close()
    return s
end

--

local kernel32 = ffi.load('kernel32.dll')
local CP_ACP = 0         -- default to ANSI code page
local CP_THREAD_ACP = 3  -- current thread's ANSI code page
local CP_UTF8 = 65001

ffi.cdef [[
int MultiByteToWideChar(
  unsigned int                   CodePage,
  unsigned long                   dwFlags,
  const char*                 lpMultiByteStr,
  int                        cbMultiByte,
  wchar_t*                   lpWideCharStr,
  int                        cchWideChar);
int WideCharToMultiByte(
  unsigned int                           CodePage,
  unsigned long                           dwFlags,
  const wchar_t*                     lpWideCharStr,
  int                                cchWideChar,
  char*                              lpMultiByteStr,
  int                                cbMultiByte,
  const char*                        lpDefaultChar,
  long*                           lpUsedDefaultChar);

int SetCurrentDirectoryW(const wchar_t* lpPathName);
int GetCurrentDirectoryW(int nBufferLength, wchar_t* lpPathName);

void Sleep(int ms);
]]

function M.toWideChar(src, bytes)
    bytes = bytes or #src
    if bytes == 0 then
        return nil
    end
    local needed = kernel32.MultiByteToWideChar(CP_UTF8, 0, src, bytes, nil, 0)
    if needed <= 0 then
        error("MultiByteToWideChar")
    end
    local buffer = ffi.new("wchar_t[?]", needed + 1)
    local count = kernel32.MultiByteToWideChar(CP_UTF8, 0, src, bytes, buffer, needed)
    buffer[count] = 0
    return buffer
end

function M.fromWideChar(src, bytes)
    bytes = bytes or ffi.sizeof(src)
    if bytes == 0 then
        return nil
    end
    local needed = kernel32.WideCharToMultiByte(CP_UTF8, 0, src, -1, nil, 0, nil, nil)
    if needed <= 0 then
        error("WideCharToMultiByte")
    end
    local buffer = ffi.new("uint8_t[?]", needed + 1)
    local count = kernel32.WideCharToMultiByte(CP_UTF8, 0, src, -1, buffer, needed, nil, nil)
    buffer[count] = 0
    return ffi.string(buffer, count - 1)
end

--

function M.sleep(ms)
    ffi.C.Sleep(ms)
end

local insert = table.insert

---@param s string
---@param sep string
function M.stringSplit(s, sep)
    local ret = {}
    if not sep or sep == '' then
        local len = #s
        for i = 1, len do
            insert(ret, s:sub(i, i))
        end
    else
        while true do
            local p = string.find(s, sep)
            if not p then
                insert(ret, s)
                break
            end
            local ss = s:sub(1, p - 1)
            insert(ret, ss)
            s = s:sub(p + 1, #s)
        end
    end
    return ret
end

function M.stringTrim(s)
    s = string.gsub(s, "^[ \t\n\r]+", "")
    return string.gsub(s, "[ \t\n\r]+$", "")
end

function M.setCurrentDirectory(path)
    path = M.toWideChar(path)
    return kernel32.SetCurrentDirectoryW(path)
end

function M.getCurrentDirectory()
    local buffer = ffi.new('wchar_t[260]')
    local ret = kernel32.GetCurrentDirectoryW(260, buffer)
    if ret == 0 then
        return nil
    end
    return M.fromWideChar(buffer)
end

return M
