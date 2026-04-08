-- Really basic stats module so I can check stuff like map hit-rate and whatever else I may throw in here

local statKeys = {
	LookupMap_Hits   = 0,
	LookupMap_Misses = 0
}

local m = {}

function m.output(self)
	print("=== Writing Stats ===")
	for k, _ in pairs(statKeys) do
		print("\t" .. k, m[k])
	end
end

function m.reset(self)
	for k, default in pairs(statKeys) do
		m[k] = default
	end
end

function m.inc(self, key)
	self[key] = self[key] + 1
end

m:reset()

return m