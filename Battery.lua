------------------------------------------------------------------------
--[[ Battery ]]--
-- A battery of experiments which can have multiple versions.
------------------------------------------------------------------------
local Battery = torch.class("hypero.Battery")

function Battery:__init(conn, name, verbose)
   assert(torch.type(name) == 'string')
   assert(name ~= '')
   assert(torch.isTypeOf(conn, "hypero.Connect"))
   self.conn = conn
   self.name = name
   self.verbose = (verbose == nil) and true or verbose
   
   -- check if the battery already exists
   self.id = self.conn:fetchOne([[
   SELECT bat_id FROM %s.battery WHERE bat_name = '%s';
   ]], {self.conn.schema, self.name})
   
   if not self.id or _.isEmpty(self.id) then
      if self.verbose then
         print("Creating new battery : "..name)
      end
      self.id = self.conn:fetchOne([[
      INSERT INTO %s.battery (bat_name) VALUES ('%s') RETURNING bat_id;
      ]], {self.conn.schema, self.name})
      
      if not self.id or _.isEmpty(self.id) then
         -- this can happen when multiple clients try to INSERT
         -- the same battery simultaneously
         local err
         self.id, err = self.conn:fetchOne([[
         SELECT bat_id FROM %s.battery WHERE bat_name = '%s';
         ]], {self.conn.schema, self.name})
         if not self.id then
            error("Battery init error : \n"..err)
         end
      end
   end
   self.id = self.id[1]
end

-- Version requires a description (like a commit message).
-- A battery can have multiple versions.
-- Each code change could have its own battery version.
function Battery:version(desc)
   if desc then
      -- identify version using description desc :
      assert(torch.type(desc) == 'string', "expecting battery version description string")
      assert(desc ~= '')
      self.verDesc = desc
      
      -- check if the version already exists
      self.verId = self.conn:fetchOne([[
      SELECT ver_id FROM %s.version 
      WHERE (bat_id, ver_desc) = (%s, '%s');
      ]], {self.conn.schema, self.id, self.verDesc})
      
      if not self.verId or _.isEmpty(verId) then
         if self.verbose then
            print("Creating new battery version : "..self.verDesc)
         end
         self.verId = self.conn:fetchOne([[
         INSERT INTO %s.version (bat_id, ver_desc) 
         VALUES (%s, '%s') RETURNING ver_id;
         ]], {self.conn.schema, self.id, self.verDesc})
         
         if not self.verId or _.isEmpty(self.verId) then
            -- this can happen when multiple clients try to INSERT
            -- the same version simultaneously
            local err
            self.verId, err = self.conn:fetchOne([[
            SELECT ver_id FROM %s.version WHERE ver_desc = '%s';
            ]], {self.conn.schema, self.verDesc})
            if not self.id then
               error("Battery version error : \n"..err)
            end
         end
      end
      self.verId = self.verId[1]
   elseif not self.verId then
      -- try to obtain the most recent version :
      self.verId = self.conn:fetchOne([[
      SELECT MAX(ver_id) FROM hyper.version WHERE bat_id = %s;
      ]], {self.id})
      
      if not self.verId or _.isEmpty(verId) then
         self.verDesc = self.verDesc or "Initial battery version"
         if self.verbose then
            print("Creating new battery version : "..self.verDesc)
         end
         self.verId = self.conn:fetchOne([[
         INSERT INTO %s.version (bat_id, ver_desc) 
         VALUES (%s, '%s') RETURNING ver_id;
         ]], {self.conn.schema, self.id, self.verDesc})
         
         if not self.verId or _.isEmpty(self.verId) then
            -- this can happen when multiple clients try to INSERT
            -- the same version simultaneously
            local err
            self.verId, err = self.conn:fetchOne([[
            SELECT ver_id FROM %s.version WHERE ver_desc = '%s';
            ]], {self.conn.schema, self.verDesc})
            if not self.id then
               error("Battery version error : \n"..err)
            end
         end
      end
      self.verId = self.verId[1]
   end
   return self.verId, self.verDesc
end

-- fetch all version ids for a battery id from db
-- or new versions if minVerDesc is specified
function Battery:fetchVersions(minVerDesc, batId)
   local batId = batId or self.id
   local rows = nil, err
   if minVerDesc then
      assert(torch.type(minVerDesc) == 'string', "expecting battery version description string")
      -- check if the version already exists
      minVerId = self.conn:fetchOne([[
      SELECT ver_id FROM %s.version 
      WHERE (bat_id, ver_desc) = (%s, '%s');
      ]], {self.conn.schema, batId, minVerDesc})
      
      if not minVerId or _.isEmpty(minVerId) then
         if self.verbose then
            print("Could not find battery version : "..minVerDesc)
         end
      else
         rows, err = self.conn:fetch([[
         SELECT distinct ver_id FROM %s.version 
         WHERE bat_id=%s AND ver_id>=%s ORDER BY ver_id;
         ]], {self.conn.schema, batId})
      end
   end
   
   if not minVerId or not rows then
      if self.verbose then
         print("Get all versions for battery id : "..batId)
      end
      rows, err = self.conn:fetch([[
      SELECT distinct ver_id FROM %s.version 
      WHERE bat_id=%s ORDER BY ver_id;
      ]], {self.conn.schema, batId})
   end

   if rows then
      assert(torch.type(rows) == 'table')
      --Xp:assert(#rows == 2, "Postgres select serialize err")
      --Xp:assert(#rows[1] == 0, "Postgres missing columns err")
      return rows, err
   else
      return nil, err
   end
end

-- fetch all experiment ids for a battery id and version from db
function Battery:fetchExperiments(verId, batId)
   vertId = verId or self.verId
   assert(torch.type(verId) == 'string', "expecting battery version id string")
   assert(verId ~= '', "expecting battery version id string")
   local batId = batId or self.id
   local rows = self.conn:fetch([[
   SELECT distinct hex_id FROM %s.version 
   WHERE (bat_id, ver_id) = (%s, %s);
   ]], {self.conn.schema, batId, verId})

   if rows then
      assert(torch.type(rows) == 'table')
      --Xp:assert(#rows == 2, "Postgres select serialize err")
      --Xp:assert(#rows[1] == 0, "Postgres missing columns err")

      return _.slice(rows, 3)
   else
      return nil, err
   end
end

function Battery:exportTable(config)
   local paramNames
end

function Battery:experiment()
   assert(self.id, self.verId)
   return hypero.Experiment(self.conn, self)
end
