local Battery = torch.class("hypero.Battery")

function Battery:__init(dbconn, name)
   assert(torch.type(name) == 'string')
   assert(name ~= '')
   assert(torch.isTypeOf(dbconn, "hypero.Postgres"))
   self.dbconn = dbconn
   self.name = name
   
   -- check if the battery already exists
   self.id = self.dbconn:fetchOne([[
   SELECT bat_id FROM hyper.battery WHERE bat_name = '%s';
   ]], {self.name})
   
   if not self.id or _.isEmpty(self.id) then
      print("Creating new battery : "..name)
      self.id = self.dbconn:fetchOne([[
      INSERT INTO hyper.battery (bat_name) VALUES ('%s') RETURNING bat_id;
      ]], {self.name})
      if not self.id or _.isEmpty(self.id)then
         self.id = self.dbconn:fetchOne([[
         SELECT bat_id FROM hyper.battery WHERE bat_name = '%s';
         ]], {self.name})
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
      self.verId = self.dbconn:fetchOne([[
      SELECT ver_id FROM hyper.version 
      WHERE (bat_id, ver_desc) = (%s, '%s');
      ]], {self.id, self.verDesc})
      
      if not self.verId or _.isEmpty(verId) then
         print("Creating new battery version : "..self.verDesc)
         
         self.verId = self.dbconn:fetchOne([[
         INSERT INTO hyper.version (bat_id, ver_desc) 
         VALUES (%s, '%s') RETURNING ver_id;
         ]], {self.id, self.verDesc})
         if not self.verId or _.isEmpty(self.verId) then
            self.verId = self.dbconn:fetchOne([[
            SELECT ver_id FROM hyper.version WHERE ver_desc = '%s';
            ]], {self.verDesc})
         end
      end
      self.verId = self.verId[1]
   elseif not self.verId then
      -- try to obtain the most recent version :
      self.verId = self.dbconn:fetchOne([[
      SELECT MAX(ver_id) FROM hyper.version WHERE bat_id = %s;
      ]], {self.id})
      
      if not self.verId or _.isEmpty(verId) then
         self.verDesc = self.verDesc or "Initial battery version"
         print("Creating new battery version : "..self.verDesc)
         
         self.verId = self.dbconn:fetchOne([[
         INSERT INTO hyper.version (bat_id, ver_desc) 
         VALUES (%s, '%s') RETURNING ver_id;
         ]], {self.id, self.verDesc})
         
         if not self.verId or _.isEmpty(self.verId) then
            self.verId = self.dbconn:fetchOne([[
            SELECT ver_id FROM hyper.version WHERE ver_desc = '%s';
            ]], {self.verDesc})
         end
      end
      self.verId = self.verId[1]
   end
   return self.verId
end

function Battery:experiment()
   assert(self.id, self.verId)
   return hypero.Experiment(self)
end
