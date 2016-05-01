----------------------------------------------------------------------
-- csvigo.File

-- A class to manage comma separate value files + two directly-usable functions
-- various function to manage csv files

-- These CSV files all have a comma delimiter and use " as the quote character
-- The separator ',' can be user-defined. A common example is ' ', which allows
-- for space separated values.

-- Ref:
-- http://www.lua.org/pil/20.4.html
-- http://www.torch.ch/manual/torch/utility#torchclass
----------------------------------------------------------------------

-- enclose commas and quotes between quotes and escape original quotes
local function escapeCsv(s, separator)
   if string.find(s, '["' .. separator .. ']') then
   --if string.find(s, '[,"]') then
      s = '"' .. string.gsub(s, '"', '""') .. '"'
   end
   return s
end

-- convert an array of strings or numbers into a row in a csv file
local function tocsv(t, separator, nan_as_missing)
   local s = ""
   for _,p in pairs(t) do
      if (nan_as_missing and p ~= p) then
         p = ''
      end
      s = s .. separator .. escapeCsv(p, separator)
   end
   return string.sub(s, 2) -- remove first comma
end

-- break record from csv file into array of strings
local function fromcsv(s, separator)
   if not s then error("s is null") end
   s = s .. separator -- end with separator
   if separator == ' ' then separator = '%s+' end
   local t = {}
   local fieldstart = 1
   repeat
      -- next field is quoted? (starts with "?)
      if string.find(s, '^"', fieldstart) then
         local a, c
         local i = fieldstart
         repeat
            -- find closing quote
            a, i, c = string.find(s, '"("?)', i+1)
         until c ~= '"'  -- quote not followed by quote?
         if not i then error('unmatched "') end
         local f = string.sub(s, fieldstart+1, i-1)
         table.insert(t, (string.gsub(f, '""', '"')))
         fieldstart = string.find(s, separator, i) + 1
      else
         local nexti = string.find(s, separator, fieldstart)
         table.insert(t, string.sub(s, fieldstart, nexti-1))
         fieldstart = nexti + 1
      end
   until fieldstart > string.len(s)
   return t
end

----------------------------------------------------------------------

-- create class Csv
local Csv = torch.class("csvigo.File")

-- initializer
function Csv:__init(filepath, mode, separator, nan_as_missing)
   local msg = nil
   self.filepath = filepath
   self.file, msg = io.open(filepath, mode)
   self.separator = separator or ','
   self.nan_as_missing = nan_as_missing or false
   if not self.file then error(msg) end
end

-- close underlying file
function Csv:close()
   self.file:close()
end

-- return iterator that reads all the remaining lines
function Csv:lines()
   return self.file:lines()
end

-- return next record from the csv file
-- return nill if at end of file
function Csv:read()
   local line = self.file:read()
   if not line then return nil end
   -- strip CR line endings
   line = line:gsub('\r', '')
   return fromcsv(line, self.separator)
end

function Csv:largereadall()
    local ok = pcall(require, 'torch')
    if not ok then
        error('large mode needs the torch package')
    end
    local libcsvigo = require 'libcsvigo'
    local ffi = require 'ffi'
    local path = self.filepath
    local f = torch.DiskFile(path, 'r'):binary()
    f:seekEnd()
    local length = f:position() - 1
    f:seek(1)
    local data = f:readChar(length)
    f:close()

    -- now that the ByteStorage is constructed,
    -- one has to make a dictionary of [offset, length] pairs of the row.
    -- for efficiency, do one pass to count number of rows,
    -- and another pass to create a LongTensor and fill it
    local lookup = libcsvigo.create_lookup(data)

    local out = {}
    local separator = self.separator

    local function index (tbl, i)
        assert(i, 'index has to be given')
        assert(i > 0 and i <= lookup:size(1), "index out of bounds: " ..  i)
        local line = ffi.string(data:data() + lookup[i][1], lookup[i][2])
        local entry = fromcsv(line, separator)
        return entry
    end

    local function stringm (i)
        assert(i, 'index has to be given')
        assert(i > 0 and i <= lookup:size(1), "index out of bounds: " ..  i)
        return ffi.string(data:data() + lookup[i][1], lookup[i][2])
    end

    out.mt = {}
    out.mt.__index = index

    out.mt.__newindex = function (t,k,v)
        error("attempt to update a read-only table", 2)
    end

    out.mt.__len = function (t)
        return lookup:size(1)
    end

    out.mt.__tostring = function(t)
        local s = ''
        if lookup:size(1) < 30 then
            for i = 1, lookup:size(1) do
                s = s .. stringm(i) .. '\n'
            end
        else
            for i = 1, 10 do
                s = s .. stringm(i) .. '\n'
            end
            for i = 1, 10 do
                s = s .. '.. .. .. .. .. .. .. .. .. \n'
            end
            for i = lookup:size(1)-10, lookup:size(1) do
                s = s .. stringm(i) .. '\n'
            end
        end
        return s
    end

    out.mt.__ipairs = function(t)
        local counter = 0
        function iter()
            counter = counter + 1
            if counter <= lookup:size(1) then
                return counter, index(t, counter)
            end
            return nil
        end
        return iter, t, 0
    end

    out.mt.__pairs = function(t)
        local counter = 0
        function iter()
            counter = counter + 1
            if counter <= lookup:size(1) then
                return counter, index(t, counter)
            end
            return nil
        end
        return iter, t, nil
    end

    setmetatable(out, out.mt)
    -- size
    -- tostring

    -- iterator
    -- index
    -- error on newindex

    return out
end

-- return all records as an array
-- each element of the array is an array of strings
-- should be faster than reading record by record
function Csv:readall(mode)
   if mode == 'large' then
       return self:largereadall()
   end
   local res = {}
   while true do
      local line = self.file:read("*l")
      if not line then break end
      -- strip CR line endings
      line = line:gsub('\r', '')
      local entry = fromcsv(line, self.separator)
      res[#res+1] = entry
   end
   return res
end

-- write array of strings|numbers to the csv file followed by \n
-- convert to csv format by inserting commas and quoting where necessary
-- return nil
function Csv:write(a)
   res, msg = self.file:write(tocsv(a, self.separator, self.nan_as_missing),"\n")
   if res then return end
   error(msg)
end

-- write all records in an array (table of tables)
function Csv:writeall(a, nan_as_missing)
   for i,entry in ipairs(a) do
      res, msg = self.file:write(tocsv(entry, self.separator, self.nan_as_missing),"\n")
      if not res then error(msg) end
   end
   return true
end
