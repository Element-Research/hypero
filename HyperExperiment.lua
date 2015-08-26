local HX = torch.class("hypero.HyperExperiment")

function HX:__init(dbconn, hexId)
   self.dbconn = dbconn
   assert(torch.isTypeOf(dbconn, "hypero.Connect"))
   
   if torch.isTypeOf(hexId, "hypero.Battery") then
      local bat = hexId
      local batId, verId = bat.id, bat:version()
      assert(torch.type(batId) == 'number' or torch.type(batId) == 'string')
      assert(torch.type(verId) == 'number' or torch.type(verId) == 'string')
      assert(pcall(function() return tonumber(batId) and tonumber(verId) end))
      -- get a new experiment id 
      self.id = self.dbconn:execute([[
      INSERT INTO hyper.experiment (bat_id, ver_id) 
      VALUES (%s, %s) RETURNING hex_id
      ]], {batId, verId})[1]
   else
      assert(torch.type(hexId) == 'number' or torch.type(hexId) == 'string')
      assert(pcall(function() return tonumber(hexId) end))
      self.id = hexId
      local row = self.dbconn:fetchOne([[
      SELECT * FROM hyper.experiment (bat_id, ver_id) WHERE hex_id = %s
      ]], {hexId})[1]
      assert(row, "Non existent experiment id :"..hexId)
   end
end

function HX:categorical()

end
