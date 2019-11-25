## Foreign function interfaces for Windows, which are missing from winlean.

import winlean, os

const
  ERROR_INVALID_PARAMETER* = 0x57'i32
  ERROR_INVALID_HANDLE* = 0x06'i32

  ONESTOPBIT* = byte(0)
  ONE5STOPBITS* = byte(1)
  TWOSTOPBITS* = byte(2)

  RTS_CONTROL_DISABLE* = DWORD(0x00)
    ## Disables the RTS line when the device is opened and leaves it disabled.
  RTS_CONTROL_ENABLE* = DWORD(0x01)
    ## Enables the RTS line when the device is opened and leaves it on.
  RTS_CONTROL_HANDSHAKE* = DWORD(0x02)
    ## Enables RTS handshaking. The driver raises the RTS line when the "type-ahead" (input) buffer is less than one-half full and lowers the RTS line when the buffer is more than three-quarters full. If handshaking is enabled, it is an error for the application to adjust the line by using the EscapeCommFunction function.
  RTS_CONTROL_TOGGLE* = DWORD(0x03)
    ## Specifies that the RTS line will be high if bytes are available for transmission. After all buffered bytes have been sent, the RTS line will be low.

  DTR_CONTROL_DISABLE* = DWORD(0x00)
    ## Disables the DTR line when the device is opened and leaves it disabled.
  DTR_CONTROL_ENABLE* = DWORD(0x01)
    ## Enables the DTR line when the device is opened and leaves it on.
  DTR_CONTROL_HANDSHAKE* = DWORD(0x02)
    ## Enables DTR handshaking. If handshaking is enabled, it is an error for the application to adjust the line by using the EscapeCommFunction function.

  #mp035: winlean defines DWORD as int32
  #MAXDWORD*: DWORD = DWORD(high(uint32))
  MAXDWORD*: DWORD = DWORD(high(int32))

  EV_BREAK*: DWORD = DWORD(0x0040)
    ## A break was detected on input.
  EV_CTS*: DWORD = DWORD(0x0008)
    ## The CTS (clear-to-send) signal changed state.
  EV_DSR*: DWORD = DWORD(0x0010)
    ## The DSR (data-set-ready) signal changed state.
  EV_ERR*: DWORD = DWORD(0x0080)
    ## A line-status error occurred. Line-status errors are CE_FRAME, CE_OVERRUN, and CE_RXPARITY.
  EV_RING*: DWORD = DWORD(0x0100)
    ## A ring indicator was detected.
  EV_RLSD*: DWORD = DWORD(0x0020)
    ## The RLSD (receive-line-signal-detect) signal changed state.
  EV_RXCHAR*: DWORD = DWORD(0x0001)
    ## A character was received and placed in the input buffer.
  EV_RXFLAG*: DWORD = DWORD(0x0002)
    ## The event character was received and placed in the input buffer. The event character is specified in the device's DCB structure, which is applied to a serial port by using the SetCommState function.
  EV_TXEMPTY*: DWORD = DWORD(0x0004)
    ## The last character in the output buffer was sent.
  ALL_EVENTS*: DWORD = DWORD(0x1fb)
    ## All events, except EV_TXEMPTY.

  CLRBREAK*: DWORD = DWORD(9)
    ## Restores character transmission and places the transmission line in a nonbreak state. The CLRBREAK extended function code is identical to the ClearCommBreak function.
  CLRDTR*: DWORD = DWORD(6)
    ## Clears the DTR (data-terminal-ready) signal.
  CLRRTS*: DWORD = DWORD(4)
    ## Clears the RTS (request-to-send) signal.
  SETBREAK*: DWORD = DWORD(8)
    ## Suspends character transmission and places the transmission line in a break state until the ClearCommBreak function is called (or EscapeCommFunction is called with the CLRBREAK extended function code). The SETBREAK extended function code is identical to the SetCommBreak function. Note that this extended function does not flush data that has not been transmitted.
  SETDTR*: DWORD = DWORD(5)
    ## Sends the DTR (data-terminal-ready) signal.
  SETRTS*: DWORD = DWORD(3)
    ## Sends the RTS (request-to-send) signal.
  SETXOFF*: DWORD = DWORD(1)
    ## Causes transmission to act as if an XOFF character has been received.
  SETXON*: DWORD = DWORD(2)
    ## Causes transmission to act as if an XON character has been received.

  ERROR_BAD_COMMAND*: int32 = 0x16
    ## The device does not recognize the command.
  ERROR_DEVICE_REMOVED*: int32 = 1617

  PURGE_RXABORT*: DWORD = DWORD(0x0002)
    ## Terminates all outstanding overlapped read operations and returns immediately, even if the read operations have not been completed.
  PURGE_RXCLEAR*: DWORD = DWORD(0x0008)
    ## Clears the input buffer (if the device driver has one).
  PURGE_TXABORT*: DWORD = DWORD(0x0001)
    ## Terminates all outstanding overlapped write operations and returns immediately, even if the write operations have not been completed.
  PURGE_TXCLEAR*: DWORD = DWORD(0x0004)
    ## Clears the output buffer (if the device driver has one).

  MS_CTS_ON*: DWORD = DWORD(0x10)
    ## The CTS (clear-to-send) signal is on.
  MS_DSR_ON*: DWORD = DWORD(0x20)
    ## The DSR (data-set-ready) signal is on.
  MS_RING_ON*: DWORD = DWORD(0x40)
    ## The ring indicator signal is on.
  MS_RLSD_ON*: DWORD = DWORD(0x80)
    ## The RLSD (receive-line-signal-detect) signal is on.

  CE_RXOVER*: DWORD = DWORD(0x01)
  CE_OVERRUN*: DWORD = DWORD(0x02)
  CE_PARITY*: DWORD = DWORD(0x04)
  CE_FRAME*: DWORD = DWORD(0x08)
  CE_BREAK*: DWORD = DWORD(0x10)
  CE_TXFULL*: DWORD = DWORD(0x100)

