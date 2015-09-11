# Installation 

This section explains how to setup the hypero server and client(s).

## Server

You will need postgresql:

```bash
$ sudo apt-get install postgresql libpq-dev
$ luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql
```

Setup a user account and a database:

```bash
$ sudo su postgres
$ psql postgres
postgres=# CREATE USER "hypero" WITH ENCRYPTED PASSWORD 'mysecretpassword';
postgres=# CREATE DATABASE hypero;
postgres=# GRANT ALL ON DATABASE hypero TO hypero;
postgres=# \q
exit
```

where you should replace `mysecretpassword` with your own super secret password. 
Then you should be able to login using those credentials :

```bash
psql -U hypero -W -h localhost hypero
Password for user hypero: 
hypero=> \q
```

Now let's setup the server so that you can connect to it from any host using your username.
You will need to add a line to `pg_hba.conf` file and change the `listen_addresses` value of 
`postgresql.conf` file (below, replace 9.3 with your postgresql version):

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
$ service postgresql restart
$ exit
```

These changes basically allow any host supplying the correct credentials (username and password) to 
connect to the database which listens on port 5432 of all IP addresses of the server.
If you want to make the system more secure (i.e. strict), 
you can consult the postgreSQL documentation for each of those files. 

To test out the changes, you can ssh to a different host and try to login from there. 
Supposing we setup our postgresql server on host `192.168.1.3` and that we ssh to `192.168.1.2` : 

```bash
$ ssh username@192.168.1.2
$ sudo apt-get install postgresql-client
$ psql -U hypero -W -h 192.168.1.3 hypero
Password for user hypero: 
hypero=> \q
```

## Client(s) 

At this point, every time we login, we need to supply a password. 
However, postgresql provides a simple facility for storing passwords on disk.
We need only store a connection string in a `.pgpass` file located at the home directory:

```bash
$ vim ~/.pgpass
192.168.1.3:5432:*:hypero:mysecretpassword
$ chmod og-rwx ~/.pgpass
```

The `chmod` command is to keep other users from viewing your connection string.
So now we can login to the database without requiring any password :

```bash
$ psql -U hypero -h 192.168.1.3 hypero
hypero=> \q
```

You should create and secure such a `.pgpass` file for each client host 
that will need to connect to the hypero database server. 
It will make your code that much more secure. Otherwise, you would 
need to pass around the username and password within your code (bad).

Next it's time to install hypero and its dependencies :

```
$ sudo apt-get install libpq-dev
$ luarocks install luasql-postgres PGSQL_INCDIR=/usr/include/postgresql
$ luarocks install https://raw.githubusercontent.com/Element-Research/hypero/master/rocks/hypero-scm-1.rockspec
```

The final step is to define the `HYPER_PG_CONN` environment variable in your `.bashrc` file:

```
$ vim ~/.bashrc
export HYPER_PG_CONN="dbname=hypero user=hypero host=192.168.1.3"
$ source ~/.bashrc 
```

Replace these with your database credentials (the `host` is the IP address of your database).
This will allow you to connect to the database without specifying anything :

```lua
$ th
th> require 'hypero'
th> conn = hypero.connect()
```

That's it.
