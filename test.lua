-- make sure you setup a .pgpass file and HYPER_PG_CONN env variable
-- (see README.md#install for instructions on how to setup postgreSQL)

local mytester
local testSchema = 'hypero_test'
local htest = {}

function htest.Postgres()
   local dbconn = hypero.Postgres()
   local res = dbconn:execute([[
   DROP SCHEMA IF EXISTS %s CASCADE;
   CREATE SCHEMA %s; 
   ]], {testSchema, testSchema})
   mytester:assert(testSchema, "Postgres schema err")
   
   local res, err = dbconn:execute([[
   CREATE TABLE %s.test5464 ( n INT4, v FLOAT4, s TEXT );
   ]], {testSchema})
   mytester:assert(res, "Postgres create table err")
   res, err = dbconn:fetchOne("SELECT * FROM %s.test5464", testSchema)
   mytester:assert(_.isEmpty(res), "Postgres select empty table err")
   
   local param_list = {
      {5, 4.1, 'asdfasdf'},
      {6, 3.5, 'asdfashhd'},
      {6, 3.7, 'asdfashhd2'}
   }
   res, err = dbconn:executeMany(
      string.format([[
         INSERT INTO %s.test5464 VALUES (%s, %s, '%s');]], 
      testSchema, '%s', '%s', '%s'), param_list)
   mytester:assertTableEq(res, {1,1,1}, "Postgres insert many err")
   
   res, err = dbconn:fetch([[
   SELECT * FROM %s.test5464 WHERE n = 6
   ]], {testSchema})
   mytester:assert(torch.type(res) == 'table')
   mytester:assert(#res == 2, "Postgres select serialize err")
   mytester:assert(#res[1] == 3, "Postgres missing columns err")
   
   -- test serialization/deserialization of postgres object
   local dbconn_str = torch.serialize(dbconn)
   dbconn = torch.deserialize(dbconn_str)
   
   local res, err = dbconn:execute([[
   CREATE TABLE %s.test5464 ( n INT4, v FLOAT4, s TEXT );
   ]], {testSchema})
   mytester:assert(res == nil and err, "Postgres serialize table exist err")
   res, err = dbconn:fetchOne("SELECT * FROM %s.test5464", testSchema)
   mytester:assert(torch.type(res) == 'table', "Postgres serialize select table err")
   mytester:assert(#res == 3, "Postgres serialize select table err")
   
   res, err = dbconn:executeMany(
      string.format([[
         INSERT INTO %s.test5464 VALUES (%s, %s, '%s');]], 
      testSchema, '%s', '%s', '%s'), param_list)
   mytester:assertTableEq(res, {1,1,1}, "Postgres serialize insert many err")
   
   res, err = dbconn:fetch([[
   SELECT * FROM %s.test5464 WHERE n = 6
   ]], {testSchema})
   mytester:assert(torch.type(res) == 'table')
   mytester:assert(#res == 4, "Postgres select serialize err")
   mytester:assert(#res[1] == 3, "Postgres missing columns err")
   
   dbconn:close()
end

function htest.Connect()
   local dbconn = hypero.Postgres()
   local res, err = dbconn:execute("DROP SCHEMA IF EXISTS %s CASCADE", testSchema)
   mytester:assert(res, "DROP SCHEMA error")
   res, err = dbconn:execute("SELECT * FROM %s.battery", testSchema)
   mytester:assert(not res, "Connect DROP SCHEMA not dropped err")
   dbconn:close()
   local conn = hypero.connect{schema=testSchema}
   res, err = conn:execute("SELECT * FROM %s.battery", testSchema)
   mytester:assert(res, "Connect battery TABLE err")
   res, err = conn:execute("SELECT * FROM %s.version", testSchema)
   mytester:assert(res, "Connect version TABLE err")
   res, err = conn:execute("SELECT * FROM %s.experiment", testSchema)
   mytester:assert(res, "Connect experiment TABLE err")
   res, err = conn:execute("SELECT * FROM %s.param", testSchema)
   mytester:assert(res, "Connect param TABLE err")
   res, err = conn:execute("SELECT * FROM %s.metadata", testSchema)
   mytester:assert(res, "Connect metadata TABLE err")
   res, err = conn:execute("SELECT * FROM %s.result", testSchema)
   mytester:assert(res, "Connect result TABLE err")
   conn:close()
end

function htest.Battery()
   
end

function htest.Experiment()

end

function hypero.test(tests)
   math.randomseed(os.time())
   mytester = torch.Tester()
   mytester:add(htest)
   mytester:run(tests)   
   return mytester
end
