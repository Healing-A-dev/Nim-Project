import tables
import os
import strutils

var Adjustment = 0
var FILENAME = commandLineParams()[0]


# Process Stack Information #
proc processStack(): string =
    return ""
    
    
# Process Error Information #
proc processInfo(process: seq[string] = @[], size: int = 8): seq[string] =
    var table: seq[string] = @[]
    for s in 0..size:
        if s <= process.len - 1:
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
        else:
            table.add("null")
    return table


# Errors #
proc throwError*(errorType: string, line: int = 0, data: seq[string] = @[], passthrough: bool = false): void =
    let errData = processInfo(data)

    # Available Errors #
    let errors = {
        "FILE_DNE":           "Orb: \e[31merror: \e[0mfailure to open file '" & FILENAME & "\n|> file or directory was not found",
        "NAME_EXPECTED":      "Orb: \e[31merror: \e[0mfailure to process file '" & FILENAME & "'\n\e[1m|> name expected near " & errData[0] & " got " & errData[1] & "\e[0m\n|> usage: `" & errData[0] & "` <name> \n|> " & FILENAME & ":" & intToStr(line+1),
        "VALUE_EXPECTED":     "Orb: \e[31merror: \e[0mfailure to process file '" & FILENAME & "'\n\e[1m|> value expected near " & errData[0] & " got " & errData[1] & "\e[0m\n|> usage: `" & errData[0] & "` <value> \n|> " & FILENAME & ":" & intToStr(line+1),
        "SYNTAX_ERROR":       "Orb: \e[31merror: \e[0mfailure to process file '" & FILENAME & "'\n\e[1m|> syntax error near '" & errData[0] & "'\e[0m\n|> reason: `" & errData[1] & "`\n|> usage: " & errData[2] & " <" & errData[3] & ">" & errData[4] & "\n|> " & FILENAME & ":" & intToStr(line+1) 
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
