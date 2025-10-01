import errors
import tables
import strutils

type TOKEN = tuple[
    Token: string,
    Value: string,
    isToken: bool,
    isStatement: bool
]

proc expect*(values: seq[string], tokens: Table[int, seq[TOKEN]], line: int = 0, position: int = 0, err: string = "NAME_EXPECTED"): TOKEN = 
    var token = tokens[line][position]
    var prev_token = "null"

    if position + 1 >= tokens[line].len and err == "NAME_EXPECTED":
        throwError(err, line, @[token.Value, ""]) 

    for name in values:
        if position + 1 < tokens[line].len and tokens[line][position + 1].Token.contains(name):
            return tokens[line][position+1]

    if position + 1 < tokens[line].len:
        prev_token = "'" & tokens[line][position + 1].Value & "'"

    throwError(err, line, @[token.Value, prev_token])