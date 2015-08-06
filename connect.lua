local Connect = torch.class("hp.Connect")

function Connect:__init(config)
   self.dbconn = hp.Postgres(config)
end
hp.connect = hp.Connect

function Connect:battery(name, version, description)
   return hp.Battery()
end
