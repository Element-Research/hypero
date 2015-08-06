local Connect = torch.class("hp.Connect")

function Connect:__init(config)
   self.dbconn = hp.Postgres(config)
   self:create()
end
hp.connect = hp.Connect

function Connect:battery(name, version, description)
   local bat = hp.Battery(self.dbconn, name)
   bat:version(version, description)
   return bat
end

function Connect:close()
   self.dbconn.close()
end

function Connect:setup()
   -- create the battery table if it doesn't already exist
   self.dbconn:execute([[
   
   
   CREATE TABLE IF NOT EXISTS hyper.battery (
      bat_id 		INT8 DEFAULT next_val(hyper.bat_id_seq),
      bat_name   	VARCHAR(255),
      PRIMARY KEY (bat_id),
      UNIQUE (bat_name)
   );
   
   
   ]])
   
   -- create the 
   
end
