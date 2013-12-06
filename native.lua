
local M = {}
M.defineStandardLibrary = function(forth)
  forth:defineNative('drop', false, function(f) f.dsp = f.dsp + 1 end)
  forth:defineNative('swap', false, function(f)
    local a = f:pop()
    local b = f:pop()
    f:push(a)
    f:push(b)
  end)
  forth:defineNative('dup', false, function(f) f:push(f:peek()) end)
  forth:defineNative('over', false, function(f) f:push(f.mem[f.dsp+1]) end)
  forth:defineNative('rot', false, function(f)
    local a = f:pop()
    local b = f:pop()
    local c = f:pop()
    -- ( c b a -- b a c ) (grab)
    f:push(b)
    f:push(a)
    f:push(c)
  end)
  forth:defineNative('-rot', false, function(f)
    local a = f:pop()
    local b = f:pop()
    local c = f:pop()
    -- ( c b a -- a c b ) (bury)
    f:push(a)
    f:push(c)
    f:push(b)
  end)

  forth:defineNative('2drop', false, function(f) f:pop(); f:pop() end)
  forth:defineNative('2dup', false, function(f)
    local a = f.mem[f.dsp]
    local b = f.mem[f.dsp+1]
    -- ( b a -- b a b a )
    f:push(b)
    f:push(a)
  end)

  forth:defineNative('2swap', false, function(f)
    local a = f:pop()
    local b = f:pop()
    local x = f:pop()
    local y = f:pop()
    -- ( y x b a -- b a y x )
    f:push(b)
    f:push(a)
    f:push(y)
    f:push(x)
  end)

  forth:defineNative('2over', false, function(f)
    local x = f.mem[f.dsp]
    local y = f.mem[f.dsp+1]
    -- ( y x b a -- y x b a y x )
    f:push(y)
    f:push(x)
  end)

  forth:defineNative('?dup', false, function(f)
    local x = f:peek()
    if x ~= 0 then f:push(x) end
  end)

  forth:defineNative('1+', false, function(f) f:push(f:pop()+1) end)
  forth:defineNative('1-', false, function(f) f:push(f:pop()-1) end)

  forth:defineNative('+', false, function(f) f:push(f:pop() + f:pop()) end)
  forth:defineNative('-', false, function(f)
    local b = f:pop()
    local a = f:pop()
    -- Deeper on the stack (a) minus shallower (b).
    f:push(a-b)
  end)

  forth:defineNative('*', false, function(f) f:push(f:pop() * f:pop()) end)
  forth:defineNative('sm/rem', false, function(f)
    local divisor = f:pop()
    local dividend = f:pop2()
    local fQuotient = dividend / divisor
    local iQuotient = fQuotient > 0 and math.floor(fQuotient) or math.ceil(fQuotient)

    local remainder = dividend - iQuotient * divisor
    f:push(remainder)
    f:push(iQuotient)
  end)

  forth:defineNative('fm/mod', false, function(f)
    local divisor = f:pop()
    local dividend = f:pop2()
    local quotient = math.floor(dividend / divisor)
    local remainder = dividend - quotient * divisor
    f:push(remainder)
    f:push(quotient)
  end)


  local compOp = function(op)
    return function(f)
      local b = f:pop()
      local a = f:pop()
      f:push(op(a,b) and -1 or 0)
    end
  end

  forth:defineNative('=', false, compOp(function(a,b) return a == b end))
  forth:defineNative('<>', false, compOp(function(a,b) return a ~= b end))
  forth:defineNative('>', false, compOp(function(a,b) return a > b end))
  forth:defineNative('<', false, compOp(function(a,b) return a < b end))
  forth:defineNative('>=', false, compOp(function(a,b) return a >= b end))
  forth:defineNative('<=', false, compOp(function(a,b) return a <= b end))


  local compOpZero = function(op)
    return function(f)
      local a = f:pop()
      f:push(op(a) and -1 or 0)
    end
  end

  forth:defineNative('0=', false, compOpZero(function(a) return a == 0 end))
  forth:defineNative('0<>', false, compOpZero(function(a) return a ~= 0 end))
  forth:defineNative('0<', false, compOpZero(function(a) return a < 0 end))
  forth:defineNative('0>', false, compOpZero(function(a) return a > 0 end))
  forth:defineNative('0<=', false, compOpZero(function(a) return a <= 0 end))
  forth:defineNative('0>=', false, compOpZero(function(a) return a >= 0 end))

  forth:defineNative('exit', false, function(f) f.nextWord = f:popRSP() end)
  forth:defineNative('lit', false, function(f)
    f:push(f.mem[f.nextWord])
    f.nextWord = f.nextWord + 1
  end)

  forth:defineNative('!', false, function(f)
    local addr = f:pop()
    local val  = f:pop()
    f.mem[addr] = val
  end)

  forth:defineNative('@', false, function(f) f:push(f.mem[f:pop()]) end)

  forth:defineNative('+!', false, function(f)
    local addr = f:pop()
    local delta = f:pop()
    f.mem[addr] = f.mem[addr] + delta
  end)

  forth:defineNative('source', false, function(f)
    f:push(f.inputBuffer)
    f:push(f.inputBufferTop - f.inputBuffer)
  end)

  forth:defineNative('source-id', false, function(f)
    -- Returns 0 when the input source is the keyboard, -1 for EVALUATE strings, and a fileid otherwise.
    local source = f.inputSources[1]
    if source.type == 'file' then
      f:push(source.fileid)
    elseif source.type == 'evaluate' then
      f:push(-1)
    else
      f:push(0) -- Keyboard or other.
    end
  end)

  forth:defineNative('abs', false, function(f) f:push(math.abs(f:pop())) end)

  forth:defineNative('state', false, function(f) f:push(f.stateAddr) end)
  forth:defineNative('latest', false, function(f) f:push(f.latestAddr) end)
  forth:defineNative('here', false, function(f) f:push(f.hereAddr) end)
  forth:defineNative('s0', false, function(f) f:push(f.DSP_TOP) end)
  forth:defineNative('base', false, function(f) f:push(f.baseAddr) end)
  forth:defineNative('version', false, function(f) f:push(1) end)
  forth:defineNative('r0', false, function(f) f:push(f.MEM_TOP) end)
  forth:defineNative('>r', false, function(f) f:pushRSP(f:pop()) end)
  forth:defineNative('r>', false, function(f) f:push(f:popRSP()) end)
  forth:defineNative('rsp@', false, function(f) f:push(f.rsp) end)
  forth:defineNative('rsp!', false, function(f) f.rsp = f:pop() end)
  forth:defineNative('rdrop', false, function(f) f:popRSP() end)
  forth:defineNative('dsp@', false, function(f) f:push(f.dsp) end)
  forth:defineNative('dsp!', false, function(f) f.dsp = f:pop() end)
  forth:defineNative('>in', false, function(f) f:push(f.posAddr) end)
  forth:defineNative('>inbuf', false, function(f) f:push(f.inputBuffer) end)
  forth:defineNative('>in+', false, function(f) f.mem[f.posAddr] = f.mem[f.posAddr] + 1 end)
  forth:defineNative('refill', false, function(f) f:refill() end)

  forth:defineNative('key', false, function(f)
    local c = f.mem[f.inputBuffer + f.mem[f.posAddr]]
    f:push(c)
    f.mem[f.posAddr] = f.mem[f.posAddr] + 1
  end)

  forth:defineNative('parse', false, function(f)
    local delimiter = f:pop()
    local start = f.inputBuffer + f.mem[f.posAddr]
    for i = start, f.inputBufferTop-1 do
      if f.mem[i] == delimiter then
        f:push(start)
        f:push(i-start)
        f.mem[f.posAddr] = i + 1
        return
      end
    end

    f:push(start)
    f:push(f.inputBufferTop - start)
    f.mem[f.posAddr] = f.inputBufferTop
  end)


  local isDelimiter = function(delim, c)
    if delim ~= -1 then
      return delim == c
    else
      return c == 32 or c == 9 or c == 13  -- space, tab, CR
    end
  end

  local parseDelimited = function(f, delimiter)
    local i = f.inputBuffer + f.mem[f.posAddr]
    while isDelimiter(delimiter, f.mem[i]) do
      i = i + 1
    end

    local start = i
    while i < f.inputBufferTop do
      if isDelimiter(delimiter, f.mem[i]) then
        f:push(start)
        f:push(i-start)
        f.mem[f.posAddr] = i - f.inputBuffer + 1
        return
      end
      i = i + 1
    end

    f:push(start)
    f:push(f.inputBufferTop - start)
    f.mem[f.posAddr] = f.inputBufferTop
  end

  forth:defineNative('parse-delim', false, function(f) parseDelimited(f, f:pop()) end)
  forth:defineNative('parse-name', false, function(f) parseDelimited(f, -1) end) -- -1 is the magic whitespace delimiter

  forth:defineNative('emit', false, function(f)
    --print('Inside emit')
    io.write(string.format('%c', f:pop()))
  end)
  forth:defineNative('find', false, function(f)
    local s = f:fromBufferStack()
    f:push(f:lookup(s))
  end)

  forth:defineNative('create', false, function(f)
    local s = f:fromBufferStack()
    local here = f.mem[f.hereAddr]
    f.mem[f.latestAddr] = here -- Move HERE to the new word
    local w = f:defineForth(s, false, here)
    w.hidden = true
  end)

  forth:defineNative(',', false, function(f) f:putHere(f:pop()) end)
  forth:defineNative('[', true, function(f) f.mem[f.stateAddr] = 0 end) -- state 0, interpreting
  forth:defineNative(']', false, function(f) f.mem[f.stateAddr] = 1 end) -- state 1, compiling
  forth:defineNative('immediate', true, function(f)
    local latest = f.mem[f.latestAddr]
    local w = f.words[latest]
    w.immediate = not w.immediate
  end)

  forth:defineNative('hidden', false, function(f)
    local addr = f:pop()
    local w = f.words[addr]
    w.hidden = not w.hidden
  end)

  forth:defineForthWords(':', false, {
    'parse-name',
    'create',
    ']',
    'exit'
  })

  forth:defineForthWords(';', true, {
    'lit',
    'exit',
    ',',
    '[',
    'latest',
    '@',
    'hidden',
    'exit'
  })

  forth:defineNative("'", false, function(f)
    local nxt = f.mem[f.nextWord]
    f.nextWord = f.nextWord + 1
    f:push(nxt)
  end)

  forth:defineNative('branch', false, function(f)
    local offset = f.mem[f.nextWord]
    f.nextWord = f.nextWord + offset
  end)

  forth:defineNative('0branch', false, function(f)
    local flag = f:pop()
    if flag == 0 then
      local offset = f.mem[f.nextWord]
      f.nextWord = f.nextWord + offset
    else
      f.nextWord = f.nextWord + 1
    end
  end)

  forth:defineNative('litstring', false, function(f)
    local len = f.mem[f.nextWord]
    f.nextWord = f.nextWord + 1
    f:push(f.nextWord)
    f:push(len)
    f.nextWord = f.nextWord + len
  end)

  forth:defineNative('type', false, function(f)
    local s = f:fromBufferStack()
    io.write(s)
  end)

  forth:defineNative('\\', true, function(f) f:refill() end)


  -- TODO: Support #, $ and % prefixes, for one-off base selection.
  -- TODO: Support 'c' for arbitrary character literals.
  local parseNumber = function(f)
    local len = f:pop()
    local addr = f:pop()
    local orig = f:pop2()

    local negative = false
    local first = true
    local digit = -1

    while len > 0 do
      local c = f.mem[addr]
      if first and c == 43 then -- '+'
        -- Do nothing on a +
      elseif first and c == 45 then -- '-'
        negative = true
      elseif c >= 48 and c <= 57 then -- '0' to '9'
        digit = c - 48
      elseif c >= 65 and c <= 90 then -- 'A' to 'Z'
        digit = c - 55 -- A = 10
      elseif c >= 97 and c <= 122 then -- 'a' to 'z'
        digit = c - 87 -- a = 10
      else
        break
      end

      first = false
      if digit >= f.mem[f.baseAddr] then break end

      if digit >= 0 then
        -- If we made it here, multiply orig by base and add digit
        orig = orig * f.mem[f.baseAddr] + digit
      end

      addr = addr + 1
      len = len - 1
    end

    f:push2(negative and -orig or orig)
    f:push(addr)
    f:push(len)
  end

  forth:defineNative('>number', false, parseNumber)
  forth:defineNative('interpret', false, function(f)
    -- Check that there's still something to read.
    local len = 0
    local buf = 0
    while len <= 0 do
      if f.mem[f.posAddr] >= f.inputBufferTop - f.inputBuffer then f:refill() end

      parseDelimited(f, -1)
      len = f:pop()
      buf = f:pop()
    end

    --print('Interpreting: found word length ' .. len .. ' at ' .. buf)
    local s = f:fromBuffer(buf, len)
    local addr = f:lookup(s)

    if addr ~= 0 then
      local w = f.words[addr]
      --print('Executing ' .. w.name)
      if w.immediate or f.mem[f.stateAddr] == 0 then
        --print('Immediately')
        f:execute(addr)
      else
        --print('Compiling')
        f:putHere(addr)
      end
    else
      -- Not found, so parse as a number.
      f:push2(0)
      f:push(buf)
      f:push(len)
      parseNumber(f)
      -- Now the new value, new address and length are left on the stack.
      -- If the remaining character count is anything other than 0, fail out.
      local remainingLen = f:pop()
      if remainingLen == 0 then
        --print('Parsed as a number')
        -- success
        f:pop() -- skip the address
        local val = f:pop2()
        if f.mem[f.stateAddr] == 0 then -- interpreting, push the value
          f:push(val)
        else
          f.mem[f.mem[f.hereAddr]] = f:lookup('lit')
          f.mem[f.mem[f.hereAddr]+1] = val
          f.mem[f.hereAddr] = f.mem[f.hereAddr] + 2
        end
      else
        print('Unknown word: "' .. s .. '"')
      end
    end
  end)


  forth:defineForthWords('quit', false, {
    'r0',
    'rsp!',
    'interpret',
    'branch'
  })
  -- Now hack in an extra value at HERE. It's the offset for the BRANCH above.
  forth:putHere(-2)

  forth:defineNative('char', false, function(f)
    parseDeliminted(f, -1)
    f:pop()
    local buf = f:pop()
    f:push(f.mem[buf])
  end)

  forth:defineNative('execute', false, function(f)
    -- Get the execution token, which is a pointer, off the stack.
    local addr = f:pop()
    --print('Execute: ' .. addr)
    f.nextWord = addr
  end)

  forth:defineNative('evaluate', false, function(f)
    local s = f:fromBufferStack()
    f.inputSources[1]:save(f)
    f.mem[f.posAddr] = f.inputBufferTop -- Fake having finished with the old buffer.
    table.insert(f.inputSources, 1, EvaluateInputSource:new(s))
  end)

  forth:defineNative('environment?', false, function(f)
    local s = f:fromBufferStack()

    if s == '/COUNTED-STRING' then
      f:push(1000000)
    elseif s == '/HOLD' then
      -- TODO: Correct me when pictorial output is implemented.
      f:push(0)
      return
    elseif s == '/PAD' then
      -- TODO: Update me when the PAD exists.
      f:push(0)
      return
    elseif s == '/ADDRESS-UNIT-BITS' then
      f:push(51)
    elseif s == 'FLOORED' then
      f:push(0)
    elseif s == 'MAX-CHAR' then
      f:push(127)
    elseif s == 'MAX-D' then
      f:push(2.2517998e+15)
    elseif s == 'MAX-N' then
      f:push(2.2517998e+15)
    elseif s == 'MAX-U' then
      f:push(2.2517998e+15)
    elseif s == 'MAX-UD' then
      f:push(2.2517998e+15)
    elseif s == 'RETURN-STACK-CELLS' then
      f:push(1024)
    elseif s == 'STACK-CELLS' then
      f:push(16384)
    else
      f:push(0)
      return
    end

    f:push(-1) -- True flag for successfully recognized values.
  end)


  forth:defineNative('(strbuf)', false, function(f) f:push(f.stringBuffer) end)

  --[[
  -- converts a number to a 52-entry table.
  -- NB: LEAST significant bit comes first
  local toBits = function(x)
    local rounded = x < 0 and math.ceil(x) or math.floor(x) -- rounding toward 0
    local bits = {}
    for i = 0, 51 do
      local b = rounded / (2^i)
      table.insert(bits, b % 2 == 1)
    end
    return bits
  end

  local fromBits = function(bits)
    local n = 0;
    for i, b in ipairs(bits) do
      if b then n = n + 2^(i-1) end
    end
  end

  local bitwiseBinOp = function(op)
    return function(f)
      local b = toBits(f:pop())
      local a = toBits(f:pop())
      local out = {}
      for i = 1, 52 do
        out[i] = op(a[i], b[i])
      end
      f:push(fromBits(out))
    end
  end

  forth.defineNative('and', false, bitwiseBinOp(function(a,b) return a and b end))
  forth.defineNative('xor', false, bitwiseBinOp(function(a,b) return a ~=  b end))
  forth.defineNative('or', false,  bitwiseBinOp(function(a,b) return a or  b end))
  --]]

end

return M

-- TODO: Implement these in Forth, later: (easy, then hard, then maybe)
-- - -!
----------------------
-- - lshift and rshift
-- and, or, xor, invert
------------------------
-- - u<, um*, um/mod, */, */mod, m*
-- - s>d, d>s

