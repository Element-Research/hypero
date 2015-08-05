# hypero
Hyper-optimization library for torch7

Connect to the database server :
```lua
hp = require 'hypero'

conn = hp.connect{database='localhost', username='nicholas'}
```

Define a new battery of experiments to run :
```lua
bat = conn:battery("RNN Visual Attenion", 3, "fixed bug in Sequencer")
```
This allows you to group your experiments by name (in this case "RNN Visual Attention") 
and to keep track of the different versions of the code you are using.
The last argument is a description of the changes you made to the last version of code to obtain the new one.
Each unique tuple of `(name, version, version-description)` is associated to its own primate key in the database.
So you can run a battery of experiments from different scripts, processes, threads, etc.

This battery can be used to instantiate new hyper-experiments :
```lua
hex = bat:experiment()
```

Now we can use the Sample some hyper-parameters :
```lua
opt.learningRate = hex:logUniform("lr", 0.00001, 0.1)
opt.lrDecay = hex:categorical("lr decay", {[0.8] = "linear", [0.2] = "adaptive"})
if opt.lrDecay == 'linear' then
	opt.minLR = hex:logUniform("min lr", opt.learninRate/1000, opt.learningRate/10)
	opt.saturateEpoch = hex:normal("saturate", 600, 200)
else
	...
end
...
```
Hyper-parameters are sampled one at a time. This keeps the code pretty simple. 
The first argument to the sampling functions are the name of the hyper-parameter 
as it will be saved in the database. These names will also be used as 
columns when retreving the data as a table.

You can also log cmd-line arguments that you would like to see included in the database:
```lua
hex:insertVarHP("channel", unpack(opt.channelSize))
hex:insertVarHP("hidden", unpack(opt.hiddenSize))
hex:insertHP("bs", opt.batchSize)
```

Run an experiment using the sampled hyper-parameters (we use dp here as an example; you can use whatever you want).
```lua
xp = buildExperiment(opt)
xp:run(ds)
```

Then we need to update the server with the experiment's results :
```lua
hex:updateMaxima(trainAccuracy, validAccuracy, testAccuracy)
hex:updateLearningCurve(trainCurve, validCurve, testCurve)
```

If you are motivated, you can also log a much of other metadata for you experiment:
```lua
hex:updateName(xp:name())
hex:updateHostname(dp.hostname())
hex:updateDataset(torch.type(ds))
hex:updatePreprocess("Standardize")
hex:updateSavepath(paths.concat(dp.SaveDir,dp:name()..'.dat'))
```

You can encapsulate this process in a for loop to sample multiple experiments :
```lua
for i=1,opt.nHex do
	hex = conn:experiment("RNN Visual Attenion", 3, "fixed bug in Sequencer")
	opt.learningRate = hex:logUniform("lr", 0.00001, 0.1)
	opt.lrDecay = hex:categorical("lr decay", {[0.8] = "linear", [0.2] = "adaptive"})
	...
	hex:updateMaxima(trainAccuracy, validAccuracy, testAccuracy)
	hex:updateLearningCurve(trainCurve, validCurve, testCurve)
end
```

You can view the results of your experiments using either the query API or our scripts.
The scripts make it easy to common things like view the learning curves of specific experiments, 
generate a .csv file, order you experiments by results, etc.
