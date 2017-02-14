# Package

version       = "0.1.1"
author        = "Euan T"
description   = "A library to operate serial ports using pure Nim."
license       = "BSD3"

srcDir = "src"

# Dependencies

requires "nim >= 0.15.2"

task docs, "Build documentation":
  exec "nim doc2 -o:docs/libserialport.html src/libserialport.nim"
