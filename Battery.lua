------------------------------------------------------------------------
--[[ Battery ]]--
-- A battery of experiments which can have multiple versions.
------------------------------------------------------------------------
local Battery = torch.class("hypero.Battery")

function Battery:__init(conn, name, verbose, strict)
   assert(torch.type(name) == 'string')
   assert(name ~= '')
   assert(torch.isTypeOf(conn, "hypero.Connect"))
   self.conn = conn
   self.name = name
   self.verbose = (verbose == nil) and true or verbose
   
   -- check if the battery already exists
   local row, err = self.conn:fetchOne([[
   SELECT bat_id FROM %s.battery WHERE bat_name = '%s';
   ]], {self.conn.schema, self.name})
   
   if (not row or _.isEmpty(row)) then
      if strict then
         error"Battery doesn't exist (create it with strict=false)"
      end
      if self.verbose then
         print("Creating new battery : "..name)
      end
      row, err = self.conn:fetchOne([[
      INSERT INTO %s.battery (bat_name) VALUES ('%s') RETURNING bat_id;
      ]], {self.conn.schema, self.name})
      
      if not row or _.isEmpty(row) then
         -- this can happen when multiple clients try to INSERT
         -- the same battery simultaneously
         local row, err = self.conn:fetchOne([[
         SELECT bat_id FROM %s.battery WHERE bat_name = '%s';
         ]], {self.conn.schema, self.name})
         if not row then
            error("Battery init error : \n"..err)
         end
      end
   end
   
   self.id = tonumber(row[1])
end

-- Version requires a description (like a commit message).
-- A battery can have multiple versions.
-- Each code change could have its own battery version.
function Battery:version(desc, strict)
   if torch.type(desc) == 'string' and desc == '' then 
      desc = nil 
   end
   
   if desc then
      -- identify version using description desc :
      assert(torch.type(desc) == 'string', "expecting battery version description string")
      self.verDesc = desc
      
      -- check if the version already exists
      local row, err = self.conn:fetchOne([[
      SELECT ver_id FROM %s.version 
      WHERE (bat_id, ver_desc) = (%s, '%s');
      ]], {self.conn.schema, self.id, self.verDesc})
      
      if not row or _.isEmpty(row) then
         if strict then
            error"Battery version doesn't exist (create it with strict=false)"
         end
         if self.verbose then
            print("Creating new battery version : "..self.verDesc)
         end
         row, err = self.conn:fetchOne([[
         INSERT INTO %s.version (bat_id, ver_desc) 
         VALUES (%s, '%s') RETURNING ver_id;
         ]], {self.conn.schema, self.id, self.verDesc})
         
         if not row or _.isEmpty(row) then
            -- this can happen when multiple clients try to INSERT
            -- the same version simultaneously
            local err
            row, err = self.conn:fetchOne([[
            SELECT ver_id FROM %s.version WHERE ver_desc = '%s';
            ]], {self.conn.schema, self.verDesc})
            if not self.id then
               error("Battery version error : \n"..err)
            end
         end
      end
      self.verId = tonumber(row[1])
   elseif not self.verId then
      -- try to obtain the most recent version :
      local row, err = self.conn:fetchOne([[
      SELECT MAX(ver_id) FROM %s.version WHERE bat_id = %s;
      ]], {self.conn.schema, self.id})
      
      if not row or _.isEmpty(row) then
         if strict then
            error"Battery version not initialized (create it with strict=false)"
         end
         self.verDesc = self.verDesc or "Initial battery version"
         if self.verbose then
            print("Creating new battery version : "..self.verDesc)
         end
         row, err = self.conn:fetchOne([[
         INSERT INTO %s.version (bat_id, ver_desc) 
         VALUES (%s, '%s') RETURNING ver_id;
         ]], {self.conn.schema, self.id, self.verDesc})
         
         if not row or _.isEmpty(row) then
            -- this can happen when multiple clients try to INSERT
            -- the same version simultaneously
            local row, err = self.conn:fetchOne([[
            SELECT ver_id FROM %s.version WHERE ver_desc = '%s';
            ]], {self.conn.schema, self.verDesc})
            if not row then
               error("Battery version error : \n"..err)
            end
         end
      end
      self.verId = tonumber(row[1])
   end
   
   return self.verId, self.verDesc
