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
   local dbconn = hypero.Postgres()
   local res, err = dbconn:execute("DROP SCHEMA IF EXISTS %s CASCADE", testSchema)
   mytester:assert(res, "DROP SCHEMA error")
   local conn = hypero.connect{schema=testSchema,dbconn=dbconn}
   local batName = "Test 22"
   local bat = conn:battery(batName, verDesc, false)
   mytester:assert(bat.id == '1', "Battery id err")
   mytester:assert(bat.verId == '1', "Battery verId err")
   mytester:assert(bat.verDesc == "Initial battery version")
   local verDesc = "Version 33"
   local verId2, verDesc2 = bat:version(verDesc)
   mytester:assert(verId2 == '2', "Battery version() id err")
   mytester:assert(verDesc2 == verDesc, "Battery version() desc err")
   local bat = conn:battery(batName, verDesc, false)
   mytester:assert(bat.id == '1', "Battery id err")
   mytester:assert(bat.verId == '2', "Battery verId err")
   res, err = conn:fetchOne("SELECT COUNT(*) FROM %s.battery", testSchema)
   mytester:assert(res, err)
   mytester:assert(res[1] == '1')
   res, err = conn:fetchOne("SELECT COUNT(*) FROM %s.version", testSchema)
   mytester:assert(res, err)
   mytester:assert(res[1] == '2')
   conn:close()
end

function htest.Experiment()
   local dbconn = hypero.Postgres()
   local res, err = dbconn:execute("DROP SCHEMA IF EXISTS %s CASCADE", testSchema)
   mytester:assert(res, "DROP SCHEMA error")
   local conn = hypero.connect{schema=testSchema,dbconn=dbconn}
   local batName = "Test 23"
   local bat = conn:battery(batName, verDesc, false)
   local hex = bat:experiment()
   mytester:assert(hex.id == '1')
   res, err = conn:fetchOne("SELECT COUNT(*) FROM %s.experiment", testSchema)
   mytester:assert(res, err)
   mytester:assert(res[1] == '1')
   local hex = hypero.Experiment(conn, 1)
   mytester:assert(hex.id == '1')
   res, err = conn:fetchOne("SELECT COUNT(*) FROM %s.experiment", testSchema)
   mytester:assert(res, err)
   mytester:assert(res[1] == '1')
   local success = pcall(function() return hypero.Experiment(2) end)
   mytester:assert(not success)
   
   -- hyperParam
   hex:hyperParam("lr", 0.0001)
   local res, err = conn:fetchOne([[
   SELECT param_val FROM %s.param WHERE (hex_id, param_name) = (%s, '%s')
   ]], {testSchema, hex.id, "lr"})
   mytester:assert(res[1] == '0.0001')
   local val = hex:hyperParam("lr")
   mytester:assert(val == 0.0001)
   mytester:assert(not pcall(function() return hex:hyperParam("lr", 0.01) end))
   hex:hyperParam("lr", 0.01, true)
   local val = hex:hyperParam("lr")
   mytester:assert(val == 0.01)
   
   -- metaData
   hex:metaData("hostname", 'bobby')
   local res, err = conn:fetchOne([[
   SELECT meta_val FROM %s.metadata WHERE (hex_id, meta_name) = (%s, '%s')
   ]], {testSchema, hex.id, "hostname"})
   mytester:assert(res[1] == '"bobby"')
   local val = hex:metaData("hostname")
   mytester:assert(val == 'bobby')
   mytester:assert(not pcall(function() return hex:metaData("hostname", 'bobby') end))
   hex:metaData("hostname", 'bobby', true)
   local val = hex:metaData("hostname")
   mytester:assert(val == 'bobby')
   
   -- result
   hex:result("valid_acc", 0.0001)
   local res, err = conn:fetchOne([[
   SELECT result_val FROM %s.result WHERE (hex_id, result_name) = (%s, '%s')
   ]], {testSchema, hex.id, "valid_acc"})
   mytester:assert(res[1] == '0.0001')
   local val = hex:result("valid_acc")
   mytester:assert(val == 0.0001)
   mytester:assert(not pcall(function() return hex:result("valid_acc", 0.01) end))
   hex:result("valid_acc", 0.01, true)
   local val = hex:result("valid_acc")
   mytester:assert(val == 0.01)
   
   conn:close()
end

-- export parameters to a CSV file
function htest.ExportCSV()
   local dbconn = hypero.Postgres()
   local res, err = dbconn:execute("DROP SCHEMA IF EXISTS %s CASCADE", testSchema)
   mytester:assert(res, "DROP SCHEMA error")
   local conn = hypero.connect{schema=testSchema,dbconn=dbconn}
   local batName = "Test 23"
   local bat = conn:battery(batName, verDesc, true)
   local nExperiment = 10
   
   for i=1,nExperiment do
      local hex = bat:experiment()
      
      -- hyperParam
      hex:hyperParam("lr", 0.0001)
      hex:hyperParam("momentum", 0.9)
      
      -- metaData
      hex:metaData("hostname", 'bobby')
      
      -- result
      hex:result("valid_acc", 0.0001)
   end

   -- get battery versions
   local verIds, err = bat:fetchVersions()
   print("got battery versions", verIds, err)

   -- get all hyper pamameter names
   for i=1,#verIds do
      local verId = verIds[i][1]
      print('get experiment for version id', verId)
      local hexIds = bat:fetchExperiments(verId, batId)
      print('experiments', hexIds)
   end
   
   conn:close()
end

function hypero.test(tests)
   math.randomseed(os.time())
   mytester = torch.Tester()
   mytester:add(htest)
   mytester:run(tests)   
   return mytester
end
