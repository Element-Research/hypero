local Connect = torch.class("hypero.Connect")

function Connect:__init(config)
   self.dbconn = hypero.Postgres(config)
   self:create()
end
hypero.connect = hypero.Connect

function Connect:battery(name, version, description)
   local bat = hypero.Battery(self.dbconn, name)
   bat:version(version, description)
   return bat
end

function Connect:close()
   self.dbconn.close()
end

function Connect:create()
   -- create the schema and tables if they don't already exist
   self.dbconn:execute([[
   CREATE SCHEMA IF NOT EXISTS hyper;

   CREATE TABLE IF NOT EXISTS hyper.battery (
      bat_id 		BIGSERIAL,
      bat_name   	VARCHAR(255),
      bat_time 	TIMESTAMP DEFAULT now(),
      PRIMARY KEY (bat_id),
      UNIQUE (bat_name)
   );

   CREATE TABLE IF NOT EXISTS hyper.version (
      ver_id 		BIGSERIAL,
      bat_id		INT8,
      ver_num		INT8,
      ver_time	TIMESTAMP DEFAULT now(),
      ver_desc 	VARCHAR(255),
      PRIMARY KEY (ver_id),
      FOREIGN KEY (bat_id) REFERENCES hyper.battery (bat_id),
      UNIQUE (bat_id, ver_num, ver_desc)
   );

   CREATE TABLE IF NOT EXISTS hyper.experiment (   
      hex_id      	BIGSERIAL,
      bat_id      	INT8,
      ver_id		INT8,
      hex_time 	TIMESTAMP DEFAULT now(),
      FOREIGN KEY (bat_id) REFERENCES hyper.battery(bat_id),
      FOREIGN KEY (ver_id) REFERENCES hyper.version(ver_id),
      PRIMARY KEY (hex_id)
   );

   CREATE TABLE IF NOT EXISTS hyper.param (
      hex_id		INT8,
      param_name	VARCHAR(255),
      param_val	JSON, 
      PRIMARY KEY (hex_id, param_name),
      FOREIGN KEY (hex_id) REFERENCES hyper.experiment (hex_id)
   );

   CREATE TABLE IF NOT EXISTS hyper.metadata (
      hex_id		INT8,
      meta_name	VARCHAR(255),
      meta_val 	JSON,
      PRIMARY KEY (hex_id, meta_name),
      FOREIGN KEY (hex_id) REFERENCES hyper.experiment (hex_id)
   );

   CREATE TABLE IF NOT EXISTS hyper.result (
      hex_id		INT8,
      result_name	VARCHAR(255),
      result_val	JSON,
      PRIMARY KEY (hex_id, result_name),
      FOREIGN KEY (hex_id) REFERENCES hyper.experiment (hex_id)
   );   
   ]])
end
