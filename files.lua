
local M = {}

-- TODO: The standard specifies that if the file-access wordset is defined, the block wordset shall
-- be too. But the block one is archaic and not strictly required for this, so I'm going to skip it for
-- now and focus on the code for file access instead.
--
-- New file access design:
--
-- The Forth word set and CC filesystem implementation have a serious impedance mismatch.
-- CC just doesn't support enough flexibility for me to follow the Forth standard.
-- Therefore, I will have to read the whole contents of files into the Lua memory and process them
-- there, instead of making calls directly to the Lua API.
--
-- So what do I need to do in order to support that? Each file needs to know its:
-- - name
-- - contents
-- - cursor position
-- - mode (to reject reads/writes appropriately)

M.defineFileLibrary = function(forth)
  forth:defineNative('bin', false, function(f) f:push(f:pop() + 8) end)
  forth:defineNative('r/o', false, function(f) f:push(F_READ) end)
  forth:defineNative('r/w', false, function(f) f:push(F_READ + F_WRITE) end)
  forth:defineNative('w/o', false, function(f) f:push(F_WRITE) end)

  forth:defineNative('close-file', false, function(f)
    local id = f:pop()
    local file = f.files[id]
    file:close()
  end)

  forth:defineNative('create-file', false, function(f)
    local access = f:pop()
    local filename = f:fromBufferStack()

    -- First we delete it if it exists, then open it in the requested mode.
    if fs.exists(filename) then fs.delete(filename) end

    local fileid = f:openFile(filename, access)

    if fileid then
      f:push(fileid)
      f:push(0) -- ior success
    else
      f:push(1) -- general purpose file error
    end
  end)

  forth:defineNative('open-file', false, function(f)
    local access = f:pop()
    local filename = f:fromBufferStack()
    local fileid = f:openFile(filename, access)
    if fileid then
      f:push(fileid)
      f:push(0)
    else
      f:push(1) -- general file error
    end
  end)

  forth:defineNative('delete-file', false, function(f)
    local filename = f:fromBufferStack()
    fs.delete(filename)
    f:push(0) -- always succeeds
  end)

  forth:defineNative('file-position', false, function(f)
    local fileid = f:pop()
    local file = f.files[fileid]
    if file then
      f:push(file.pos)
      f:push(0)
    else
      f:push(0)
      f:push(1)
    end
  end)

  forth:defineNative('file-size', false, function(f)
    local fileid = f:pop()
    local file = f.files[fileid]
    if file then
      f:push(file.contents:len())
      f:push(0)
    else
      f:push(0)
      f:push(1) -- general file error
    end
  end)


  -- Accepts either a fileid or a filename string.
  local includeFile = function(f, filespec)
    f.inputSources[1]:save(f)
    f.mem[f.posAddr] = f.inputBufferTop -- Fake having finished with the old buffer.
    table.insert(f.inputSources, 1, FileInputSource:new(f, filespec))
  end

  forth:defineNative('include-file', false, function(f) includeFile(f, f:pop()) end)
  forth:defineNative('included', false, function(f) includeFile(f, f:fromBufferStack()) end)

  forth:defineNative('read-file', false, function(f)
    local fileid = f:pop()
    local len = f:pop()
    local buf = f:pop()

    local file = f.files[fileid]
    if not file then
      f:push(0)
      f:push(1) -- general file error
      return
    end

    -- Sequentially read the characters, bumping the position.
    -- If we run out of file, we exit early.
    local read = 0
    local fileLen = file.contents:len()
    while read < len and file.pos < fileLen do -- NB: file.pos is 0-based.
      -- Read a byte
      local c = file.contents:byte(file.pos+1)
      f.mem[buf+read] = c
      file.pos = file.pos + 1
      read = read + 1
    end

    f:push(read)
    f:push(0)
  end)

  forth:defineNative('read-line', false, function(f)
    local fileid = f:pop()
    local len = f:pop()
    local buf = f:pop()

    local file = f.files[fileid]
    if not file then
      f:push(0)
      f:push(0)
      f:push(1)
      return
    end

    local line = file:readLine(len)

    -- copy it into the buffer
    local lineLen = line:len()
    for i = 1, lineLen do
      local c = line:byte(i)
      f.mem[buf + i - 1] = c
    end

    f:push(lineLen)
    f:push(lineLen == len and 0 or -1)
    f:push(0)
  end)

  forth:defineNative('reposition-file', false, function(f)
    local fileid = f:pop()
    local pos = f:pop()
    local file = f.files[fileid]
    if not file then
      f:push(1)
    else
      file.pos = pos
      f:push(0)
    end
  end)

  forth:defineNative('resize-file', false, function(f)
    local fileid = f:pop()
    local newSize = f:pop()
    local file = f.files[fileid]

    if not file then
      f:push(1)
      return
    end

    -- pos is specified to be undefined after this operation; I always set it to 0.
    file.pos = 0

    -- If the file is being shrunk, just substring its contents.
    if newSize < file.contents:len() then
      file.contents = file.contents:sub(1, newSize)
    else -- And if it's being enlarged, just pad it out with spaces.
      file.contents = file.contents .. string.rep(' ', newSize - file.contents:len())
    end

    f:push(0)
  end)

  local writer = function(ending)
    return function(f)
      local fileid = f:pop()
      local s = f:fromBufferStack() .. ending
      local file = f.files[fileid]
      if not file then
        f:push(1) -- general error
        return
      end

      -- Pull apart the contents and splice in this chunk.
      local oldLen = file.contents:len()
      local chunkLen = s:len()
      local prefixEnd = file.pos -- file.pos is 0-based so this is correct
      local suffixStart = file.pos + chunkLen + 1 -- likewise, this +1 is necessary on this end
      file.contents = file.contents:sub(1, file.pos) .. s .. (prefixEnd + chunkLen < oldLen and file.contents:sub(suffixEnd) or '')
      f:push(0)
    end
  end

  forth:defineNative('write-file', false, writer(''))
  forth:defineNative('write-line', false, writer('\n'))


end

return M
