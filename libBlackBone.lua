local ffi = require('ffi')
local helper = require('helper')

ffi.cdef(require('helper').loadFileString('BlackBone/BlackBoneC.h'))

local last_path = helper.getCurrentDirectory()
helper.setCurrentDirectory(last_path .. '\\BlackBone')
local lib = ffi.load('BlackBoneC.dll')
helper.setCurrentDirectory(last_path)

return lib
