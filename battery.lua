local Battery = torch.class("hypero.Battery")

function Battery:__init(dbconn, name)
   assert(torch.type(name) == 'string')
   assert(name ~= '')
   self.dbconn = dbconn
   self.name = name
   
   -- check if the battery already exists
   self.id = self.dbconn:fetchOne([[
   SELECT bat_id FROM hyper.battery WHERE bat_name = %s;
   ]], {self.name})
   
   if not self.id then
      print("Creating new battery : "..name)
      self.id = self.dbconn:fetchOne([[
      INSERT INTO hyper.battery (bat_name) VALUES (%s) RETURNING bat_id;
      ]], {self.name})
      if not self.id then
         self.bat_id = self.dbconn:fetchOne([[
         SELECT bat_id FROM hyper.battery WHERE bat_name = %s;
         ]], {self.name})
      end
   end
end

function Battery:version(num, description)
   
end

