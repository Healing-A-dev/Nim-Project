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
  if len(token) == 1 and token != ".":
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
          throwError("UNFINISHED_STRING", line, @[buffer.join("")])
        else:
          fix.add((Token: "STR", Value: buffer.join(""), isToken: true, isStatement: false))
          LexerTokens[line][pos+skipper] = DISCARDED
          pos += skipper+1
          continue

      # Comments
      if token.Token.contains("COMMENT_START"):
        multiline_comment = true
      elif token.Token.contains("COMMENT_END"):
        multiline_comment = false
      elif multiline_comment or token.Token.contains("COMMENT"):
        pos.inc()
        continue

      # Keep useful tokens
      if token.Token != "SPACE" and token.Token != "DISCARDED" and not token.Token.contains("COMMENT"):
        fix.add(token)

      pos.inc()

    LexerTokens[line] = fix


proc Lex*(filename: string): Table[int, seq[TOKEN]]=
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
        discard expect(@["TBD"], LexerTokens, line, pos).Value
        LexerTokens[line][pos+1].Token = "GLOBAL_VAR"
      
      # Defining Variables
      of "VAR_DEFINE":
        discard expect(@["TBD", "STR"], LexerTokens, line, pos, "VALUE_EXPECTED")
        let old_tk_value = LexerTokens[line][pos-1].Token
        LexerTokens[line][pos-1].Token = "$" & old_tk_value

      of "UNFOLD", "VAR_CALL", "SUB_VAR_CALL", "CALLS":
        discard expect(@["TBD","STR","NUM"], LexerTokens, line, pos, "VALUE_EXPECTED")
        throwWarning("TODO\n|> Implement check(s) for '" & token.Token & "'")
      

      pos.inc()

  return LexerTokens

