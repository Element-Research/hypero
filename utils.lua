-- http://lua-users.org/wiki/SplitJoin
function string:split(sep)
   local sep, fields = sep or ":", {}
   local pattern = string.format("([^%s]+)", sep)
   self:gsub(pattern, function(c) fields[#fields+1] = c end)
   return fields
end

--http://stackoverflow.com/questions/2705793/how-to-get-number-of-entries-in-a-lua-table
function table.length(T)
   local count = 0
   for _ in pairs(T) do count = count + 1 end
   return count
end
