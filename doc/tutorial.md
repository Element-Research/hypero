# Tutorial

This is a brief tutorial on how to use *hypero*. 
We demonstrate how the library can be used to log experiments,
sample hyper-parameters, and query the database for analysing results.

## Connect

Let's start off by connecting to the database server :

```lua
require 'hypero'
conn = hypero.connect{database='localhost', username='nicholas'}
```

The `conn` variable is a `Connect` instance.

## Battery 

Define a new `Battery` of experiments to run :

```lua
batName = "RNN Visual Attenion - MNIST"
verDesc = "fixed bug in Sequencer"
battery = conn:battery(batName, verDesc)
```

This allows us to group our experiments into batteries identified by a unique `batName` string. 
We can also optionally keep track of the different versions of the 
code we are using by providing a unique `verDesc` string.
This is usually a description of the changes we made to the last version of code to obtain the new one.
Making changes to our code often influences the results of our experiments,
so it's good practive to log these.

Grouping experiments by battery and version will come in handy later 
when we need to retrieve the results of our experiment (see below).

## Experiment 

Once we have our versionned `battery` defined, we can use it to instantiate new experiments:

```lua
hex = bat:experiment()
```

Think of each such experiment as an entry into the hyper-optimization log.
The experiment log is organized into 3 PostgreSQL tables, where each row is associated to an experiment :
 
  * `param` : hyper-parameters like the learning rate, momentum, learning rate decay, etc.
  * `result` : experimental results like the learning curves or the accuracy (train, valid, test), etc.
  * `meta` : meta-data like the hostname from which the experiment was run, the path to the saved model, etc.

These database tables can be filled with Lua tables. 
For example, given the following Lua tables :

```lua
hp = {startLR = 0.01, momentum = 0.09, lrDecay = 'linear', minLR = 0.0001, satEpoch = 300}
md = {hostname = 'hermes', dataset = 'mnist'}
res = {trainAcc = 0.998, validAcc = 0.876, testAcc = 0.862}
```

Using the `hex` experiment, we can update the respective database tables as follows:

```lua
hex:setParam(hp)
hex:setMeta(md)
hex:setResult(res)
```