end

-- factory method for experiments of this battery
function Battery:experiment()
   assert(self.id, self.verId)
   return hypero.Experiment(self.conn, self)
end


-- fetch all version ids from db
-- or new versions if minVerDesc is specified
function Battery:fetchVersions(minVerDesc)
   local rows, err
   if minVerDesc then
      assert(torch.type(minVerDesc) == 'string', "expecting battery version description string")
      -- check if the version already exists
      local row, err = self.conn:fetchOne([[
      SELECT ver_id FROM %s.version 
      WHERE (bat_id, ver_desc) = (%s, '%s');
      ]], {self.conn.schema, self.id, minVerDesc})
      
      if not row or _.isEmpty(row) then
         if self.verbose then
            print("Could not find battery version : "..minVerDesc)
            if err then print(err) end
         end
      else
         rows, err = self.conn:fetch([[
         SELECT ver_id FROM %s.version 
         WHERE bat_id = %s AND ver_id >= %s ORDER BY ver_id ASC;
         ]], {self.conn.schema, self.id, row[1]})
         
      end
   else
      rows, err = self.conn:fetch([[
      SELECT ver_id FROM %s.version 
      WHERE bat_id = %s ORDER BY ver_id ASC;
      ]], {self.conn.schema, self.id})
   end
   
   local verIds = {}
   if rows then
      for i,row in ipairs(rows) do
         table.insert(verIds, tonumber(row[1]))
      end
   else
      error("Batter:fetchVersions error : \n"..tostring(err))
   end

   return verIds
end

-- fetch all experiment ids for version(s) from db
function Battery:fetchExperiments(verId)
   verId = verId or self.verId
   verId = torch.type(verId) ~= 'table' and {verId} or verId
   
   local rows, err = self.conn:fetch([[
   SELECT hex_id FROM %s.experiment 
   WHERE bat_id = %s AND ver_id IN (%s);
   ]], {self.conn.schema, self.id, table.concat(verId, ', ')})
   
   local hexIds = {}
   if rows then
      for i,row in ipairs(rows) do
         table.insert(hexIds, tonumber(row[1]))
      end
   else
      error("Battery:fetchExperiments error :\n"..tostring(err))
   end
   
   return hexIds
end

-- get version id of version having description verDesc
function Battery:getVerId(verDesc)
   assert(torch.type(verDesc == 'string'))
   local row, err = self.conn:fetchOne([[
   SELECT ver_id FROM %s.version 
   WHERE (bat_id, ver_desc) = (%s, '%s')
   ]], {self.conn.schema, self.id, verDesc})
   
   if not row then
      error("Battery:getVerId err :\n"..tostring(err))
   end
   
   return tonumber(row[1])
end

local function db2tbl(rows, colNames)
   local all = torch.type(colNames) == 'string' and colNames == '*'
   colNames = torch.type(colNames) == 'table' and colNames or string.split(colNames, ',')
   all = all or _.isEmpty(colNames)
   if all then
      colNames = {}
   end
   local colDict = {}
   
   local tbl = {}
   for i=1,#rows do
      local hexId, jsonVals = unpack(rows[i])
      local vals = json.decode.decode(jsonVals)
      local row = {}
      if all then
         for k,v in pairs(vals) do
            if not colDict[k] then
               colDict[k] = true
               table.insert(colNames, k)
            end 
         end
      end
      for j,name in ipairs(colNames) do
         row[j] = vals[name]
      end
      tbl[tonumber(hexId)] = row
   end
   return tbl, colNames
end

-- get hyper-params of experiments hexIds
-- The output is a table of tables (rows)
-- Each row is ordered by names (column names)
function Battery:getParam(hexIds, names)
   hexIds = torch.type(hexIds) == 'table' and hexIds or {hexIds}
   local rows, err = self.conn:fetch([[
   SELECT hex_id, hex_param FROM %s.param WHERE hex_id IN (%s)
   ]], {self.conn.schema, table.concat(hexIds,', ')})
   
   if not rows then
      error("Battery:getParam err"..tostring(err))
   end
   
   local tbl, names = db2tbl(rows, names or {})
   return tbl, names
