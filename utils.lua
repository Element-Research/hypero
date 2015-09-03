-- http://lua-users.org/wiki/SplitJoin
function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

-- http://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
function table.length(T)
   local count = 0
   for _ in pairs(T) do count = count + 1 end
   return count
end

-- http://nocurve.com/simple-csv-read-and-write-using-lua/
function hypero.writecsv(path, header, data, sep)
   sep = sep or ','
   local file = assert(io.open(path, "w"))
   local nCol = header
   if torch.type(header) == 'table' then
      nCol = #nCol
      data = _.clone(data)
      table.insert(data, 1, header)
   else
      assert(torch.type(nCol) == 'number')
   end
   print(#header, header)
   for i=1,#data do
      local row = data[i]
      if i == 4 or i == 5 or i == 6 then
         print(nCol, row)
      end
      for j=1,nCol do
         if j>1 then 
            file:write(sep) 
         end
         local val = row[j]
         local jsonVal = json.encode.encode(val)
         if torch.type(val) == 'table' then
            jsonVal = '"'..jsonVal..'"'
         end
         file:write(jsonVal)
     end
     file:write('\n')
   end
   file:close()
end
