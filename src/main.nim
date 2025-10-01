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

proc main()=
    let Tokens: Table[int, seq[TOKEN]] = Lex(FILENAME)

main()