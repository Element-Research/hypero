require 'dp'
require 'hypero'

--[[command line arguments]]--

cmd = torch.CmdLine()
cmd:text()
cmd:text('MNIST dataset Image Classification using MLP Training')
cmd:text('Example:')
cmd:text('$> th neuralnetwork.lua --batchSize 128 --momentum 0.5')
cmd:text('Options:')
cmd:option('--batteryName', 'hypero neural network example', "name of battery of experiments to be run")
cmd:option('--maxHex', 100, 'maximum number of hyper-experiments to train (from this script)')
cmd:option('--preprocess', "{16,2,1,1}", "preprocessor (or distribution thereof)"
cmd:option('--startLR', '{0.001,1}', 'learning rate at t=0 (log-uniform {log(min), log(max)})')
cmd:option('--minLR', '{0.001,1}', 'minimum LR = minLR*startLR (log-uniform {log(min), log(max)})')
cmd:option('--satEpoch', '{300, 150}', 'epoch at which linear decayed LR will reach minLR*startLR (normal {mean, std})')
cmd:option('--maxOutNorm', '{1,3,4,2}', 'max norm each layers output neuron weights (categorical)')
cmd:option('--momentum', '{4,4,2}', 'momentum (categorical)')
cmd:option('--hiddenDepth', '{0,7}', 'number of hidden layers (log-uniform {log(min), log(max)})')
cmd:option('--hiddenSize', '{128,1024}', 'number of hidden units per layer (log-uniform {log(min), log(max)})')
cmd:option('--batchSize', '{1,4,1}', 'number of examples per batch (categorical)')
cmd:option('--extra' '{1,1,1}', 'apply nothing, dropout or batchNorm (categorical)')
cmd:option('--cuda', false, 'use CUDA')
cmd:option('--useDevice', 1, 'sets the device (GPU) to use')
cmd:option('--maxEpoch', 500, 'maximum number of epochs to run')
cmd:option('--maxTries', 50, 'maximum number of epochs to try to find a better local minima for early-stopping')
cmd:option('--progress', false, 'display progress bar')
cmd:option('--silent', false, 'dont print anything to stdout')
cmd:text()
hopt = cmd:parse(arg or {})
hopt.schedule = dp.returnString(hopt.schedule)
hopt.preprocess = dp.returnString(hopt.preprocess)
hopt.startLR = dp.returnString(hopt.startLR)
hopt.minLR = dp.returnString(hopt.minLR)
hopt.hiddenSize = dp.returnString(hopt.hiddenSize)
hopt.hiddenDepth = dp.returnString(hopt.hiddenDepth)

hopt.versionDesc = "Neural Network v1"

--[[hypero]]--

conn = hypero.connect()
bat = conn:battery(hopt.batteryName, hopt.versionDesc)
hs = hypero.Sampler()

-- this allows the hyper-param sampler to be bypassed via cmd-line
function ntbl(param)
   return torch.type(param) ~= 'table' and param
end


-- loop over experiments
for i=1,opt.maxHex do
   collectgarbage()
   local hex = bat:experiment()
   local opt = _.clone(hopt) 
   
   --[[hyper-parameters]]--
   local hp = {}
   hp.preprocess = ntbl(opt.preprocess) or hs:categorical(opt.preprocess, {'', 'lcn', 'std', 'zca'})
   hp.startLR = ntbl(opt.startLR) or hs:logUniform(math.log(opt.startLR[1]), math.log(opt.startLR[2]))
   hp.minLR = (ntbl(opt.minLR) or hs:logUniform(math.log(opt.minLR[1]), math.log(opt.minLR[2])))*hp.startLR
   hp.satEpoch = ntbl(opt.satEpoch) or hs:normal(unpack(opt.satEpoch))
   hp.momentum = ntbl(opt.momentum) or hs:categorical(opt.momentum, {0,0.9,0.95})
   hp.maxOutNorm = ntbl(opt.maxOutNorm) or hs:categorical(opt.maxOutNorm, {0,1,2,4})
   hp.hiddenDepth = ntbl(opt.hiddenDepth) or hs:randint(unpack(opt.hiddenDepth))
   hp.hiddenSize = ntbl(opt.hiddenSize) or hs:logUniform(math.log(opt.hiddenSize[1]), math.log(opt.hiddenSize[2]))
   hp.batchSize = ntbl(opt.batchSize) or hs:categorical(opt.batchSize, {16,32,64})
   hp.extra = ntbl(opt.extra) or hs:categorical(opt.extra, {'none','dropout','batchnorm'})
   
   hex:hyperParam(hp)
   
   
   if not opt.silent then
      table.print(opt)
   end

   --[[preprocessing]]--

   local input_preprocess = {}
   if opt.preprocess == 'std' then
      table.insert(input_preprocess, dp.Standardize())
   elseif opt.preprocess == 'zca' then
      table.insert(input_preprocess, dp.ZCA())
   elseif opt.preprocess == 'lcn' then
      table.insert(input_preprocess, dp.GCN())
      table.insert(input_preprocess, dp.LeCunLCN{progress=true})
   elseif opt.preprocess then
      error("unknown preprocess : "..opt.preprocess) 
   end

   --[[data]]--

   local ds = torch.checkpoint(
      paths.concat(dp.DATA_DIR,"checkpoint","mnist_"..opt.preprocess..".t7"),
      function() 
         return dp.Mnist{input_preprocess = input_preprocess} 
      end)


   --[[Model]]--

   local model = nn.Sequential()
   model:add(nn.Convert(ds:ioShapes(), 'bf')) -- to batchSize x nFeature (also type converts)

   -- hidden layers
   inputSize = ds:featureSize()

   for i=1,opt.hiddenDepth do
      model:add(nn.Linear(inputSize, opt.hiddenSize)) -- parameters
      if opt.extra == 'batchNorm' then
         model:add(nn.BatchNormalization(hiddenSize))
      end
      model:add(nn.Tanh())
      if opt.extra == 'dropout' then
         model:add(nn.Dropout())
      end
      inputSize = hiddenSize
   end

   -- output layer
   model:add(nn.Linear(inputSize, #(ds:classes())))
   model:add(nn.LogSoftMax())


   --[[Propagators]]--

   -- linear decay
   opt.decayFactor = (opt.minLR - opt.learningRate)/opt.satEpoch

   local train = dp.Optimizer{
      acc_update = opt.accUpdate,
      loss = nn.ModuleCriterion(nn.ClassNLLCriterion(), nil, nn.Convert()),
      epoch_callback = function(model, report) -- called every epoch
         -- learning rate decay
         if report.epoch > 0 then
            opt.learningRate = opt.learningRate + opt.decayFactor
            opt.learningRate = math.max(opt.minLR, opt.learningRate)
            if not opt.silent then
               print("learningRate", opt.learningRate)
            end
         end
      end,
      callback = function(model, report) -- called for every batch
         if opt.accUpdate then
            model:accUpdateGradParameters(model.dpnn_input, model.output, opt.learningRate)
         else
            model:updateGradParameters(opt.momentum) -- affects gradParams
            model:updateParameters(opt.learningRate) -- affects params
         end
         model:maxParamNorm(opt.maxOutNorm) -- affects params
         model:zeroGradParameters() -- affects gradParams 
      end,
      feedback = dp.Confusion(),
      sampler = dp.ShuffleSampler{batch_size = opt.batchSize},
      progress = opt.progress
   }
   local valid = dp.Evaluator{
      feedback = dp.Confusion(),  
      sampler = dp.Sampler{batch_size = opt.batchSize}
   }
   local test = dp.Evaluator{
      feedback = dp.Confusion(),
      sampler = dp.Sampler{batch_size = opt.batchSize}
   }

   --[[Experiment]]--

   local xp = dp.Experiment{
      model = model,
      optimizer = train,
      validator = valid,
      tester = test,
      observer = {
         dp.FileLogger(),
         dp.EarlyStopper{
            error_report = {'validator','feedback','confusion','accuracy'},
            maximize = true,
            max_epochs = opt.maxTries
         }
      },
      random_seed = os.time(),
      max_epoch = opt.maxEpoch
   }

   --[[GPU or CPU]]--

   if opt.cuda then
      require 'cutorch'
      require 'cunn'
      cutorch.setDevice(opt.useDevice)
      xp:cuda()
   end

   xp:verbose(not opt.silent)
   if not opt.silent then
      print"Model :"
      print(model)
   end

   xp:run(ds)
end
