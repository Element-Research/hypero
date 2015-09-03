require 'hypero'
require 'paths'

--[[command line arguments]]--

cmd = torch.CmdLine()
cmd:text()
cmd:text('Export database battery data')
cmd:text('Options:')
cmd:option('--schema', 'hyper', 'SQL schema in databse')
cmd:option('--batteryName', '', "name of battery of experiments to be exported")
cmd:option('--versionDesc', '', 'desc of version to be exported')
cmd:option('--minVer', '', '--versionDesc specifies the minimum version to be exported')
cmd:option('--paramNames', '*', "comma separated list of hyper-param columns to retrieve")
cmd:option('--metaNames', '*', "comma separated list of meta-data columns to retrieve")
cmd:option('--resultNames', '*', "comma separated list of result columns to retrieve")
cmd:option('--format', 'csv', "export format : csv")
cmd:option('--savePath', '', 'for csv format, defaults to [schema].csv')
cmd:option('--orderBy', 'hexId', "order by this result column")
cmd:option('--desc', false, 'order is descending')
cmd:text()
opt = cmd:parse(arg or {})
opt.asc = not opt.desc
assert(opt.batteryName ~= '')

conn = hypero.connect{schema=schema}
bat = conn:battery(opt.batteryName, opt.versionDesc, true, true)

local data, header = bat:exportTable(opt)

if opt.format == 'csv' or opt.format == 'CSV' then
   opt.savePath = opt.savePath == '' and (opt.schema..'.csv') or opt.savePath
   hypero.writecsv(opt.savePath, header, data)
else
   error("Unrecognized export format : "..opt.format)
end
