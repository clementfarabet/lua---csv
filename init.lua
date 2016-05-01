----------------------------------------------------------------------
--
-- Copyright (c) 2012 Roy Lowrance, Clement Farabet
--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
-- LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
-- OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
-- WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--
----------------------------------------------------------------------
-- description:
--     csvigo - a little package to handle CSV files (read/write)
--
-- history:
--     June 24, 2012 - create a complete API to make queries - C. Farabet
--     June 23, 2012 - made a pkg, and high-level functions - C. Farabet
--     June 1, 2012  - csvigo.File class - R. Lowrance
----------------------------------------------------------------------

require 'torch'
require 'dok'

-- create global nnx table:
csvigo = {}

-- csvigo.File manager:
torch.include('csvigo', 'File.lua')

----------------------------------------------------------------------

-- functional API: simple shortcuts to serialize data using CSV files
-- this API is similar to the image.load/save, where the user doens't
-- have to create a csvigo.File object, and handle it later on.

-- load
function csvigo.load(...)
   -- usage
   local args, path, separator, mode, header, verbose, skip = dok.unpack(
      {...},
      'csvigo.load',
      'Load a CSV file, according to the specified mode:\n'
      .. ' - raw   : no clean up, return a raw list of lists, a 1-to-1 mapping to the CSV file\n'
      .. ' - tidy  : return a clean table, where each entry is a variable that points to its values\n'
      .. ' - query : return the tidy table, as well as query operators\n'
      .. ' - large : returns a table that decodes rows on the fly, on indexing ',
      {arg='path',         type='string',  help='path to file', req=true},
      {arg='separator',    type='string',  help='separator (one character)', default=','},
      {arg='mode',         type='string',  help='load mode: raw | tidy | query', default='tidy'},
      {arg='header',       type='boolean', help='file has a header (variable names)', default=true},
      {arg='verbose',      type='boolean', help='verbose load', default=true},
      {arg='skip',         type='number',  help='skip this many lines at start of file', default=0},
      {arg='column_order', type='boolean', help='return csv\'s column order in tidy mode', default=false}
   )

   -- check path
   path = path:gsub('^~',os.getenv('HOME'))

   -- verbose print
   local function vprint(...) if verbose then print('<csv>',...) end end

   -- load CSV
   vprint('parsing file: ' .. path)
   local f = csvigo.File(path, 'r', separator)
   local loaded = f:readall(mode)
   f:close()

   -- do work depending on mode
   if mode == 'raw' or mode == 'large' then
      -- simple, dont do anything
      vprint('parsing done')
      return loaded

   elseif mode == 'tidy' or mode == 'query' then
      -- tidy up results:
      vprint('tidying up entries')
      local tidy = {}
      local i2key = {}
      -- header?
      local start = 1 + skip
      if header then
         -- use header names
         i2key = loaded[start]
         start = start + 1
      else
         -- generate names
         for i = 1,#loaded[start] do
            i2key[i] = 'var_'..i
         end
      end
      for i,key in ipairs(i2key) do
         tidy[key] = {}
      end
      -- parse all
      for i = start,#loaded do
         local entry = loaded[i]
         for i,val in ipairs(entry) do
            table.insert(tidy[i2key[i]], val)
         end
      end
      -- return tidy table
      if mode == 'tidy' then
         vprint('returning tidy table')

         if args.column_order then
            return i2key,tidy
         else
            return tidy
         end
      end

      -- query mode: build reverse index
      vprint('generating reversed index for fast queries')
      local revidx = {}
      for var,vals in pairs(tidy) do
         revidx[var] = {}
         for i,val in ipairs(vals) do
            revidx[var][val] = revidx[var][val] or {}
            table.insert(revidx[var][val], i)
         end
      end

      -- create a function/closure that can be used to query
      -- the table
      local function query(...)
         -- usage
         local args, query, varvals = dok.unpack(
            {...},
            'query',
            'This closure was automatically generated to query your data.\n'
            .. 'Example of query: query(\'union\', {var1={1}, var2={2,3,4}})\n'
            .. 'this query will return a subset of the original data, where var1 = 1 OR var2 = 2 or 3 or 4 \n'
            .. '\n'
            .. 'Other example of query: query(\'inter\', {var1={1}, var2={2,3,4}})\n'
            .. 'this query will return a subset of the original data, where var1 = 1 AND var2 = 2 or 3 or 4 \n'
            .. '\n'
            .. 'Other example of query: query(\'vars\')\n'
            .. 'this will return a list of the variable names\n'
            .. '\n'
            .. 'Other example of query: query() or query(\'all\')\n'
            .. 'this query will return the complete dataset'
            ,
            {arg='query',  type='string', help='query: all | help | vars | inter | union', default='all'},
            {arg='vars', type='table',  help='list of vars/vals'}
         )
         if query == 'help' then
            -- help
            print(args.usage)
            return

         elseif query == 'vars' then
            -- return vars
            local vars = {}
            for k in pairs(tidy) do
               table.insert(vars,k)
            end
            return vars

         elseif query == 'all' then
            -- query all: return the whole thing
            return tidy

         else
            -- query has this form:
            -- { var1 = {'value1', 'value2'}, var2 = {'value1'} }
            -- OR
            -- { var1 = 'value1', var2 = 'value2'}
            -- convert second form into first one:
            for var,vals in pairs(varvals) do
               if type(vals) ~= 'table' then
                  varvals[var] = {vals}
               end
            end
            -- find all indices that are ok
            local indices = {}
            if query == 'union' then
               for var,vals in pairs(varvals) do
                  for _,val in ipairs(vals) do
                     local found = revidx[var][tostring(val)]
		     if found ~= nil then
			for _,idx in ipairs(found) do
			   table.insert(indices, idx)
			end
		     end
                  end
               end
            else -- 'inter'
               local revindices = {}
               local nvars = 0
               for var,vals in pairs(varvals) do
                  for _,val in ipairs(vals) do
                     local found = revidx[var][tostring(val)]
                     for _,idx in ipairs(found) do
                        revindices[idx] = (revindices[idx] or 0) + 1
                     end
                  end
                  nvars = nvars + 1
               end
               for var,vals in pairs(varvals) do
                  for _,val in ipairs(vals) do
                     local found = revidx[var][tostring(val)]
                     for _,idx in ipairs(found) do
                        if revindices[idx] == nvars then
                           table.insert(indices, idx)
                        end
                     end
                  end
               end
            end
            table.sort(indices, function(a,b) return a<b end)
            -- generate filtered table
            local filtered = {}
            for k in pairs(tidy) do
               filtered[k] = {}
            end
            for idx,i in ipairs(indices) do
               if i ~= indices[idx-1] then -- check for doubles
                  for k in pairs(tidy) do
                     table.insert(filtered[k], tidy[k][i])
                  end
               end
            end
            -- return filtered table
            return filtered
         end
      end

      -- returning query closure
      vprint('returning query closure, type query(\'help\') to get help')
      return query

   else
      print(args.usage)
      error('unknown mode')
   end
