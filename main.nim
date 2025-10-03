{.push warningAsError[Effect]: on.}
    
# Standard Modules
import std / [strutils, tables, os]
import lexer
import errors

type 
    ORB_VAR = object
        Type*: string
        Value*: string
        Content*: seq[string]

# Variables Table
var VARIABLES* = initTable[string, Table[string, ORB_VAR]]()
type TOKEN = tuple[Token: string, Value: string, isToken: bool, isStatement: bool]


let FILENAME = commandLineParams()[0]
    
proc main(): void =
    let Tokens: Table[int, seq[TOKEN]] = Lex(FILENAME)

    for line in 0..<Tokens.len:
        for token in Tokens[line]:
            echo token
main()