# This module
# contains the main entry functions for tokenizing, parsing, and compiling
# source into compiled code.

fs               = require 'fs'
path             = require 'path'
{Lexer,RESERVED} = require './lexer'
{parser}         = require './parser'
vm               = require 'vm'

# The current version number.
exports.VERSION = '0.0.0'

# Words that cannot be used as identifiers
exports.RESERVED = RESERVED

# Compile a string of code 
exports.compile = compile = (code, options = {}) ->
  try
    dasm = something compileToIntermediate(code, options)
  catch err
    err.message = "In #{options.filename}, #{err.message}" if options.filename
    throw err
  header = "Generated by swark #{@VERSION}"
  "; #{header}\n\n#{dasm}"

# Tokenize a string of code, and return the array of tokens.
exports.tokenize = tokenize = (code, options) ->
  lexer.tokenize code, options

# Parse a string of code, and return the AST.
exports.parse = parse = (source, options) ->
  parser.parse tokenize source, options

# Compile a string of code to intermediate instructions.
exports.compileToIntermediate = compileToIntermediate = (source, options) ->
  parse(source, options).compileToIntermediate()

# Compile and evaluate a string of code (in a Node.js-like environment).
# The REPL uses this to run the input.
exports.eval = (code, options = {}) ->
  return unless code = code.trim()
  Script = vm.Script
  if Script
    if options.sandbox?
      if options.sandbox instanceof Script.createContext().constructor
        sandbox = options.sandbox
      else
        sandbox = Script.createContext()
        sandbox[k] = v for own k, v of options.sandbox
      sandbox.global = sandbox.root = sandbox.GLOBAL = sandbox
    else
      sandbox = global
    sandbox.__filename = options.filename || 'eval'
    sandbox.__dirname  = path.dirname sandbox.__filename
    # define module/require only if they chose not to specify their own
    unless sandbox isnt global or sandbox.module or sandbox.require
      Module = require 'module'
      sandbox.module  = _module  = new Module(options.modulename || 'eval')
      sandbox.require = _require = (path) ->  Module._load path, _module, true
      _module.filename = sandbox.__filename
      _require[r] = require[r] for r in Object.getOwnPropertyNames require when r isnt 'paths'
      # use the same hack node currently uses for their own REPL
      _require.paths = _module.paths = Module._nodeModulePaths process.cwd()
      _require.resolve = (request) -> Module._resolveFilename request, _module
  o = {}
  o[k] = v for own k, v of options
  js = compile code, o
  if sandbox is global
    vm.runInThisContext js
  else
    vm.runInContext js, sandbox

# Instantiate a Lexer for our use here.
lexer = new Lexer

# The real Lexer produces a generic stream of tokens. This object provides a
# thin wrapper around it, compatible with the Jison API. We can then pass it
# directly as a "Jison lexer".
parser.lexer =
  lex: ->
    [tag, @yytext, @yylineno] = @tokens[@pos++] or ['']
    tag
  setInput: (@tokens) ->
    @pos = 0
  upcomingInput: ->
    ""

parser.yy = require './nodes'