type
  FileType* {.pure.} = enum
    Unknown = DWORD(0x0000), ## Either the type of the specified file is unknown, or the function failed.
    Disk = DWORD(0x0001), ## The specified file is a disk file.
    Character = DWORD(0x0002), ## The specified file is a character file, typically an LPT device or a console.
    Pipe = DWORD(0x0003), ## The specified file is a socket, a named pipe, or an anonymous pipe.
    Remote = DWORD(0x8000), ## Unused

  WORD* = uint16

  CommProp* {.importc: "COMMPROP", header: "Windows.h", incompleteStruct.} = object
    wPacketLength*: WORD ## The size of the entire data packet, regardless of the amount of data requested, in bytes.
    wPacketVersion*: WORD ## The version of the structure.
    dwServiceMask*: DWORD ## A bitmask indicating which services are implemented by this provider. The SP_SERIALCOMM value is always specified for communications providers, including modem providers.
    dwReserved1*: DWORD # Reserved; do not use.
    dwMaxTxQueue*: DWORD ## The maximum size of the driver's internal output buffer, in bytes. A value of zero indicates that no maximum value is imposed by the serial provider.
    dwMaxRxQueue*: DWORD ## The maximum size of the driver's internal input buffer, in bytes. A value of zero indicates that no maximum value is imposed by the serial provider.
    dwMaxBaud*: DWORD ## The maximum allowable baud rate, in bits per second (bps).
    dwProvSubType*: DWORD ## The communications-provider type.
    dwProvCapabilities*: DWORD ## A bitmask indicating the capabilities offered by the provider.
    dwSettableParams*: DWORD ## A bitmask indicating the communications parameters that can be changed.
    dwSettableBaud*: DWORD ## The baud rates that can be used. For values, see the dwMaxBaud member.
    wSettableData*: WORD ## A bitmask indicating the number of data bits that can be set.
    wSettableStopParity*: WORD ## A bitmask indicating the stop bit and parity settings that can be selected.
    dwCurrentTxQueue*: DWORD ## The size of the driver's internal output buffer, in bytes. A value of zero indicates that the value is unavailable.
    dwCurrentRxQueue*: DWORD ## The size of the driver's internal input buffer, in bytes. A value of zero indicates that the value is unavailable.
    dwProvSpec1*: DWORD ## Any provider-specific data. Applications should ignore this member unless they have detailed information about the format of the data required by the provider.
    dwProvSpec2*: DWORD ## Any provider-specific data. Applications should ignore this member unless they have detailed information about the format of the data required by the provider.
    wcProvChar*: array[1, WinChar] ## Any provider-specific data. Applications should ignore this member unless they have detailed information about the format of the data required by the provider.

  LPCOMMPROP* = ptr CommProp

  ComStat* {.importc: "COMSTAT", header: "Windows.h", incompleteStruct.} = object
    fCtsHold* {.bitsize:1.}: DWORD ## If this member is TRUE, transmission is waiting for the CTS (clear-to-send) signal to be sent.
    fDsrHold* {.bitsize:1.}: DWORD ## If this member is TRUE, transmission is waiting for the DSR (data-set-ready) signal to be sent.
    fRlsdHold* {.bitsize:1.}: DWORD ## If this member is TRUE, transmission is waiting for the RLSD (receive-line-signal-detect) signal to be sent.
    fXoffHold* {.bitsize:1.}: DWORD ## If this member is TRUE, transmission is waiting because the XOFF character was received.
    fXoffSent* {.bitsize:1.}: DWORD ## If this member is TRUE, transmission is waiting because the XOFF character was transmitted. (Transmission halts when the XOFF character is transmitted to a system that takes the next character as XON, regardless of the actual character.)
    fEof* {.bitsize:1.}: DWORD ## If this member is TRUE, the end-of-file (EOF) character has been received.
    fTxim* {.bitsize:1.}: DWORD ## If this member is TRUE, there is a character queued for transmission that has come to the communications device by way of the TransmitCommChar function. The communications device transmits such a character ahead of other characters in the device's output buffer.
    fReserved* {.bitsize:25.}: DWORD ## Reserved; do not use.
    cbInQue*: DWORD ## The number of bytes received by the serial provider but not yet read by a ReadFile operation.
    cbOutQue*: DWORD ## The number of bytes of user data remaining to be transmitted for all write operations. This value will be zero for a nonoverlapped write.

  DCB* {.importc: "DCB", header: "<windows.h>", incompleteStruct.} = object
    DCBlength*: DWORD ## The length of the structure, in bytes. The caller must set this member to sizeof(DCB).
    BaudRate*: DWORD ## The baud rate at which the communications device operates.
    fBinary* {.bitsize: 1.}: DWORD ## If this member is TRUE, binary mode is enabled. Windows does not support nonbinary mode transfers, so this member must be TRUE.
    fParity* {.bitsize: 1.}: DWORD ## If this member is TRUE, parity checking is performed and errors are reported.
    fOutxCtsFlow* {.bitsize: 1.}: DWORD # #If this member is TRUE, the CTS (clear-to-send) signal is monitored for output flow control. If this member is TRUE and CTS is turned off, output is suspended until CTS is sent again.
    fOutxDsrFlow* {.bitsize: 1.}: DWORD ## If this member is TRUE, the DSR (data-set-ready) signal is monitored for output flow control. If this member is TRUE and DSR is turned off, output is suspended until DSR is sent again.
    fDtrControl* {.bitsize: 2.}: DWORD ## The DTR (data-terminal-ready) flow control.
    fDsrSensitivity* {.bitsize: 1.}: DWORD ## If this member is TRUE, the communications driver is sensitive to the state of the DSR signal. The driver ignores any bytes received, unless the DSR modem input line is high.
    fTXContinueOnXoff* {.bitsize: 1.}: DWORD ## If this member is TRUE, transmission continues after the input buffer has come within XoffLim bytes of being full and the driver has transmitted the XoffChar character to stop receiving bytes. If this member is FALSE, transmission does not continue until the input buffer is within XonLim bytes of being empty and the driver has transmitted the XonChar character to resume reception.
    fOutX* {.bitsize: 1.}: DWORD ## Indicates whether XON/XOFF flow control is used during transmission. If this member is TRUE, transmission stops when the XoffChar character is received and starts again when the XonChar character is received.
    fInX* {.bitsize: 1.}: DWORD ## Indicates whether XON/XOFF flow control is used during reception. If this member is TRUE, the XoffChar character is sent when the input buffer comes within XoffLim bytes of being full, and the XonChar character is sent when the input buffer comes within XonLim bytes of being empty.
    fErrorChar* {.bitsize: 1.}: DWORD ## Indicates whether bytes received with parity errors are replaced with the character specified by the ErrorChar member. If this member is TRUE and the fParity member is TRUE, replacement occurs.
    fNull* {.bitsize: 1.}: DWORD ## If this member is TRUE, null bytes are discarded when received.
    fRtsControl* {.bitsize: 2.}: DWORD ## The RTS (request-to-send) flow control.
    fAbortOnError* {.bitsize: 1.}: DWORD ## If this member is TRUE, the driver terminates all read and write operations with an error status if an error occurs. The driver will not accept any further communications operations until the application has acknowledged the error by calling the ClearCommError function.
    fDummy2* {.bitsize: 17.}: DWORD ## Reserved; do not use.
    wReserved*: WORD ## Reserved; must be zero.
    XonLim*: WORD ## The minimum number of bytes in use allowed in the input buffer before flow control is activated to allow transmission by the sender. This assumes that either XON/XOFF, RTS, or DTR input flow control is specified in the fInX, fRtsControl, or fDtrControl members.
    XoffLim*: WORD ## The minimum number of free bytes allowed in the input buffer before flow control is activated to inhibit the sender. Note that the sender may transmit characters after the flow control signal has been activated, so this value should never be zero. This assumes that either XON/XOFF, RTS, or DTR input flow control is specified in the fInX, fRtsControl, or fDtrControl members. The maximum number of bytes in use allowed is calculated by subtracting this value from the size, in bytes, of the input buffer.
    ByteSize*: byte ## The number of bits in the bytes transmitted and received.
    Parity*: byte ## The parity scheme to be used.
    StopBits*: byte ## The number of stop bits to be used.
    XonChar*: cchar ## The value of the XON character for both transmission and reception.
    XoffChar*: cchar ## The value of the XOFF character for both transmission and reception.
    ErrorChar*: cchar ## The value of the character used to replace bytes received with a parity error.
    EofChar*: cchar ## The value of the character used to signal the end of data.
    EvtChar*: cchar ## The value of the character used to signal an event.
    wReserved1*: WORD ## Reserved; do not use.

  LPDCB = ptr DCB

  COMMTIMEOUTS* {.importc: "COMMTIMEOUTS", header: "<windows.h>", incompleteStruct.} = object
    ReadIntervalTimeout*: DWORD
    ReadTotalTimeoutMultiplier*: DWORD
    ReadTotalTimeoutConstant*: DWORD
    WriteTotalTimeoutMultiplier*: DWORD
    WriteTotalTimeoutConstant*: DWORD

