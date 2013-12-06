-- ForthCraft - A Forth implementation for ComputerCraft.
-- This is written on top of the existing Lua APIs in ComputerCraft, and so requires
-- that they remain on the system undisturbed.
-- This script is intended to be loaded at boot time by the CC terminal, and to replace
-- the existing terminal environment completely.
--
-- The /rom/forth directory holds Forth libraries to be loaded at startup.

-- A Forth table holds all the necessary data for the Forth system.
-- There's likely to be only one of these globally, but the separation is still a good idea.

Forth = {}

function Forth:new(imports)
  local newObj = {}
  newObj.MEM_TOP = 0x10000
  newObj.DSP_TOP = newObj.MEM_TOP - 1024
  newObj.NEXT_VAR = 1

  newObj.nextWord = nil
  newObj.rsp = newObj.MEM_TOP
  newObj.dsp = newObj.DSP_TOP

  newObj.mem = {}
  newObj.dict = {}
  newObj.words = {}

  newObj.interpWord = nil

  newObj.stateAddr = 2
  newObj.latestAddr = 3
  newObj.baseAddr = 4
  newObj.hereAddr = 5
  newObj.wordBuffer = 6
  newObj.posAddr = 7
  newObj.inputBuffer = 10
  newObj.inputBufferTop = 256
  newObj.nextNative = newObj.MEM_TOP

  newObj.files = {}
  newObj.fileNames = {}
  newObj.nextFile = 1
  newObj.inputSources = {}

  self.__index = self
  setmetatable(newObj, self)

  for i, file in ipairs(imports) do
    table.insert(newObj.inputSources, FileInputSource:new(newObj, file))
  end
  table.insert(newObj.inputSources, KeyboardInputSource:new())

  return newObj
end

function Forth:start()
  self.mem[self.stateAddr] = 0
  self.mem[self.latestAddr] = 0
  self.mem[self.baseAddr] = 10
  self.mem[self.hereAddr] = self.inputBufferTop
  self.mem[self.posAddr] = self.inputBufferTop

  require('native').defineStandardLibrary(self)
  self:interpreter()
end

function Forth:interpreter()
  -- Start things off by calling QUIT, which will reset the return stack,
  -- and then repeatedly call INTERPRET.
  self.mem[self.NEXT_VAR] = self.dict.quit[1]
  self.nextWord = self.NEXT_VAR

  while(true) do
    local addr = self.mem[self.nextWord]
    self.nextWord = self.nextWord + 1
    self:execute(addr)
  end
end

-- Words are tables with the following keys:
-- type: either 'native' or 'forth'
-- name: a string
-- immediate: boolean, true if this is an immediate word
-- hidden: boolean, true if this word is hidden.
-- code:
--     - native: a function to execute that takes a Forth object and returns nothing.
--     - forth:  the address of the first word to execute in memory.
function Forth:defineNative(name, immediate, code)
  local w = { type = 'native', name = name, immediate = immediate, hidden = false, code = code }
  self.words[self.nextNative] = w
  self.dict[name] = { self.nextNative }
  self.nextNative = self.nextNative + 1
  return w
end

function Forth:defineForth(name, immediate, code)
  local w = { type = 'forth', name = name, immediate = immediate, hidden = false, code = code }
  self.words[self.mem[self.hereAddr]] = w
  if self.dict[name] == nil then
    self.dict[name] = {}
  end

  -- insert the new definition at the start of the list
  table.insert(self.dict[name], 1, self.mem[self.hereAddr])
  return w
end

function Forth:defineForthWords(name, immediate, words)
  local code = self.mem[self.hereAddr]
  --print('Defining new word at ' .. code)
  self:defineForth(name, immediate, code)

  for i, w in ipairs(words) do
    local addr = self.dict[w][1]
    --print('storing ' .. addr .. ' at ' .. self.mem[self.hereAddr])
    self:putHere(addr)
  end
end

function Forth:peek()
  return self.mem[self.dsp]
end

function Forth:pop()
  local x = self.mem[self.dsp]
  self.dsp = self.dsp + 1
  return x
end

function Forth:push(x)
  if x == nil then error('pushed nil') end
  self.dsp = self.dsp - 1
  self.mem[self.dsp] = x
end

-- pop2 and push2 just ignore the second value. 64-bit doubles are plenty big enough for most purposes.
function Forth:pop2()
  self:pop()
  return self:pop()
end

function Forth:push2(x)
  self:push(x)
  self:push(0)
end

-- TODO: Skipped push2 and pop2; they are unlikely to be needed.

function Forth:popRSP()
  local x = self.mem[self.rsp]
  self.rsp = self.rsp + 1
  return x
end

function Forth:pushRSP(x)
  self.rsp = self.rsp - 1
  self.mem[self.rsp] = x
end



