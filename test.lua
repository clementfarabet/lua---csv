
-- test csv.File class

require 'csv'

tempfilename = "csv-test-delete-me.csv"

function testerror(a, b, msg)
   print("a = ", a)
   print("b = ", b)
   error(msg)
end

-- test two arrays
function testequalarray(a, b)
   if #a ~= #b then
      testerror(a, b,
		string.format("#a == %d ~= %d == #b", #a, #b))
   end
   for i = 1, #a do
      if a[i] ~= b[i] then
	 testerror(a, b, string.format("for i=%d, %q not equal %q", 
				       i, a[i], b[i]))
      end
   end
end

-- test two values
function testvalue(a, b)
   local res = a == b
   if res then return end
   testerror(a, b, string.format("%q not equal %q", a, b))
end



-- test writing file
function writeRecs(csvf)
   csvf:write({"a","b","c"})
   csvf:write({01, 02, 03})
   csvf:write({11, 12, 13})
end

csvf = csv.File(tempfilename, "w")
writeRecs(csvf)
csvf:close()


-- test reading same file line by line
function readRecs(csv)
   row = csvf:read()
   testequalarray(row, {"a","b","c"})
   datarownum = 0
   while true do
      local row = csvf:read()
      if not row then break end
      datarownum = datarownum + 1
      if datarownum == 1 then
	 testequalarray(row, {"1", "2", "3"})
      else
	 testequalarray(row, {"11", "12", "13"})
      end
   end
end

csvf = csv.File(tempfilename, "r")
readRecs(csvf)
csvf:close()

-- read same file all at once
csvf = csv.File(tempfilename, "r")
lines = csvf:readall()
csvf:close()
testequalarray(lines[1], {"a","b","c"})
testequalarray(lines[2], {"1", "2", "3"})
testequalarray(lines[3], {"11", "12", "13"})

-- test using a | instead of , as a separator
csvf = csv.File(tempfilename, "w", "|")
writeRecs(csvf)
csvf:close()

-- now read the records
csvf = csv.File(tempfilename, "r", "|")
readRecs(csvf)
csvf:close()

os.execute("rm " .. tempfilename)

print("all tests passed")
