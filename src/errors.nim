import tables
import os
import strutils

var Adjustment = 0
var FILENAME = commandLineParams()[0]


# Process Information #
proc processInfo(process: seq[string] = @[], size: int = 8): seq[string] =
    var table: seq[string] = @[]
    for s in 0..<min(size, process.len):
        case process[s]
        of "proc":
            if process.len >= 3:
                table.add(process[s] & "edure <" & process[2] & ">")
            else:
                table.add(process[s] & "edure")
        of "if", "elseif", "for"," while", "else":
            table.add(process[s] & " statement")
        else:
            table.add(process[s])
    return table


# Errors #
proc throwError*(errorType: string, line: int = 0, data: seq[string] = @[], passthrough: bool = false): void =
    let errData = processInfo(data)

    # Available Errors #
    let errors = {
        "FILE_DNE":          "Orb: \027[93merror: \027[0mfailure to open file " & FILENAME & "\n|> file or directory was not found",
        "UNFINISHED_STRING": "Orb: \027[93merror: \027[0mfailure to process file " & FILENAME & "\n|> unfishied string near " & errData[0],
        "NAME_EXPECTED":     "Orb: \027[93merror: \027[0mfailure to process file '" & FILENAME & "'\n\027[1m|> name expected near " & errData[0] & " got " & errData[1] & "\027[0m\n|> usage: `" & errData[0] & "` <name> \n|> " & FILENAME & ":" & intToStr(line+1),
        "VALUE_EXPECTED":     "Orb: \027[93merror: \027[0mfailure to process file '" & FILENAME & "'\n\027[1m|> value expected near " & errData[0] & " got " & errData[1] & "\027[0m\n|> usage: `" & errData[0] & "` <value> \n|> " & FILENAME & ":" & intToStr(line+1)
    }.toTable()


    if errors.hasKey(errorType):
        echo errors[errorType]
    else:
        echo errorType

    if not passthrough:
        quit()


# Warnings #
proc throwWarning*(msg: string, data: seq[string] = @[]): void =
    const header = "Orb: warning: "
    echo header & msg
