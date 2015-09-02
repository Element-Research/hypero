local Xp = torch.class("hypero.Experiment")

function Xp:__init(conn, hexId)
   self.conn = conn
   assert(torch.isTypeOf(conn, "hypero.Connect"))

   if torch.isTypeOf(hexId, "hypero.Battery") then
      local bat = hexId
      local batId, verId = bat.id, bat:version()
      assert(torch.type(batId) == 'number' or torch.type(batId) == 'string')
      assert(torch.type(verId) == 'number' or torch.type(verId) == 'string')
      assert(pcall(function() return tonumber(batId) and tonumber(verId) end))
      -- get a new experiment id 
      local err
      local row, err = self.conn:fetchOne([[
      INSERT INTO %s.experiment (bat_id, ver_id) 
      VALUES (%s, %s) RETURNING hex_id
      ]], {self.conn.schema, batId, verId})
      if not row then
         error("Experiment error :\n"..err)
      end
      self.id = tonumber(row[1])
   else
      assert(torch.type(hexId) == 'number' or torch.type(hexId) == 'string')
      self.id = tonumber(hexId)
      local row, err = self.conn:fetchOne([[
      SELECT * FROM %s.experiment WHERE hex_id = %s
      ]], {self.conn.schema, hexId})
      assert(row, "Non existent experiment id : "..hexId)
   end
end

-- hyper-param get/set
function Xp:setParam(hp, update)
   assert(torch.type(hp) == 'table')
   -- set
   local jsonVal = json.encode.encode(hp)
   local cur, err = self.conn:execute([[
   INSERT INTO %s.param (hex_id, hex_param) VALUES (%s, '%s')
   ]], {self.conn.schema, self.id, jsonVal})
   
   if update and not cur then
      -- handle insert conflict
      local cur, err = self.conn:execute([[
      UPDATE %s.param SET hex_param = '%s' WHERE hex_id = %s
      ]], {self.conn.schema, jsonVal, self.id})
      if not cur then
         error("Experiment:setParam UPDATE err :\n"..err)
      end
   elseif not cur then
      error("Experiment:setParam INSERT err :\n"..err)
   end
   
   return value
end

function Xp:getParam()
   -- get
   local row = self.conn:fetchOne([[
   SELECT hex_param FROM %s.param WHERE hex_id = %s
   ]], {self.conn.schema, self.id})
   
   if row then
      return json.decode.decode(row[1])
   else
      return nil, err
   end
end

-- meta-data get/set
-- Unlike hyper-params, metadata should not influence the results of the experiment.
function Xp:setMeta(md, update)
   assert(torch.type(md) == 'table')
   -- set
   local jsonVal = json.encode.encode(md)
   local cur, err = self.conn:execute([[
   INSERT INTO %s.meta (hex_id, hex_meta) VALUES (%s, '%s')
   ]], {self.conn.schema, self.id, jsonVal})
   
   if update and not cur then
      -- handle insert conflict
      local cur, err = self.conn:execute([[
      UPDATE %s.meta SET hex_meta = '%s' WHERE hex_id = %s
      ]], {self.conn.schema, jsonVal, self.id})
      if not cur then
         error("Experiment:setMeta UPDATE err :\n"..err)
      end
   elseif not cur then
      error("Experiment:setMeta INSERT err :\n"..err)
   end
end

function Xp:getMeta()
    -- get
   local row, err = self.conn:fetchOne([[
   SELECT hex_meta FROM %s.meta WHERE hex_id = %s
   ]], {self.conn.schema, self.id})
   
   if row then
      return json.decode.decode(row[1])
   else
      return nil, err
   end
end

function Xp:setResult(res, update)
   assert(torch.type(res) == 'table')
   -- set
   local jsonVal = json.encode.encode(res)
   local cur, err = self.conn:execute([[
   INSERT INTO %s.result (hex_id, hex_result) VALUES (%s, '%s')
   ]], {self.conn.schema, self.id, jsonVal})
   
   if update and not cur then
      -- handle insert conflict
      local cur, err = self.conn:execute([[
      UPDATE %s.result SET hex_result = '%s' WHERE hex_id = %s
      ]], {self.conn.schema, jsonVal, self.id})
      if not cur then
         error("Experiment:setResult UPDATE err :\n"..err)
      end
   elseif not cur then
      error("Experiment:setResult INSERT err :\n"..err)
   end
end

function Xp:getResult()
   local row, err = self.conn:fetchOne([[
   SELECT hex_result FROM %s.result WHERE hex_id = %s
   ]], {self.conn.schema, self.id})
   
   if row then
      return json.decode.decode(row[1])
   else
      return nil, err
   end
end
