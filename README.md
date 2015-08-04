# hypero
Hyper-optimization library for torch7

Connect to the database server :
```lua
hp = require 'hypero'

conn = hp.connect{database='localhost', username='nicholas'}
```

Define a search space:
```lua
space = hp.choice{
      hp.lognormal('c1', 0, 1)),
      hp.uniform('c2', -10, 10)
    }
```
