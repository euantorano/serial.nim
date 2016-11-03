import ../serialport

when isMainModule:
  proc main =
    for p in listSerialPorts():
      echo "Found port: ", p

  main()