function Forth:fromBuffer(buf, len)
  local s = ''
  while len > 0 do
    s = s .. string.format("%c", self.mem[buf])
    buf = buf + 1
    len = len - 1
  end
  return s
end

function Forth:fromBufferStack()
  local len = self:pop()
  local buf = self:pop()
  return self:fromBuffer(buf, len)
end

function Forth:lookup(s)
  if self.dict[s] ~= nil then
    for i, addr in ipairs(self.dict[s]) do
      if not self.words[addr].hidden then return addr end
    end
  end

  return 0
end

function Forth:putHere(x)
  self.mem[self.mem[self.hereAddr]] = x
  self.mem[self.hereAddr] = self.mem[self.hereAddr] + 1
end

function Forth:refill()
  for i = self.inputBuffer, self.inputBufferTop-1 do
    self.mem[i] = 32
  end

  -- Attempt to read a line from the topmost item in the input source list.
  while #self.inputSources > 0 do
    if self.inputSources[1]:refill(self) then return end

    -- If not, pop the first source and try again.
    table.remove(self.inputSources, 1)
    if #self.inputSources and self.inputSources[1]:restore(self) then return end
  end

  print('Bye!')
  os.exit(0)
end


function Forth:execute(addr)
  local word = self.words[addr]
  --print(addr)
  --print(word)
  if not word then return end
  if word.type == 'native' then
    word.code(self)
  else
    self:pushRSP(self.nextWord)
    self.nextWord = word.code
    --print('Executing at ' .. word.code)
  end
end



FileInputSource = {}

function FileInputSource:new(f, filename)
  local newObj = {
    type = 'file',
    lastLine = nil,
    lineCount = 0,
    savedPosition = nil,
    saved = false
  }

  local file
  if type(filename) == 'string' then
    file = io.open(filename)
    f.files[f.nextFile] = file
    f.fileNames[f.nextFile] = filename
    newObj.fileid = f.nextFile
    f.nextFile = f.nextFile + 1
  else -- it's actually a fileid
    newObj.fileid = filename
    file = f.files[filename]
    filename = f.fileNames[newObj.fileid]
  end

  newObj.lines = file:lines()

  self.__index = self
  return setmetatable(newObj, self)
end

function FileInputSource:refill(f)
  -- Try to load a line from the file.
  local line = self.lines()
  if line == nil then return false end
  self.lastLine = line

  for i = 1, line:len() do
    f.mem[i - 1 + f.inputBuffer] = string.byte(line, i)
  end
  f.mem[f.posAddr] = 0
  self.lineCount = self.lineCount + 1
  return true
end

function FileInputSource:save(f)
  self.savedPosition = f.mem[f.posAddr]
  self.saved = true
end

function FileInputSource:restore(f)
  if not self.saved then return false end
  self.saved = false
  -- Just refull the same string again.
  for i = 1, self.lastLine:len() do
    f.mem[i - 1 + f.inputBuffer] = string.byte(self.lastLine, i)
  end
  f.mem[f.posAddr] = 0
end


KeyboardInputSource = {}

function KeyboardInputSource:new()
  local newObj = {
    type = 'keyboard',
    line = '',
    savedPosition = 0,
    saved = false
  }

  self.__index = self
  return setmetatable(newObj, self)
end

function KeyboardInputSource:refill(f)
  self.line = io.read()
  if self.line == nil then return false end

  for i = 1, self.line:len() do
    f.mem[f.inputBuffer + i - 1] = string.byte(self.line, i)
  end
  f.mem[f.posAddr] = 0
  return true
end

function KeyboardInputSource:save(f)
  self.savedPosition = f.mem[f.posAddr]
  self.saved = true
end

function KeyboardInputSource:restore(f)
  if not saved then return false end
  self.saved = false
  for i = 1, self.line:len() do
    f.mem[f.inputBuffer + i - 1] = string.byte(self.line, i)
  end

  f.mem[f.posAddr] = self.savedPosition
  return true
end


EvaluateInputSource = {}

function EvaluateInputSource:new(s)
  local newObj = {
    type = 'evaluate',
    content = s,
    savedPosition = 0,
    saved = true -- yes, default to true, because refill() calls restore()
  }
  self.__index = self
  return setmetadata(newObj, self)
end

function EvaluateInputSource:refill(f)
  if not saved then return false end
  self.savedPosition = 0
  self:restore(f)
  return true
end

function EvaluateInputSource:save(f)
  self.savedPosition = f.mem[f.posAddr]
  self.saved = true
end

function EvaluateInputSource:restore(f)
  if not self.saved then return false end
  self.saved = false
  for i = 1, self.content:len() do
    f.mem[f.inputBuffer + i - 1] = string.byte(self.content, i)
  end
  f.mem[f.posAddr] = self.savedPosition
  return true
end


-- main function

theForth = Forth:new(arg)
theForth:start()

