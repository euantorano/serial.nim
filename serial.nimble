# Package

version       = "1.0.0"
author        = "Euan T"
description   = "SerialPort library for Nim."
license       = "BSD3"

srcDir = "src"

# Dependencies

requires "nim >= 0.16.0"

task docs, "Build documentation":
  exec "nim doc2 --project --index:on -o:docs/ src/serial.nim"
