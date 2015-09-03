# Tutorial

This is a brief tutorial on how to use *hypero*.

## Connect

Let's start off by connecting to the database server :
```lua
hp = require 'hypero'
conn = hp.connect{database='localhost', username='nicholas'}
```

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

## Query

You can view the results of your experiments using either the query API or our scripts.
The scripts make it easy to do common things like view the learning curves of specific experiments, 
generate a .csv file, order you experiments by results, etc.
