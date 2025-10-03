# Modules
import std/[strutils, tables, re, os]
import tokens
import errors
import helper

# Creating TOKEN type #
type TOKEN = tuple[
  Token: string,
  Value: string,
  isToken: bool,
  isStatement: bool
]

# Instance Variables #
var LexerTokens = initTable[int, seq[TOKEN]]()
var DISCARDED: TOKEN = (Token: "DISCARDED", Value: "", isToken: false, isStatement: false)


# Token Checker #
proc isValidToken(token: string): TOKEN =
  if len(token) == 1:
    if Tokens.hasKey(token):
      return (Token: Tokens.getOrDefault(token), Value: token, isToken: true, isStatement: false)
    
  elif len(token) > 1:
    let rep_token = token.replace(re"\s+", "")
    if Tokens.hasKey(rep_token):
      let token_value = Tokens.getOrDefault(rep_token)
      if token_value.contains("STMT"):
        return (Token: token_value, Value: rep_token, isToken: true, isStatement: true)
            
      return (Token: token_value, Value: rep_token, isToken: true, isStatement: false)
    
  return (Token: "", Value: "", isToken: false, isStatement: false)


# Tokenizer #
proc Tokenize(lines: seq[string]) =
  var token_buffer: seq[string] = @[]
  for line, content in lines.pairs():
    LexerTokens[line] = @[]
    for character in content:
      if not isValidToken("" & character).isToken:
        token_buffer.add("" & character)
      else:
        if len(token_buffer) > 0:
          let token = token_buffer.join("")
          let token_data = isValidToken(token)
          if token_data.isToken:
            LexerTokens[line].add(token_data)
          else:
            LexerTokens[line].add((Token: "TBD", Value: token, isToken: false, isStatement: false))
              
        token_buffer.setLen(0)
        LexerTokens[line].add(isValidToken("" & character))
    if len(token_buffer) > 0:
      let token = token_buffer.join("")
      let token_data = isValidToken("" & token)
      if token_data.isToken:
        LexerTokens[line].add(token_data)
      else:
        LexerTokens[line].add((Token: "TBD", Value: token, isToken: false, isStatement: false))
      token_buffer.setLen(0)


proc Adjust() =
  # Instance Variables
  var multiline_comment = false

  for line in 0..<LexerTokens.len:
    var fix: seq[TOKEN] = @[]
    var pos = 0
    while pos < LexerTokens[line].len:
      var token = LexerTokens[line][pos]

      # Combined tokens
      if pos < LexerTokens[line].len-1:
        let combined = fetchCombinedToken(token.Value, LexerTokens[line][pos+1].Value)
        if combined.Token != "":
          fix.add(combined)
          pos += 2
          continue

      # String literals
      if token.Token.contains("QUOTE"):
        var buffer: seq[string] = @[]
        var skipper = 1
        while pos+skipper < LexerTokens[line].len and LexerTokens[line][pos+skipper].Token != token.Token:
          buffer.add(LexerTokens[line][pos+skipper].Value)
          LexerTokens[line][pos+skipper] = DISCARDED
          skipper.inc()

        if pos+skipper >= LexerTokens[line].len:
          throwError("SYNTAX_ERROR", line, @[buffer.join(""), "unfinished string near: " & buffer.join(""), "`" & token.Value & "`" , "string", " `" & token.Value & "`"])
        else:
          fix.add((Token: "STR", Value: buffer.join(""), isToken: true, isStatement: false))
          LexerTokens[line][pos+skipper] = DISCARDED
          pos += skipper+1
          continue

      # Numbers
      if token.Token == "TBD":
        try:
          discard parseInt(token.Value)
          fix.add((Token: "NUM", Value: token.Value, isToken: true, isStatement: false))
          LexerTokens[line][pos] = DISCARDED
          pos.inc()
          continue
        except ValueError as err:
          discard

      # Comments
      if token.Token.contains("COMMENT_START"):
        multiline_comment = true
      elif token.Token.contains("COMMENT_END"):
        multiline_comment = false
      elif multiline_comment or token.Token.contains("COMMENT"):
        pos.inc()
        continue

      if pos > 0:
        if LexerTokens[line][pos-1].Token.contains("COMMENT") or multiline_comment:
          LexerTokens[line][pos].Token = "COMMENT"

      # Keep useful tokens
      if token.Token != "SPACE" and token.Token != "DISCARDED" and not token.Token.contains("COMMENT"):
        fix.add(token)

      pos.inc()

    LexerTokens[line] = fix