proc GetFileType*(hFile: Handle): DWORD {.stdcall, dynlib: "kernel32", importc: "GetFileType".}

proc GetCommProperties*(hFile: Handle, lpCommProp: LPCOMMPROP): WINBOOL {.stdcall, dynlib: "kernel32", importc: "GetCommProperties".}

proc GetCommModemStatus*(hFile: Handle, lpModemStat: PDWORD): WINBOOL {.stdcall, dynlib: "kernel32", importc: "GetCommModemStatus".}

proc GetCommState*(hFile: Handle, lpDCB: LPDCB): WINBOOL {.stdcall, dynlib: "kernel32", importc: "GetCommState".}

proc SetCommState*(hFile: Handle, lpDCB: LPDCB): WINBOOL {.stdcall, dynlib: "kernel32", importc: "SetCommState".}

proc GetCommTimeouts*(hFile: Handle, lpCommTimeouts: ptr COMMTIMEOUTS): WINBOOL {.stdcall, dynlib: "kernel32", importc: "GetCommTimeouts".}

proc SetCommTimeouts*(hFile: Handle, lpCommTimeouts: ptr COMMTIMEOUTS): WINBOOL {.stdcall, dynlib: "kernel32", importc: "SetCommTimeouts".}

proc SetCommMask*(hFile: Handle, dwEvtMask: DWORD): WINBOOL {.stdcall, dynlib: "kernel32", importc: "SetCommMask".}

proc EscapeCommFunction*(hFile: Handle, dwFunc: DWORD): WINBOOL {.stdcall, dynlib: "kernel32", importc: "EscapeCommFunction".}

proc FlushFileBuffers*(hFile: Handle): WINBOOL {.stdcall, dynlib: "kernel32", importc: "FlushFileBuffers".}

proc PurgeComm*(hFile: Handle, dwFlags: DWORD): WINBOOL {.stdcall, dynlib: "kernel32", importc: "PurgeComm".}

proc SetCommBreak*(hFile: Handle): WINBOOL {.stdcall, dynlib: "kernel32", importc: "SetCommBreak".}

proc ClearCommBreak*(hFile: Handle): WINBOOL {.stdcall, dynlib: "kernel32", importc: "ClearCommBreak".}

proc ClearCommError*(hFile: Handle, lpErrors: ptr DWORD, lpStat: ptr ComStat): WINBOOL {.stdcall, dynlib: "kernel32", importc: "ClearCommError".}

when useWinUnicode:
  const CreateFileWindows* = createFileW
else:
  const CreateFileWindows* = createFileA

template getWindowsString*(str: string): untyped =
  when useWinUnicode:
    newWideCString(str)
  else:
    cstring(str)
