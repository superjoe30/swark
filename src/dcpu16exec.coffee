dcpu16 = require("dcpu16")

exports.runAssembly = (asm_code) ->
  cpu = new dcpu16.CPU()

  # stdin/stdout
  cpu.mapDevice 0x8fff, 1, do ->
    buffer = ""
    already_listening = false
    listen = ->
      return if already_listening
      already_listening = true
      stdin = process.openStdin()
      stdin.on 'data', (buf) -> buffer += buf
    return {} =
      get: ->
        listen()
        result = buffer.charCodeAt(0) or 0x0000
        buffer = buffer.substr(1)
        result
      set: (index, value) ->
        process.stdout.write String.fromCharCode(value)

  # write anything here to kill the program
  return_code = 1
  cpu.mapDevice 0x8ffe, 1,
    set: (index, value) ->
      return_code = value
      cpu.stop()

  assembler = new dcpu16.Assembler(cpu)
  try
    assembler.compile asm_code
  catch err
    process.stderr.write "#{err}\n"
    process.exit 1

  cpu.run()
  process.exit return_code
