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
      self.id, err = self.conn:fetchOne([[
      INSERT INTO %s.experiment (bat_id, ver_id) 
      VALUES (%s, %s) RETURNING hex_id
      ]], {self.conn.schema, batId, verId})[1]
      if not self.id then
         error("Experiment error :\n"..err)
      end
   else
      assert(torch.type(hexId) == 'number' or torch.type(hexId) == 'string')
      assert(pcall(function() return tonumber(hexId) end))
      self.id = tostring(hexId)
      local row, err = self.conn:fetchOne([[
      SELECT * FROM %s.experiment WHERE hex_id = %s
      ]], {self.conn.schema, hexId})
      assert(row, "Non existent experiment id : "..hexId)
   end
end

--[[ 3 get/set : hyperParam, metaData and results ]]--

-- hyper-param get/set (SELECT/INSERT)
function Xp:hyperParam(name, value, update)
   assert(torch.type(name) == 'string')
   if not value then
      -- get
      local row = self.conn:fetchOne([[
      SELECT param_val FROM %s.param 
      WHERE (hex_id, param_name) = (%s, '%s')
      ]], {self.conn.schema, self.id, name})
      
      if row then
         return json.decode.decode(row[1])
      else
         return nil, err
      end
   else
      -- set
      local jsonVal = json.encode.encode(value)
      local cur, err = self.conn:execute([[
      INSERT INTO %s.param (hex_id, param_name, param_val)
      VALUES (%s, '%s', '%s')
      ]], {self.conn.schema, self.id, name, jsonVal})
      
      if update and not cur then
         -- handle insert conflict
         local cur, err = self.conn:execute([[
         UPDATE %s.param 
         SET (param_name, param_val) = ('%s', '%s')
         WHERE hex_id = %s
         ]], {self.conn.schema, name, jsonVal, self.id})
         if not cur then
            error("Experiment:hyperParam UPDATE err :\n"..err)
         end
      elseif not cur then
         error("Experiment:hyperParam INSERT err :\n"..err)
      end
   end
end

-- fetch all the hyper parameter names from db
function Xp:fetchHyperParamNames()
   assert(torch.type(name) == 'string')
   local rows, err = self.conn:fetch([[
   SELECT distinct param_name FROM %s.param 
   WHERE hex_id = %s
   ]], {self.conn.schema, self.id})

   Xp:assert(torch.type(rows) == 'table')
   --Xp:assert(#rows == 2, "Postgres select serialize err")
   --Xp:assert(#rows[1] == 0, "Postgres missing columns err")

   if rows then
      -- rows = _.slice(rows, 3)
      return rows, err
   else
      return nil, err
   end
end

-- meta-data get/set
-- Unlike hyper-params, metadata do/should not influence the results of the experiment.
function Xp:metaData(name, value, update)
   assert(torch.type(name) == 'string')
   if not value then
      -- get
      local row, err = self.conn:fetchOne([[
      SELECT meta_val FROM %s.metadata 
      WHERE (hex_id, meta_name) = (%s, '%s')
      ]], {self.conn.schema, self.id, name})
      
      if row then
         return json.decode.decode(row[1])
      else
         return nil, err
      end
   else
      -- set
      local jsonVal = json.encode.encode(value)
      local cur, err = self.conn:execute([[
      INSERT INTO %s.metadata (hex_id, meta_name, meta_val)
      VALUES (%s, '%s', '%s')
      ]], {self.conn.schema, self.id, name, jsonVal})
      
      if update and not cur then
         -- handle insert conflict
         local cur, err = self.conn:execute([[
         UPDATE %s.metadata 
         SET (meta_name, meta_val) = ('%s', '%s')
         WHERE hex_id = %s
         ]], {self.conn.schema, name, jsonVal, self.id})
         if not cur then
            error("Experiment:metaData UPDATE err :\n"..err)
         end
      elseif not cur then
         error("Experiment:metaData INSERT err :\n"..err)
      end
   end
end

function Xp:result(name, value, update)
   assert(torch.type(name) == 'string')
   if not value then
      -- get
      local row, err = self.conn:fetchOne([[
      SELECT result_val FROM %s.result 
      WHERE (hex_id, result_name) = (%s, '%s')
      ]], {self.conn.schema, self.id, name})
      
      if row then
         return json.decode.decode(row[1])
      else
         return nil, err
      end
   else
      -- set
      local jsonVal = json.encode.encode(value)
      local cur, err = self.conn:execute([[
      INSERT INTO %s.result (hex_id, result_name, result_val)
      VALUES (%s, '%s', '%s')
      ]], {self.conn.schema, self.id, name, jsonVal})
      
      if update and not cur then
         -- handle insert conflict
         local cur, err = self.conn:execute([[
         UPDATE %s.result 
         SET (result_name, result_val) = ('%s', '%s')
         WHERE hex_id = %s
         ]], {self.conn.schema, name, jsonVal, self.id})
         if not cur then
            error("Experiment:result UPDATE err :\n"..err)
         end
      elseif not cur then
         error("Experiment:result INSERT err :\n"..err)
      end
   end
end

--[[ hyper param sampling distributions ]]--

-- sample from a categorical distribution
function Xp:categorical(varName, varProbs, varVals)
   assert(torch.type(varName) == 'string')
   assert(torch.type(dist) == 'table')
   
   local probs = torch.Tensor(varProbs)
   local idx = torch.multinomial(probs, 1)[1]
   local varVal = varVals and varVals[idx] or idx
   
   self:hyperParam(varName, varVal)
   return varVal
end

-- sample from a normal distribution
function Xp:normal(varName, varMean, varStd)
   assert(torch.type(varName) == 'string')
   assert(torch.type(varMean) == 'number')
   assert(torch.type(varStd) == 'number')
   
   local varVal = torch.normal(varMean, varStd)
   
   self:hyperParam(varName, varVal)
   return varVal
end

-- sample from uniform distribution
function Xp:uniform(varName, varMin, varMax)
   assert(torch.type(varName) == 'string')
   assert(torch.type(varMin) == 'number')
   assert(torch.type(VarMax) == 'number')
   
   local varVal = torch.uniform(varMin, varMax)
   
   self:hyperParam(varName, varVal)
   return varVar
end

-- Returns a value drawn according to exp(uniform(low, high)) 
-- so that the logarithm of the return value is uniformly distributed.
-- When optimizing, this variable is constrained to the interval [exp(low), exp(high)].
function Xp:logUniform(varName, varMin, varMax)
   assert(torch.type(varName) == 'string')
   assert(torch.type(varMin) == 'number')
   assert(torch.type(VarMax) == 'number')
   
   local varVal = torch.exp(torch.uniform(varMin, varMax))
   
   self:hyperParam(varName, varVal)
   return varVar
end

-- sample from uniform integer distribution
function Xp:randint(varName, varMin, varMax)
   assert(torch.type(varName) == 'string')
   assert(torch.type(varMin) == 'number')
   assert(torch.type(VarMax) == 'number')
   
   local varVal = math.random(varMin, varMax)
   
   self:hyperParam(varName, varVal)
   return varVar
end 

--[[ common meta data methods ]]--

function Xp:metaName(name)
   return self:metaData('name', name)
end

function Xp:metaHostname(hostname)
   return self:metaData('hostname', hostname)
end

function Xp:metaDataset(dataset)
   return self:metaData('dataset', dataset)
end

function Xp:metaSavepath(savepath)
   return self:metaData('savepath', savepath)
end

--[[ common experimental results ]]--
