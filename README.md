# hypero
Hyper-optimization library for torch7

Connect to the database server :
```lua
hp = require 'hypero'

conn = hp.connect{database='localhost', username='nicholas'}
```

Define a new battery of experiments to run :
```lua
bat = conn:battery("RNN Visual Attenion", "fixed bug in Sequencer")
```
This allows you to group your experiments by name (in this case "RNN Visual Attention") 
and to keep track of the different versions of the code you are using.
The last argument is a description of the changes you made to the last version of code to obtain the new one.
Each unique tuple of `(battery-name, version-description)` is associated to its own primate key in the database.
So you can run a battery of experiments from different scripts, processes, threads, etc.

This battery can be used to instantiate new hyper-experiments :
```lua
hex = bat:experiment()
```

Now we can use `hex` to sample some hyper-parameters :
```lua
opt.learningRate = hex:logUniform("lr", math.log(0.00001), math.log(0.1))
opt.lrDecay = hex:categorical("lr decay", {[0.8] = "linear", [0.2] = "adaptive"})
if opt.lrDecay == 'linear' then
	opt.minLR = hex:logUniform("min lr", math.log(opt.learninRate/1000), math.log(opt.learningRate/10))
	opt.saturateEpoch = hex:normal("saturate", 600, 200)
else
	...
end
...
```
Hyper-parameters are sampled one at a time. This keeps the code pretty-simple. 
The first argument to the sampling functions are the name of the hyper-parameter 
as it will be saved in the database. These names will also be used as 
columns when later retreving the data as a table.

You can also log cmd-line arguments that you would like to see included in the database:
```lua
hex:hyperParam("channel", opt.channelSize)
hex:hyperParam("hidden", opt.hiddenSize)
hex:hyperParam("bs", opt.batchSize)
```

Build and run an experiment using the sampled hyper-parameters (we use dp here as an example; you can use whatever you want).
```lua
xp = buildExperiment(opt)
xp:run(ds)
```

Then we need to update the server with the experiment's results :
```lua
hex:resultMaxima(trainAccuracy, validAccuracy, testAccuracy)
hex:resultLearningCurve(trainCurve, validCurve, testCurve)
```

If you are motivated or just like to keep a log of everything, 
you can also keep track of a bunch of metadata for you experiment:
```lua
hex:metaName(xp:name())
hex:metaHostname(dp.hostname())
hex:metaDataset(torch.type(ds))
hex:metaSavepath(paths.concat(dp.SaveDir,dp:name()..'.dat'))
```
which is equalivalent to :
```lua
hex:metaData('name', xp:name())
hex:metaData('hostname', dp.hostname())
hex:metaData('dataset', torch.type(ds))
hex:metaData('savepath', paths.concat(dp.SaveDir,dp:name()..'.dat'))
```

You can encapsulate this process in a for loop to sample multiple experiments :
```lua
for i=1,opt.nHex do
	hex = conn:experiment("RNN Visual Attenion", 3, "fixed bug in Sequencer")
	opt.learningRate = hex:logUniform("lr", math.log(0.00001), math.log(0.1))
	opt.lrDecay = hex:categorical("lr decay", {[0.8] = "linear", [0.2] = "adaptive"})
	...
	hex:updateMaxima(trainAccuracy, validAccuracy, testAccuracy)
	hex:updateLearningCurve(trainCurve, validCurve, testCurve)
end
```

You can view the results of your experiments using either the query API or our scripts.
The scripts make it easy to do common things like view the learning curves of specific experiments, 
generate a .csv file, order you experiments by results, etc.

## Installation 

You will need postgresql:
```bash
sudo apt-get install postgresql
sudo apt-get install libpq-dev
sudo luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql
```

Setup a user account and a database:
```bash
sudo su postgres
psql postgres
postgres=# CREATE USER "hypero" WITH ENCRYPTED PASSWORD 'mysecretpassword';
postgres=# CREATE DATABASE hypero;
postgres=# GRANT ALL ON DATABASE hypero TO hypero;
postgres=# \q
exit
```
where you should replace `mysecretpassword` with your own. 
Then you should be able to login using those credentials :
```bash
psql -U hypero -W -h localhost hypero
Password for user hypero: 
hypero=>
```
Now let's setup the server so that you can connect to it from any host using your username.
You will need to add a line to `pg_hba.conf` file and change the `listen_addresses` value of 
`postgresql.conf` file (replace 9.3 with your postgresql version):
```bash
$ sudo su postgres
$ vim  /etc/postgresql/9.3/main/pg_hba.conf 
host    all             hypero        all                md5
$ vim /etc/postgresql/9.3/main/postgresql.conf
...
#------------------------------------------------------------------------------
# CONNECTIONS AND AUTHENTICATION
#------------------------------------------------------------------------------

# - Connection Settings -

listen_addresses = '*'
...
$ sudo service postgresql restart
```
These changes basically allow any host supplying the correct credentials (username and password) to 
connect to the database which listens on port 5432 of all IP addresses of the server.
If you want to make the system more secure (i.e. strict), 
you can consult the postgreSQL documentation for each of those files. 
To test out the changes, you can ssh to a different host and try to login from there. 
Supposing we setup our postgresql server on host 192.168.1.3 and that we ssh to 192.168.1.2 : 
```bash
$ ssh username@192.168.1.2
$ sudo apt-get install postgresql-client
$ psql -U hypero -W -h 192.168.1.3 hypero
Password for user hypero: 
hypero=>
```
Now every time we login, we need to supply a password. 
However, postgresql provides a simple facility for storing passwords on disk.
We need only store a connection string in a `.pgpass` file located at the home directory:
```bash
$ vim ~/.pgpass
192.168.1.3:5432:*:hypero:mysecretpassword
$ chmod og-rwx .pgpass
```
The `chmod` command is to keep other users from viewing your connection string.
So now we can login to the database without requiring any password :
```bash
$ psql -U hypero -h 192.168.1.3 hypero
hypero=> \q
```
You should create and secure such a `.pgpass` file for each host 
that will need to connect to the hypero database server. 
If will make your code that much more secure. Otherwise, you would 
need to pass around the username and password within your code.