end

-- get meta-data of experiments hexIds
function Battery:getMeta(hexIds, names)
   hexIds = torch.type(hexIds) == 'table' and hexIds or {hexIds}
   local rows, err = self.conn:fetch([[
   SELECT hex_id, hex_meta FROM %s.meta WHERE hex_id IN (%s)
   ]], {self.conn.schema, table.concat(hexIds,', ')})
   
   if not rows then
      error("Battery:getMeta err"..tostring(err))
   end
   
   local tbl, names = db2tbl(rows, names)
   return tbl, names
end

-- get result of experiments hexIds
function Battery:getResult(hexIds, names)
   hexIds = torch.type(hexIds) == 'table' and hexIds or {hexIds}
   local rows, err = self.conn:fetch([[
   SELECT hex_id, hex_result FROM %s.result WHERE hex_id IN (%s)
   ]], {self.conn.schema, table.concat(hexIds,', ')})
   
   if not rows then
      error("Battery:getResult err"..tostring(err))
   end
   
   local tbl, names = db2tbl(rows, names)
   return tbl, names
end

-- export hyper-param, result and meta-data as a table of rows
-- where each row is an experiment (a list of values).
function Battery:exportTable(config)
   config = config or {}
   assert(type(config) == 'table', "Constructor requires key-value arguments")
   local args, verDesc, minVer, paramNames, metaNames, resultNames, 
      orderBy, asc = xlua.unpack(
      {config},
      'Battery:exportTable', 
      'exports the battery of experiments as a lua table',
      {arg='verDesc', type='string', default=self.verDesc,
       help='description of version to be exported'},
      {arg='minVer', type='boolean', default=false,
       help='versionDesc specifies the minimum version to be exported'},
      {arg='paramNames', type='string | table', default='*',
       help='comma separated list of hyper-param columns to retrieve'},
      {arg='metaNames', type='string | table', default='*',
       help='comma separated list of meta-data columns to retrieve'},
      {arg='resultNames', type='string | table', default='*',
       help='comma separated list of result columns to retrieve'},
      {arg='orderBy', type='string', default='hexId',
       help='order by this result column'},
      {arg='asc', type='boolean', default=true,
       help='row ordering is ascending. False is descending.'}
   )
   
   -- select versions
   local verIds
   if verDesc == '' or verDesc == '*' or verDesc == nil then
      verIds = self:fetchVersions()
   elseif minVer then
      verIds = self:fetchVersions(verDesc)
   else
      verIds = {self:getVerId(verDesc)}
   end
   assert(#verIds > 0, "no versions found") 
   
   -- select experiments
   local hexIds = self:fetchExperiments(verIds)
   assert(#hexIds > 0, "no experiments found")
   
   -- select hyper-param, meta-data and result
   local hp, hpNames = self:getParam(hexIds, paramNames)
   local res, resNames = self:getResult(hexIds, resultNames)
   local md, mdNames = self:getMeta(hexIds, metaNames)
   
   -- join tables using hexId
   local tbl = {}
   local names = {hpNames, resNames, mdNames}
   
   for i, hexId in ipairs(hexIds) do
      local hp, res, md = hp[hexId], res[hexId], md[hexId]
      local row = {}
      local offset = 0
      for i,subtbl in ipairs{hp, res, md} do
         for k,v in pairs(subtbl) do
            row[k+offset] = v
         end
         offset = offset + #names[i]
      end
      if not _.isEmpty(row) then
         table.insert(row, 1, hexId)
         table.insert(tbl, row)
      end
   end
   
   local colNames = _.flatten(names)
   table.insert(colNames, 1, 'hexId')
   
   -- orderBy 
   if orderBy and orderBy ~= '' then
      local colIdx = _.find(colNames, orderBy)
      assert(colIdx, "unknown orderBy column name")
      _.sort(tbl, function(rowA, rowB) 
            valA, valB = rowA[colIdx], rowB[colIdx]
            local success, rtn = pcall(function()
                  if asc then
                     return valA < valB
                  else
                     return valA > valB
                  end
               end)
            if success then
               return rtn
            else
               return false
            end
         end)
   end
   
   return tbl, colNames
end
