#
# mp035: modified version of the registry module from the Nim standard library
#

#
#
#            Nim's Runtime Library
#        (c) Copyright 2016 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

## This module is experimental and its interface may change.

import winlean, os

type
  HKEY* = uint

const
  HKEY_LOCAL_MACHINE* = HKEY(0x80000002u)
  HKEY_CURRENT_USER* = HKEY(2147483649)

  RRF_RT_ANY = 0x0000ffff
  RRF_RT_REG_DWORD = 0x00000010
  KEY_WOW64_64KEY = 0x0100
  KEY_WOW64_32KEY = 0x0200
  KEY_READ = 0x00020019
  REG_SZ = 1

proc regOpenKeyEx(hKey: HKEY, lpSubKey: WideCString, ulOptions: int32,
                  samDesired: int32,
                  phkResult: var HKEY): int32 {.
  importc: "RegOpenKeyExW", dynlib: "Advapi32.dll", stdcall.}

proc regCloseKey(hkey: HKEY): int32 {.
  importc: "RegCloseKey", dynlib: "Advapi32.dll", stdcall.}

proc regGetValue(key: HKEY, lpSubKey, lpValue: WideCString;
                 dwFlags: int32 = RRF_RT_ANY, pdwType: ptr int32,
                 pvData: pointer,
                 pcbData: ptr int32): int32 {.
  importc: "RegGetValueW", dynlib: "Advapi32.dll", stdcall.}

proc regQueryInfoKey( hKey: HKEY,
                       lpClass : WideCstring,
                       lpcchClass : ptr int32,
                       lpReserved : ptr int32,
                       lpcSubKeys : ptr int32,
                       lpcbMaxSubKeyLen : ptr int32,
                       lpcbMaxClassLen : ptr int32,
                       lpcValues : ptr int32,
                       lpcbMaxValueNameLen : ptr int32,
                       lpcbMaxValueLen : ptr int32,
                       lpcbSecurityDescriptor : ptr int32,
                       lpftLastWriteTime : ptr FILETIME): int32 {.
  importc: "RegQueryInfoKeyW", dynlib: "Advapi32.dll", stdcall.}

proc regEnumValue( hKey: HKEY,
                    dwIndex : int32,
                    lpValueName : WideCString,
                    lpcchValueName : ptr int32,
                    lpReserved : ptr int32,
                    lpType : ptr int32,
                    lpData : pointer,
                    lpcbData : ptr int32): int32 {.
  importc: "RegEnumValueW", dynlib: "Advapi32.dll", stdcall.}

template call(f) =
  let err = f
  if err != 0:
    raiseOSError(err.OSErrorCode, astToStr(f))

iterator enumKeyValues*(path: string, handle: HKEY): tuple[key:string, value:string] =
  var numValues : int32
  let hh = newWideCString path

  var newHandle: HKEY
  call regOpenKeyEx(handle, hh, 0, KEY_READ or KEY_WOW64_64KEY, newHandle)
  call regQueryInfoKey(newHandle, nil, nil, nil, nil, nil, nil, addr numValues, nil, nil, nil, nil)
  for i in 0 ..< numValues:
    var regValueSize = 0'i32
    var regNameSize = 16383'i32
    var regName = newWideCString("", regNameSize)
    call regEnumValue(newHandle, int32(i), regName, addr regNameSize, nil, nil, nil, addr regValueSize)
    var regValue = newWideCString("", regValueSize)
    regNameSize += 2 # reallocate for null wchar.
    call regEnumValue(newHandle, int32(i), regName, addr regNameSize, nil, nil, cast[pointer](regValue), addr regValueSize)
    yield (regName $ regNameSize, regValue $ regValueSize)
  
  call regCloseKey(newHandle)

proc getDwordValue*(path, key: string; handle: HKEY): int32 =
  let hh = newWideCString path
  let kk = newWideCString key
  var buffsize = 4'i32
  var flags: int32 = RRF_RT_REG_DWORD
  call regGetValue(handle, hh, kk, flags, nil, addr result, addr buffsize)

proc getUnicodeValue*(path, key: string; handle: HKEY): string =
  let hh = newWideCString path
  let kk = newWideCString key
  var bufsize: int32
  # try a couple of different flag settings:
  var flags: int32 = RRF_RT_ANY
  let err = regGetValue(handle, hh, kk, flags, nil, nil, addr bufsize)
  if err != 0:
    var newHandle: HKEY
    call regOpenKeyEx(handle, hh, 0, KEY_READ or KEY_WOW64_64KEY, newHandle)
    call regGetValue(newHandle, nil, kk, flags, nil, nil, addr bufsize)
    var res = newWideCString("", bufsize)
    call regGetValue(newHandle, nil, kk, flags, nil, cast[pointer](res),
                   addr bufsize)
    result = res $ bufsize
    call regCloseKey(newHandle)
  else:
    var res = newWideCString("", bufsize)
    call regGetValue(handle, hh, kk, flags, nil, cast[pointer](res),
                   addr bufsize)
    result = res $ bufsize

proc regSetValue(key: HKEY, lpSubKey, lpValueName: WideCString,
                 dwType: int32; lpData: WideCString; cbData: int32): int32 {.
  importc: "RegSetKeyValueW", dynlib: "Advapi32.dll", stdcall.}

proc setUnicodeValue*(path, key, val: string; handle: HKEY) =
  let hh = newWideCString path
  let kk = newWideCString key
  let vv = newWideCString val
  call regSetValue(handle, hh, kk, REG_SZ, vv, (vv.len.int32+1)*2)

