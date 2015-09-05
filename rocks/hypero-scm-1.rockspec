package = "hypero"
version = "scm-1"

source = {
   url = "git://github.com/Element-Research/hypero",
   tag = "master"
}

description = {
   summary = "A hyper-optimization library for torch7",
   detailed = [[
A simple asynchronous distributed hyper-parameter optimization library for torch7.
It performs random-search of a parameter distribution.
All params, meta-data and results are stored in a PostgreSQL database.
These can be queried and updated using scripts or client APIs.
]],
   homepage = "https://github.com/Element-Research/hypero/blob/master/README.md"
}

dependencies = {
   "torch >= 7.0",
   "moses >= 1.3.1",
   "fs >= 0.3",
   "xlua >= 1.0",
   "luafilesystem >= 1.6.2",
   "sys >= 1.1",
   "torchx >= 1.0",
   "luajson",
   "luasql-postgres"
}

external_dependencies = {
  PGSQL = {
}

build = {
   type = "command",
   build_command = [[
cmake -E make_directory build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="$(LUA_BINDIR)/.." -DCMAKE_INSTALL_PREFIX="$(PREFIX)" && $(MAKE)
   ]],
   install_command = "cd build && $(MAKE) install"
}