end

-- load
function csvigo.save(...)
   -- usage
   local args, path, data, separator, mode, header, verbose = dok.unpack(
      {...},
      'csvigo.save',
      'Load a CSV file, according to the specifided mode:\n'
      .. ' - raw   : no clean up, return a raw list of lists, a 1-to-1 mapping to the CSV file\n'
      .. ' - tidy  : return a clean table, where each entry is a variable that points to its values\n'
      .. ' - query : return the tidy table, as well as query operators',
      {arg='path',         type='string',  help='path to file', req=true},
      {arg='data',         type='table',   help='table to save as a CSV file', req=true},
      {arg='separator',    type='string',  help='separator (one character)', default=','},
      {arg='mode',         type='string',  help='table to save is represented as: raw | tidy | query', default='autodetect'},
      {arg='header',       type='boolean', help='table has a header (variable names)', default=true},
      {arg='verbose',      type='boolean', help='verbose load', default=true},
      {arg='column_order', type='table',   help='Write csv according to given column order', default=nil},
      {arg='nan_as_missing', type='boolean', help='Save nan values (0/0) as missing',  default=false}
   )

   -- check path
   path = path:gsub('^~',os.getenv('HOME'))

   -- verbose print
   local function vprint(...) if verbose then print('<csv>',...) end end

   -- save CSV
   vprint('writing to file: ' .. path)
   local f = csvigo.File(path,'w',separator, args.nan_as_missing)

   -- autodetect mode?
   if mode == 'autodetect' then
      if type(data) == 'function' then
         mode = 'query'
      elseif type(data) == 'table' then
         if #data == 0 then
            mode = 'tidy'
         else
            mode = 'raw'
         end
      else
         error('cannot autodetect mode, incorrect data type')
      end
   end

   -- do work depending on mode
   if mode == 'raw' then
      -- simple, just write table
      f:writeall(data)
      vprint('writing done')

   elseif mode == 'tidy' or mode == 'query' then
      -- query mode?
      if mode == 'query' then
         -- query all data:
         vprint('generating tidy table')
         data = data('all')
      end
      -- 'data' is a tidy table, export to raw mode
      vprint('exporting tidy table to raw CSV')
      local raw = {}
      -- use headers?
      local headers
      if header then
         headers = {}

         if args.column_order then
            for _,var in pairs(args.column_order) do
               table.insert(headers, var)
            end
         else
            for var in pairs(data) do
               table.insert(headers, var)
            end
         end
      end
      -- export data
      if args.column_order then
         for var,vals in pairs(args.column_order) do
            for i,val in ipairs(data[vals]) do
               raw[i] = raw[i] or {}
               table.insert(raw[i], val)
            end
         end
      else
         for var,vals in pairs(data) do
            for i,val in ipairs(vals) do
               raw[i] = raw[i] or {}
               table.insert(raw[i], val)
            end
         end
      end
      -- write raw data
      if headers then f:write(headers) end
      f:writeall(raw)
      vprint('writing done')

   else
      print(args.usage)
      error('unknown mode')
   end

   -- done
   f:close()
end

return csvigo