proc Lex*(filename: string): Table[int, seq[TOKEN]]=
  # Instance Variables
  var ReturnTokens = initTable[int, seq[TOKEN]]()

  # Checking if file exist
  if fileExists(filename):
    let lines = readFile(filename).splitLines()
    Tokenize(lines)
  else:
    throwError("FILE_DNE", 0, @[filename])

  # Adjusting tokens
  Adjust()

  # Finalizing lexing
  for line in 0..<LexerTokens.len:
    var pos = 0
    for i,token in LexerTokens[line]:

      case token.Token
      # Global keyword
      of "GLOBAL":
        let old_token = expect(@["TBD"], LexerTokens, line, pos).Value
        LexerTokens[line][pos+1].Token = "@G_" & old_token
        LexerTokens[line][pos] = DISCARDED
      
      # Defining Variables
      of "VAR_DEFINE":
        if pos - 1 < 0 or pos == 0:
          throwError("NAME_EXPECTED", line, @[token.Value])

        let old_token = LexerTokens[line][pos-1].Token
        if old_token != "TBD" and not old_token.contains("VAR") and not old_token.contains("@G_"):
          echo old_token, ": ", LexerTokens[line][pos-1].Value
          throwError("NAME_EXPECTED", line, @[token.Value])

        discard expect(@["VAR_CALL", "STR", "O_BRACE", "NUM", "PERIOD"], LexerTokens, line, pos, "VALUE_EXPECTED")
        LexerTokens[line][pos-1].Token = "$" & old_token.findAll(re"\@G_").join("") & "VAR"

      # Reassigning Variables
      of "EQU":
        if pos - 1 < 0 or pos == 0:
          throwError("NAME_EXPECTED", line, @[token.Value])

        let old_token = LexerTokens[line][pos-1]
        if old_token.Token != "VAR_CALL":
          throwError("NAME_EXPECTED", line, @[token.Value])
        
        discard expect(@["VAR_CALL", "STR", "O_BRACE", "NUM", "PERIOD"], LexerTokens, line, pos, "VALUE_EXPECTED")

      # Period (function calls, floats)
      of "PERIOD":
        if pos - 1 < 0 or pos == 0:
          discard expect(@["TBD"], LexerTokens, line, pos)
          LexerTokens[line][pos].Token = DISCARDED
          LexerTokens[line][pos+1].Token = "PROC_CALL"
        else:
          let prev_token = expect(@["VAR_DEFINE", "NUM", "COMMA", "O_BRACE", "CONCAT", "EQU"], LexerTokens, line, pos-2, "VALUE_EXPECTED")
          let next_token = expect(@["TBD", "NUM"], LexerTokens, line, pos, "VALUE_EXPECTED")

          # Floats (eg. 3.14)
          if prev_token.Token == "NUM" and next_token.Token != "NUM":
            throwError("SYNTAX_ERROR", line, @[token.Value, "invalid integer: " & next_token.Value, "<integer> `" & token.Value & "`", "integer", ""])
          else:
            LexerTokens[line][pos-1].Value = prev_token.Value & token.Value & next_token.Value
            LexerTokens[line][pos] = DISCARDED
            LexerTokens[line][pos+1] = DISCARDED

          # Function calls (eg. .main)
          if prev_token.Token != "NUM" and next_token.Token == "TBD":
            LexerTokens[line][pos].Token = DISCARDED
            LexerTokens[line][pos+1].Token = "PROC_CALL"

      # Calls (->)
      of "CALLS":
        if pos - 1 < 0 or pos == 0:
          throwError("NAME_EXPECTED", line, @[token.Value])
        else:
          let prev_token = LexerTokens[line][pos-1]
          let next_token = LexerTokens[line][pos+1]
          # Lefthand Side:
          if prev_token.Token != "TBD" and not prev_token.Token.contains("@G_"):
            echo prev_token.Token, ": ", prev_token.Value
            throwError("NAME_EXPECTED", line, @[token.Value, prev_token.Value])
          else:
            LexerTokens[line][pos-1].Token = "$" & prev_token.Token.findAll(re"\@G_").join("") & "VAR"

          if next_token.Token != "UNFOLD":
            throwError("SYNTAX_ERROR", line, @[token.Value, "& expected after '" & token.Value & "': got " & next_token.Value, "`" & token.Value & "` &", "folded_function_name", ""])

      # Unfold (&)
      of "UNFOLD":
        let next_token = expect(@["TBD", "PROC"], LexerTokens, line, pos)
        if LexerTokens[line][pos+1].Token.contains("STMT"):
          LexerTokens[line][pos+1].Token = "%UNFOLD_" & next_token.Token.findAll(re"\STMT.+").join("")
        else:
          LexerTokens[line][pos+1].Token = "%UNFOLD_STMT"

      # Variable Calling
      of "VAR_CALL":
        discard expect(@["TBD"], LexerTokens, line, pos)
        LexerTokens[line][pos+1].Token = token.Token
        LexerTokens[line][pos] = DISCARDED

      # TODO:
      of "SUB_VAR_CALL":
        discard expect(@["TBD","STR","NUM", "PROC"], LexerTokens, line, pos, "VALUE_EXPECTED")
        throwWarning("TODO\n|> Implement check(s) for '" & token.Token & "'")
        #quit()

      pos.inc()

  # Cleaning Lexer Table
  for line in 0..<LexerTokens.len:
    var pos = 0
    ReturnTokens[line] = @[]
    for token in LexerTokens[line]:
      if token.Token != "DISCARDED":
        ReturnTokens[line].add(LexerTokens[line][pos])
      pos.inc()

  return ReturnTokens

