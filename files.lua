
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

  forth:defineNative('close-file', false, function(f)
    local id = f:pop()
    local file = f.files[id]
    file:close()
  end)

  -- The force* arguments are optional.
  local forthFileAccessorToCC = function(access, forceRead, forceWrite, forceBin)
    -- Forth file accessors are a bitfield: 1 = read, 2 = write, 8 = bin
    local read = forceRead or access % 2 == 1
    local write = forceWrite or (access / 2) % 2 == 1
    local bin = forceBin or (access / 8) % 2 == 1

    return (read and 'r' or '') .. (write and 'w' or '') .. (bin and 'b' or '')
  end

  forth:defineNative('create-file', false, function(f)
    local access = f:pop()
    local filename = f:fromBufferStack()
    -- Impedance mismatch on the modes here. The Forth requires the mode to be honoured,
    -- and that an existing file be recreated as an empty file.
    -- NB: Forth doesn't have "append" mode. So I'll always set W and we'll get the right behavior.
    local ccAccessor = forthFileAccessorToCC(access, false, true)
    local file = fs.open(filename, ccAccessor);
    if file then
      f:push(f.nextFile)
      f:push(0) -- ior success
      f.files[f.nextFile] = file
      f.fileNames[f.nextFile] = filename
      f.nextFile = f.nextFile + 1
    else
      f:push(1) -- general purpose file error
    end
  end)

  forth:defineNative('open-file', false, function(f)
    local access

    -- XXX: CC's fs.open access modes don't allow this flow at all.
    -- I'm going to have to rewire this implementation to do everything in Lua's RAM,
    -- simulating the Forth calls and writing out on close.
  end)

  forth:defineNative('delete-file', false, function(f)
    local filename = f:fromBufferStack()
    fs.delete(filename)
    f:push(0) -- always succeeds
  end)

  -- XXX: Deviates from the spec: CC doesn't track file position. Just pushed 0 and ior of 1 every time.
  forth:defineNative('file-position', false, function(f)
    local fileid = f:pop()
    f:push(0)
    f:push(1)
  end)

  forth:defineNative('file-size', false, function(f)
    -- I can check the size, but only with fs.size(path). So I need to retain the fileid -> path mapping.
    f:push(fs.getSize(f.fileNames[f:pop()]))
  end)


  -- Accepts either a fileid or a filename string.
  local includeFile = function(f, filespec)
    f.inputSources[1]:save(f)
    f.mem[f.posAddr] = f.inputBufferTop -- Fake having finished with the old buffer.
    table.insert(f.inputSources, 1, FileInputSource:new(f, filespec))
  end

  forth:defineNative('include-file', false, function(f) includeFile(f, f:pop()) end)
  forth:defineNative('included', false, function(f) includeFile(f, f:fromBufferStack()) end)
  forth:defineNative



end

return M
