# lua-wow64

Use 64-bit DLLs in 32-bit LuaJIT.

The main feature is based on [BlackBone](https://github.com/DarthTon/Blackbone). `BlackBoneC` encapsulates some BlackBone APIs. Lua scripts wrap `BlackBoneC` into easy-to-use classes and functions.

The source of BlackBone is modified a bit. See `BlackBoneC.cpp` for more information.

`dummy_proc` is the only 64-bit program in this project. It runs silently and exits automatically. It's the host process for 64-bit DLLs.

`header_parser` is a tool to parse C header (of DLL) into Lua script this project can use. It only supports type define, function declaration and doxygen comment.

## Requirements

* LuaJIT 2.0+
* Windows 7+ x64

## Example

```lua
local proc = require('proc')
proc.start()
print(proc.GetCurrentDirectory())
proc.SetCurrentDirectory('path/to/dll')
proc.LoadLibrary('dllname.dll')
proc.setMod('dllname.dll')
proc.addDef('func', { 'int', 'int' }, 'int')
print(proc.call('func', 1, 2))
```
