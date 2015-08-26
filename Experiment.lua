local Xp = torch.class("hypero.Experiment")

function Xp:__init(dbconn, hexId)
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

--[[ 3 get/set : hyperParam, metaData and results ]]--

-- hyper-param get/set (SELECT/INSERT)
function Xp:hyperParam(name, value)
   assert(torch.type(name) == 'string')
   if not value then
      -- get
      local row = self.dbconn:fetchOne([[
      SELECT param_value FROM hyper.param 
      WHERE (hex_id, param_name) = (%s, '%s')
      ]], {self.id, name})
      if row then
         return row[1]
      else
         error("Hyper Param '"..name.."' undefined for experiment "..self.id)
      end
   else
      -- set
      local jsonVal = json.encode.encode(value)
      -- TODO handle insert conflicts
      self.dbconn:execute([[
      INSERT INTO hyper.param (hex_id, param_name, param_val)
      VALUES (%s, '%s', '%s')
      ]], {self.id, name, jsonValue})
   end
end

-- meta-data get/set
-- Unlike hyper-params, metadata do/should not influence the results of the experiment.
function Xp:metaData(name, value)
   assert(torch.type(name) == 'string')
   if not value then
      -- get
      local row = self.dbconn:fetchOne([[
      SELECT meta_value FROM hyper.metadata 
      WHERE (hex_id, meta_name) = (%s, '%s')
      ]], {self.id, name})
      if row then
         return row[1]
      else
         error("Meta Data '"..name.."' undefined for experiment "..self.id)
      end
   else
      -- set
      local jsonVal = json.encode.encode(value)
      -- TODO handle insert conflicts
      self.dbconn:execute([[
      INSERT INTO hyper.metadata (hex_id, meta_name, meta_val)
      VALUES (%s, '%s', '%s')
      ]], {self.id, name, jsonValue})
   end
end

function Xp:result(name, value)
   assert(torch.type(name) == 'string')
   if not value then
      -- get
      local row = self.dbconn:fetchOne([[
      SELECT result_value FROM hyper.result 
      WHERE (hex_id, result_name) = (%s, '%s')
      ]], {self.id, name})
      if row then
         return row[1]
      else
         error("Result '"..name.."' undefined for experiment "..self.id)
      end
   else
      -- set
      local jsonVal = json.encode.encode(value)
      -- TODO handle insert conflicts
      self.dbconn:execute([[
      INSERT INTO hyper.result (hex_id, result_name, result_val)
      VALUES (%s, '%s', '%s')
      ]], {self.id, name, jsonValue})
   end
end

--[[ hyper param sampling distributions ]]--

-- sample from a categorical distribution
-- varDist : {[prob] = value}. 
-- e.g. varDist = {[0.1]='linear', [0.2]='exp', [0.7]='adaptive'} 
function Xp:categorical(varName, varDist)
   assert(torch.type(varName) == 'string')
   assert(torch.type(dist) == 'table')
   local probs, vals = {}, {}
   for prob, val in pairs(dist) do 
      assert(torch.type(prob) == 'number')
      table.insert(probs, prob)
      table.insert(vals, val)
   end
   
   probs = torch.Tensor(probs)
   local idx = torch.multinomial(probs, 1)[1]
   local varVal = vals[idx]
   
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
