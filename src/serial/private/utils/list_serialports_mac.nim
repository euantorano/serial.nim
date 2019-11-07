# OS X specific code to list available serial ports using IO Kit.

{.passl: "-framework IOKit -framework CoreFoundation".}

type
  kern_return_t = int32
  mach_port_t = uint32
  io_object_t {.importc: "io_object_t", header: "<IOKit/IOTypes.h>".} = mach_port_t
  io_iterator_t {.importc: "io_iterator_t", header: "<IOKit/IOTypes.h>".} = io_object_t
  CFAllocatorRef {.importc: "CFAllocatorRef", header: "<CoreFoundation/CoreFoundation.h>".} = pointer
  CFStringEncoding {.importc: "CFStringEncoding", header: "<CoreFoundation/CoreFoundation.h>".} = uint32
  CFStringRef {.importc: "CFStringRef", header: "<CoreFoundation/CoreFoundation.h>".} = ref cstring
  IOOptionBits = uint32
  CFTypeRef {.importc: "CFTypeRef", header: "<CoreFoundation/CoreFoundation.h>".} = pointer

const
  KERN_SUCCESS: kern_return_t = 0

var
  kIOMasterPortDefault {.importc: "kIOMasterPortDefault", header: "<IOKit/IOKitLib.h>".}: mach_port_t
  kCFAllocatorDefault {.importc: "kCFAllocatorDefault", header: "<CoreFoundation/CoreFoundation.h>".}: CFAllocatorRef
  kCFStringEncodingMacRoman {.importc: "kCFStringEncodingMacRoman", header: "<CoreFoundation/CoreFoundation.h>".}: CFStringEncoding

proc IOServiceGetMatchingServices(masterPort: mach_port_t, matching: pointer,
    existing: ptr io_iterator_t): kern_return_t {.importc: "IOServiceGetMatchingServices",
    header: "<IOKit/IOKitLib.h>".}

proc IOServiceMatching(name: cstring): pointer {.importc: "IOServiceMatching", header: "<IOKit/IOKitLib.h>".}

proc IOIteratorIsValid(theIterator: io_iterator_t): bool {.importc: "IOIteratorIsValid", header: "<IOKit/IOKitLib.h>".}

proc IOIteratorNext(theIterator: io_iterator_t): io_object_t {.importc: "IOIteratorNext", header: "<IOKit/IOKitLib.h>".}

proc IOObjectRelease(obj: io_object_t): kern_return_t {.importc: "IOObjectRelease", header: "<IOKit/IOKitLib.h>".}

proc CFStringCreateWithCString(allocator: CFAllocatorRef, cStr: cstring,
  encoding: CFStringEncoding): CFStringRef {.importc: "CFStringCreateWithCString", header: "<CoreFoundation/CoreFoundation.h>".}

proc IORegistryEntryCreateCFProperty(entry: io_object_t, key: CFStringRef,
    allocator: CFAllocatorRef, options: IOOptionBits): CFTypeRef {.importc: "IORegistryEntryCreateCFProperty", header: "<IOKit/IOKitLib.h>".}

proc CFStringGetCStringPtr(theString: CFTypeRef, encoding: CFStringEncoding): cstring {.importc: "CFStringGetCStringPtr", header: "<CoreFoundation/CoreFoundation.h>".}

proc CFRelease(cf: CFTypeRef) {.importc: "CFRelease", header: "<CoreFoundation/CoreFoundation.h>".}

iterator GetIOServicesByType(): io_object_t =
  var
    serialPortIterator: io_iterator_t
    service: io_object_t

  let kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOSerialBSDClient"), addr serialPortIterator)
  if kernResult != KERN_SUCCESS:
    raise newException(OSError, "Error getting matching services")

  try:
    while IOIteratorIsValid(serialPortIterator):
      service = IOIteratorNext(serialPortIterator)
      if service == 0:
        break
      yield service
  finally:
    discard IOObjectRelease(serialPortIterator)

proc getDeviceName(service: io_object_t): cstring =
  let key = CFStringCreateWithCString(kCFAllocatorDefault, "IOCalloutDevice", kCFStringEncodingMacRoman)
  let cfContainer = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0)

  if cfContainer != nil:
    let name = CFStringGetCStringPtr(cfContainer, kCFStringEncodingMacRoman)
    result = name

    CFRelease(cfContainer)

iterator listSerialPorts*(): string =
  for service in GetIOServicesByType():
    let name = getDeviceName(service)
    if len(name) > 0:
      yield $name
