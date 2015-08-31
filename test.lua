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
   res, err = conn:execute("SELECT * FROM %s.meta", testSchema)
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
   local hp = {lr=0.0001,mom=0.9}
   hex:setParam(hp)
   local hp2 = hex:getParam()
   mytester:assert(hp2.lr == 0.0001)
   mytester:assert(hp2.mom == 0.9)
   hp.lr = 0.01
   mytester:assert(not pcall(function() return hex:setParam(hp) end))
   hex:setParam(hp, true)
   local hp2 = hex:getParam()
   mytester:assert(hp2.lr == 0.01)
   
   -- metaData
   local md = {hostname='bobby', screen=3463}
   hex:setMeta(md)
   local md2 = hex:getMeta()
   mytester:assert(md2.hostname == 'bobby')
   mytester:assert(md2.screen == 3463)
   md.hostname = 'sonny'
   mytester:assert(not pcall(function() return hex:setMeta(md) end))
   hex:setMeta(md, true)
   local md2 = hex:getMeta()
   mytester:assert(md2.hostname == 'sonny')
   
   -- result
   local res = {valid_acc = 0.0001, test_acc = 0.02}
   hex:setResult(res)
   local res2 = hex:getResult()
   mytester:assert(res2.valid_acc == 0.0001)
   mytester:assert(res2.test_acc == 0.02)
   res.valid_acc = 0.01
   mytester:assert(not pcall(function() return hex:setResult(es) end))
   hex:setResult(res, true)
   local res2 = hex:getResult()
   mytester:assert(res2.valid_acc == 0.01)
   
   conn:close()
end

function htest.Sampler()
   local hs = hypero.Sampler()
   local val = hs:categorical({0.001, 0.0001, 0.0001, 10000}, {1,2,3,4})
   mytester:assert(val == 4, "Sampler err")
   local val = hs:normal(0, 1)
   mytester:assert(torch.type(val) == 'number')
   local val = hs:uniform(0, 1)
   mytester:assert(val >= 0 and val <= 1)
   local val = hs:logUniform(0, 1)
   mytester:assert(val >= math.exp(0) and val <= math.exp(1))
   local val = hs:randint(1,100)
   mytester:assert(math.floor(val) == val)
   mytester:assert(val >= 1 and val <= 100)
end

function hypero.test(tests)
   math.randomseed(os.time())
   mytester = torch.Tester()
   mytester:add(htest)
   mytester:run(tests)   
   return mytester
end
