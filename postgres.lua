------------------------------------------------------------------------
--[[ Postgres ]]--
-- Simplified PostgreSQL database connection handler. 
-- Uses the ~/.pgpass file for authentication 
-- see (http://wiki.postgresql.org/wiki/Pgpass)
------------------------------------------------------------------------
local Postgres = torch.class("hypero.Postgres")

function Postgres:__init(config)
   config = config or {}
   local args, database, user, host, env, autocommit
      = xlua.unpack(
      {config},
      'Postgres', 'Default is to get the connection string from an ' ..
      'environment variable. For security reasons, and to allow ' .. 
      'for its serialization, no password is accepted. The password ' ..
      'should be set in the ~/.pgpass file.',
      {arg='database', type='string', help='name of postgres database'},
      {arg='user', type='string', help='username used to connect to db'},
      {arg='host', type='string', help='hostname/IP address of database'},
      {arg='env', type='string', default='HYPER_PG_CONN'},
      {arg='autocommit', type='boolean', default=true}
   )
   if not (database or user or host) then
      self.connStr = os.getenv(env)
      assert(self.connStr, "Environment variable HYPER_PG_CONN not set")
   else
      self.connStr = ""
      if database then self.connStr = self.connStr.."dbname="..database.." " end
      if user then self.connStr = self.connStr.."user="..user.." " end
      if host then self.connStr = self.connStr.."host="..host.." " end
   end
   local env = require('luasql.postgres'):postgres()
   self.conn = assert(env:connect(self.connStr))
   self.conn:setautocommit(autocommit)
   self.autocommit = autocommit
end
   
function Postgres:executeMany(command, param_list)
   local results = {}
   local result
   for i, params in pairs (param_list) do
      result = self:execute(command, params)
      table.insert(results, result)
   end
   return results
end
	
function Postgres:execute(command, params)
   local result
   if params then
      result = self.conn:execute(string.format(command, unpack(params)))
   else
      result = self.conn:execute(command)
   end
   return result
end

--mode : 'n' returns rows as array, 'a' returns them as key-value
function Postgres:fetch(command, params, mode)
   mode = mode or 'n'
   local cur = self:execute(command, params)
   local coltypes = cur:getcoltypes()
   local colnames = cur:getcolnames()
   local row = cur:fetch({}, mode)
   local rows = {}
   while row do
     table.insert(rows, row)
     row = cur:fetch({}, mode)
   end
   cur:close()
   return rows, coltypes, colnames
end

function Postgres:fetchOne(command, params, mode)
   mode = mode or 'n'
   local cur = self:execute(command, params)
   if cur then
	   local coltypes = cur:getcoltypes()
	   local colname = cur:getcolnames()
	   local row = cur:fetch({}, mode)
	   cur:close()
      return row, coltypes, colnames
   else
      return false
   end
end

function Postgres:close()
   self.conn:close()
end

-- These two methods allow for (de)serialization of Postgres objects:
function Postgres:write(file)
   file:writeObject(self.connStr)
   file:writeObject(self.autocommit)
end

function Postgres:read(file, version)
   self.connStr = file:readObject()
   self.autocommit = file:readObject()
   local env = require('luasql.postgres'):postgres()
   self.conn = assert(env:connect(self.connStr))
end


local function test(pg, no_serialize)
   local pg = pg or dp.Postgres()
   local res = pg:execute"CREATE TABLE public.test5464 ( n INT4, v FLOAT4, s TEXT )"
   print(res)
   res = pg:fetchOne"SELECT * FROM public.test5464"
   print(res)
   local param_list = {
      {5, 4.1, 'asdfasdf'},
      {6, 3.5, 'asdfashhd'},
      {6, 3.7, 'asdfashhd2'}
   }
   res = pg:executeMany("INSERT INTO public.test5464 VALUES (%s, %s, '%s');", param_list)
   print(res)
   res = pg:fetch"SELECT * FROM public.test5464 WHERE n = 6"
   print(res)
   if not no_serialize then
      local pg_str = torch.serialize(pg)
      test(torch.deserialize(pg_str), true)
   end
end
