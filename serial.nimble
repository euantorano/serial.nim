# Package

version       = "1.1.3"
author        = "Euan T"
description   = "SerialPort library for Nim."
license       = "BSD-3-Clause"

srcDir = "src"

# Dependencies

requires "nim >= 1.0.0"

task docs, "Build documentation":
  exec "nim doc --project --index:on -o:docs/ src/serial.nim"
