local mytester
local htest = {}

function htest.Postgres()

end

function htest.Connect()
   local conn = hypero.connect{schema='hypero_test'}
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
