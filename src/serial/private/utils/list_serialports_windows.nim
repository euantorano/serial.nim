# Windows specific code to list available serial ports using SetupDiGetClassDevs().

import winlean, os, windows_registry, unicode, strutils

type
  HDEVINFO = ptr HANDLE
  HKEY = uint
  REGSAM = DWORD
  SP_DEVINFO_DATA {.final, pure.} = object
    cbSize: DWORD
    ClassGuid: GUID
    DevInst: DWORD
    Reserved: pointer

const
  DIGCF_PRESENT: uint = 0x00000002
  DIGCF_DEVICEINTERFACE: uint = 0x00000010
  setupDiGetClassDevsInitialFlags: DWORD = DWORD(DIGCF_PRESENT or DIGCF_DEVICEINTERFACE)
  DICS_FLAG_GLOBAL: DWORD = 1
  DIREG_DEV: DWORD = 1
  KEY_QUERY_VALUE: REGSAM = 1
  NULL_HANDLE: uint = 0

var
  GUID_DEVINTERFACE_COMPORT: GUID = GUID(D1: 0x86e0d1e0'i32, D2: 0x8089'i16,
    D3: 0x11d0, D4: [
    0x9c'i8, 0xe4'i8, 0x08'i8, 0x00'i8, 0x3e'i8, 0x30'i8, 0x1f'i8, 0x73'i8])

proc SetupDiGetClassDevs(ClassGuid: ptr GUID, Enumerator: cstring,
    hwndParent: uint, Flags: DWORD): HDEVINFO
  {.stdcall, importc: "SetupDiGetClassDevsW", dynlib: "setupapi.dll".}

proc SetupDiEnumDeviceInfo(DeviceInfoSet: HDEVINFO, MemberIndex: DWORD,
    DeviceInfoData: ptr SP_DEVINFO_DATA): bool
  {.stdcall, importc: "SetupDiEnumDeviceInfo", dynlib: "setupapi.dll".}

proc SetupDiOpenDevRegKey(DeviceInfoSet: HDEVINFO,
    DeviceInfoData: ptr SP_DEVINFO_DATA, Scope: DWORD, HwProfile: DWORD,
    KeyType: DWORD, samDesired: REGSAM): HKEY
  {.stdcall, importc: "SetupDiOpenDevRegKey", dynlib: "setupapi.dll".}

proc SetupDiDestroyDeviceInfoList(DeviceInfoSet: HDEVINFO): bool
  {.stdcall, importc: "SetupDiDestroyDeviceInfoList", dynlib: "setupapi.dll".}

iterator listSerialPorts*(): string =
  ## Iterates through a list of serial port names currently available on the system.

  
  ## First we enumerate the USB serial ports from the appropritate registry node, 
  ## this is because some of them are reported not to show up using the second method below.
  ## see https://github.com/euantorano/serial.nim/issues/26
  var usbSerialPortList = newSeq[string]()

  var numUsbDevices = 0
  try:
    # the Enum node does not exist if no usb devices have been connected since startup hence the try block
    numUsbDevices = getDwordValue(r"SYSTEM\CurrentControlSet\Services\usbser\Enum", "Count", HKEY_LOCAL_MACHINE)
  except OSError:
    discard #numUsbDevices stays at zero

  for devNum in 0..<numUsbDevices:
    var nodePath = getUnicodeValue(r"SYSTEM\CurrentControlSet\Services\usbser\Enum", $devNum, HKEY_LOCAL_MACHINE)
    if nodePath.toUpper.contains("VID_0483&PID_5740"):
      var portname = getUnicodeValue(r"SYSTEM\CurrentControlSet\Enum\" & nodePath & r"\Device Parameters", "PortName", HKEY_LOCAL_MACHINE)
      usbSerialPortList.add(portname)
      yield portname

  ## Secondly we hit the serial api and enumerate anything that has not already been found.
  ## This part is based upon the `CEnumerateSerial::QueryUsingSetupAPI` method from `CEnumerateSerial`: http://www.naughter.com/enumser.html

  # Create a "device info set" for the device interface GUID
  let devInfoSet = SetupDiGetClassDevs(addr GUID_DEVINTERFACE_COMPORT, nil,
      NULL_HANDLE, setupDiGetClassDevsInitialFlags)
  if devInfoSet[] == -1:
    raiseOsError(osLastError())

  try:
    var
      moreItems: bool = true
      index: DWORD = 0
      devInfo: SP_DEVINFO_DATA

    ## Then enumerate the entries in the device info set
    while moreItems:
      devInfo.cbSize = DWORD(sizeof(SP_DEVINFO_DATA))
      moreItems = SetupDiEnumDeviceInfo(devInfoSet, index, addr devInfo)

      if moreItems:
        # Open the registry key for the device
        let regKey: HKEY = SetupDiOpenDevRegKey(devInfoSet, addr devInfo,
            DICS_FLAG_GLOBAL, 0, DIREG_DEV, KEY_QUERY_VALUE)

        if regKey != cast[HKEY](-1):
          # Then read the port name from the registry
          var portname = getUnicodeValue("", "PortName", regKey)
          if not usbSerialPortList.contains(portname):
            yield portname

      inc(index)

  finally:
    # Destroy the "device info set" once done with it
    if not SetupDiDestroyDeviceInfoList(devInfoSet):
      raiseOsError(osLastError())
