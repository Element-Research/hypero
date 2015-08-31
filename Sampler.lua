------------------------------------------------------------------------
--[[ Sampler ]]--
-- hyper parameter sampling distributions 
------------------------------------------------------------------------
local Sampler = torch.class("hypero.Sampler")

-- sample from a categorical distribution
function Sampler:categorical(probs, vals)
   assert(torch.type(probs) == 'table', "Expecting table of probabilites, got :"..tostring(probs))
   
   local probs = torch.Tensor(probs)
   local idx = torch.multinomial(probs, 1)[1]
   local val = vals and vals[idx] or idx

   return val
end

-- sample from a normal distribution
function Sampler:normal(mean, std)
   assert(torch.type(mean) == 'number')
   assert(torch.type(std) == 'number')
   
   local val = torch.normal(mean, std)
   
   return val
end

-- sample from uniform distribution
function Sampler:uniform(minval, maxval)
   assert(torch.type(minval) == 'number')
   assert(torch.type(maxval) == 'number')
   
   local val = torch.uniform(minval, maxval)
   
   return val
end

-- Returns a value drawn according to exp(uniform(low, high)) 
-- so that the logarithm of the return value is uniformly distributed.
-- When optimizing, this variable is constrained to the interval [exp(low), exp(high)].
function Sampler:logUniform(minval, maxval)
   assert(torch.type(minval) == 'number')
   assert(torch.type(maxval) == 'number')
   
   local val = torch.exp(torch.uniform(minval, maxval))

   return val
end

-- sample from uniform integer distribution
function Sampler:randint(minval, maxval)
   assert(torch.type(minval) == 'number')
   assert(torch.type(maxval) == 'number')
   
   local val = math.random(minval, maxval)
   
   return val
end 