Internally, the Lua tables are serialized to a 
[JSON](https://en.wikipedia.org/wiki/JSON) string
and stored in a single column of the database.
This keeps the database schema pretty simple.
The only constraint is that the Lua tables be convertable 
to JSON, so only primitive types like `nil`, `string`, 
`table` and `number` can be nested within the table.

## Sampler 

The above example, we didn't really sample anything. 
That is because the database (i.e. centralized persistent storage) aspect of the 
library was separated from the hyper-parameter sampling.
For sampling, we can basically use whatever we want, 
but hypero provide a `Sampler` object with different sampling distribution methods.
It's doesn't use anything fancy like a Gaussian Process or anything like that.
But if you do a good job of bounding and choosing your distributions, 
you still end up with a really effective *random search*.

Example :

```lua
hs = hypero.Sampler()
hp = {}
hp.preprocess = hs:categorical({0.8,0.1,0.1}, {'', 'lcn', 'std'})
hp.startLR = hs:logUniform(math.log(0.1), math.log(0.00001))
hp.minLR = math.min(hs:logUniform(math.log(0.1)), math.log(0.0001))*hp.startLR, 0.000001)
hp.satEpoch = hs:normal(300, 200)
hp.hiddenDepth = hs:randint(1, 7)
```

What did we create a `Sampler` class for this? 
Well we never know, maybe someday, we will have a Sampler 
subclass that will use a Gaussian Process 
or something to optimize the sampling of hyper-parameters.

Again, if we want to store the hyper-parameters in the database, it's as easy as :

```lua
hex:setParam(hp)
```

## Training Script

If we have a bunch of GPUs or CPUs lying around, we can create 
a training script that loops over different experiments.
Each experiment can be logged into the database using `hypero`.
For a complete example for how this is done, please consult this 
[example training script](../examples/neuralnetwork.lua).
The main part of the script that concerns hypero is this :

```lua
...
-- loop over experiments
for i=1,hopt.maxHex do
   collectgarbage()
   local hex = bat:experiment()
   local opt = _.clone(hopt) 
   
   -- hyper-parameters
   local hp = {}
   hp.preprocess = ntbl(opt.preprocess) or hs:categorical(opt.preprocess, {'', 'lcn', 'std'})
   hp.startLR = ntbl(opt.startLR) or hs:logUniform(math.log(opt.startLR[1]), math.log(opt.startLR[2]))
   hp.minLR = (ntbl(opt.minLR) or hs:logUniform(math.log(opt.minLR[1]), math.log(opt.minLR[2])))*hp.startLR
   hp.satEpoch = ntbl(opt.satEpoch) or hs:normal(unpack(opt.satEpoch))
   hp.momentum = ntbl(opt.momentum) or hs:categorical(opt.momentum, {0,0.9,0.95})
   hp.maxOutNorm = ntbl(opt.maxOutNorm) or hs:categorical(opt.maxOutNorm, {0,1,2,4})
   hp.hiddenDepth = ntbl(opt.hiddenDepth) or hs:randint(unpack(opt.hiddenDepth))
   hp.hiddenSize = ntbl(opt.hiddenSize) or math.round(hs:logUniform(math.log(opt.hiddenSize[1]), math.log(opt.hiddenSize[2])))
   hp.batchSize = ntbl(opt.batchSize) or hs:categorical(opt.batchSize, {16,32,64})
   hp.extra = ntbl(opt.extra) or hs:categorical(opt.extra, {'none','dropout','batchnorm'})
   
   for k,v in pairs(hp) do opt[k] = v end
   
   if not opt.silent then
      table.print(opt)
   end

   -- build dp experiment
   local xp, ds, hlog = buildExperiment(opt)
   
   -- more hyper-parameters
   hp.seed = xp:randomSeed()
   hex:setParam(hp)
   
   -- meta-data
   local md = {}
   md.name = xp:name()
   md.hostname = os.hostname()
   md.dataset = torch.type(ds)
   
   if not opt.silent then
      table.print(md)
   end
   
   md.modelstr = tostring(xp:model())
   hex:setMeta(md)

   -- run the experiment
   local success, err = pcall(function() xp:run(ds) end )
   
   -- results
   if success then
      res = {}
      res.trainCurve = hlog:getResultByEpoch('optimizer:feedback:confusion:accuracy')
      res.validCurve = hlog:getResultByEpoch('validator:feedback:confusion:accuracy')
      res.testCurve = hlog:getResultByEpoch('tester:feedback:confusion:accuracy')
      res.trainAcc = hlog:getResultAtMinima('optimizer:feedback:confusion:accuracy')
      res.validAcc = hlog:getResultAtMinima('validator:feedback:confusion:accuracy')
      res.testAcc = hlog:getResultAtMinima('tester:feedback:confusion:accuracy')
      res.lrs = opt.lrs
      res.minimaEpoch = hlog.minimaEpoch
      hex:setResult(res)
      
      if not opt.silent then
         table.print(res)
      end
   else
      print(err)
   end
end
```

So basically, for each experiment, sample hyper-parameters, 
build and run the experiment, and save the hyper-parameters, 
meta-data and results to the database. 
If we have multiple GPUs/CPUs, we can launch an instance 
of the script for each available GPU/CPU, sit back, relax and 
wait for the results to be logged into the database.
That is assuming your script is bug-free. 
When a bug in the code is uncovered (as it inevitably will be), 
we can just fix it and update the version of the battery before re-running our scripts.

## Query

Assuming our training script(s) has been running for a couple of experiments,
we need a way to query the results from the database. 
We can use the [export script](../scripts/export.lua) to export our results 
to CSV format. Assuming, our battery is called `Neural Network - Mnist` and 
we only care about versions `Neural Network v1` and above, 
we can use the following command to retrieve our results:

```bash
th scripts/export.lua --batteryName 'Neural Network - Mnist' --versionDesc 'Neural Network v1'
```


