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
cmd:option('--learningRate', 0.1, 'learning rate at t=0')
cmd:option('--lrDecay', 'linear', 'type of learning rate decay : adaptive | linear | schedule | none')
cmd:option('--minLR', 0.00001, 'minimum learning rate')
cmd:option('--saturateEpoch', 300, 'epoch at which linear decayed LR will reach minLR')
cmd:option('--schedule', '{}', 'learning rate schedule')
cmd:option('--maxWait', 4, 'maximum number of epochs to wait for a new minima to be found. After that, the learning rate is decayed by decayFactor.')
cmd:option('--decayFactor', 0.001, 'factor by which learning rate is decayed for adaptive decay.')
cmd:option('--maxOutNorm', 1, 'max norm each layers output neuron weights')
cmd:option('--momentum', 0, 'momentum')
cmd:option('--hiddenSize', '', 'number of hidden units per layer')
cmd:option('--batchSize', 32, 'number of examples per batch')
cmd:option('--cuda', false, 'use CUDA')
cmd:option('--useDevice', 1, 'sets the device (GPU) to use')
cmd:option('--maxEpoch', 100, 'maximum number of epochs to run')
cmd:option('--maxTries', 30, 'maximum number of epochs to try to find a better local minima for early-stopping')
cmd:option('--dropout', false, 'apply dropout on hidden neurons')
cmd:option('--batchNorm', false, 'use batch normalization. dropout is mostly redundant with this')
cmd:option('--preprocess', "hex:categorical('preproc', {[8]='',[0.5]='std',[0.5]='zca',[1]='lcn'})", "valid values : 'std' | 'zca' | 'lcn' | dist where dist is a table defining a categorical distribution (see default)"
cmd:option('--progress', false, 'display progress bar')
cmd:option('--silent', false, 'dont print anything to stdout')
cmd:text()
opt = cmd:parse(arg or {})
opt.schedule = dp.returnString(opt.schedule)
opt.hiddenSize = dp.returnString(opt.hiddenSize)
opt.preprocess = dp.returnString(opt.preprocess)
if not opt.silent then
   table.print(opt)
end

opt.versionDesc = "Neural Network v1"

--[[hypero]]--

conn = hypero.connect()
bat = conn:battery(opt.batteryName, opt.versionDesc)
hex = bat:experiment()

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

ds = torch.checkpoint(
   paths.concat(dp.DATA_DIR,"checkpoint","mnist_"..opt.preprocess..".t7"),
   function() 
      return dp.Mnist{input_preprocess = input_preprocess} 
   end)


--[[Model]]--

model = nn.Sequential()
model:add(nn.Convert(ds:ioShapes(), 'bf')) -- to batchSize x nFeature (also type converts)

-- hidden layers
inputSize = ds:featureSize()

opt.hiddenDepth = hex:randint("hd.",0,7)
opt.hiddenSize = hex:logUniform("hs.", math.log(128), math.log(1024))

for i=1,opt.hiddenDepth do
   model:add(nn.Linear(inputSize, opt.hiddenSize)) -- parameters
   if opt.batchNorm then
      model:add(nn.BatchNormalization(hiddenSize))
   end
   model:add(nn.Tanh())
   if opt.dropout then
      model:add(nn.Dropout())
   end
   inputSize = hiddenSize
end

-- output layer
model:add(nn.Linear(inputSize, #(ds:classes())))
model:add(nn.LogSoftMax())


--[[Propagators]]--
if opt.lrDecay == 'adaptive' then
   ad = dp.AdaptiveDecay{max_wait = opt.maxWait, decay_factor=opt.decayFactor}
elseif opt.lrDecay == 'linear' then
   opt.decayFactor = (opt.minLR - opt.learningRate)/opt.saturateEpoch
end

train = dp.Optimizer{
   acc_update = opt.accUpdate,
   loss = nn.ModuleCriterion(nn.ClassNLLCriterion(), nil, nn.Convert()),
   epoch_callback = function(model, report) -- called every epoch
      -- learning rate decay
      if report.epoch > 0 then
         if opt.lrDecay == 'adaptive' then
            opt.learningRate = opt.learningRate*ad.decay
            ad.decay = 1
         elseif opt.lrDecay == 'schedule' and opt.schedule[report.epoch] then
            opt.learningRate = opt.schedule[report.epoch]
         elseif opt.lrDecay == 'linear' then 
            opt.learningRate = opt.learningRate + opt.decayFactor
         end
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
valid = dp.Evaluator{
   feedback = dp.Confusion(),  
   sampler = dp.Sampler{batch_size = opt.batchSize}
}
test = dp.Evaluator{
   feedback = dp.Confusion(),
   sampler = dp.Sampler{batch_size = opt.batchSize}
}

--[[Experiment]]--

xp = dp.Experiment{
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
