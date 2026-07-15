-- Really basic stats module so I can check stuff like map hit-rate and whatever else I may throw in here
local featureCheck   = require(script.Parent.Parent.Util.FeatureCheck)
local versionConfig  = require(script.Parent.Parent.Util.VersionConfig)
local writePrimitive = require(script.Parent.WritePrimitive)
local writeEnum      = require(script.Parent.WriteEnum)
local readPrimitive  = require(script.Parent.Parent.Reading.ReadPrimitive)

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

local compare = function(v1, v2)
	local v1t = typeof(v1)
	local v2t = typeof(v2)
	if v1t ~= v2t then error(`Critical error {v1t} ~= {v2t}`) end
	
	if v1t == "CFrame" or v1t == "Vector3" or v1t == "Vector2" then
		return v1:FuzzyEq(v2, 0.001)
	elseif v1t == "number" then
		return math.abs(v1 - v2) <= 0.001
	else
		return v1 == v2
	end
end

local signed_int_bound = math.floor((math.pow(72, 3) - 1) / 2)
local testData = {
	Bool              = { true, false },
	ShortestInt       = { 0, 71 },
	ShortInt          = { 0, math.pow(72, 2)-1 },
	Int               = { 0, math.pow(72, 4)-1 },
	LongInt           = { 0, math.pow(72, 6)-1 },
	SignedInt         = { -signed_int_bound, 0, signed_int_bound },
	Float             = { -signed_int_bound, 0, signed_int_bound },
	FloatSequence     = { NumberSequence.new(0, 1) },
	FloatRange        = false, -- Vector2 Wrapper, doesn't need tests
	Vector2           = { Vector2.new(-signed_int_bound, -signed_int_bound), Vector2.zero, Vector2.one, Vector2.new(signed_int_bound, signed_int_bound), Vector2.new(-signed_int_bound, signed_int_bound) },
	Vector3           = { Vector3.zero, Vector3.one, Vector3.one * signed_int_bound, Vector3.one * -signed_int_bound },
	UDim              = false, -- Vector2 Wrapper
	UDim2             = { UDim2.new(1, 0, 1, 0) },
	CFrame            = { CFrame.new() },
	BoundedFloat      = { 0, 1 },
	ShortBoundedFloat = { 0, 1 },
	Color3            = { Color3.fromHex('000000'), Color3.fromHex('FFFFFF') },
	ColorSequence     = { ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex('000000')), ColorSequenceKeypoint.new(1, Color3.fromHex('FFFFFF')) }) },
	String            = { "This is a test", "Hello, World!", "", "This\nstring\nhas\tfancy\tformatting!" },
	InstanceReference = false, -- Genuinely how would you test this?
}

if featureCheck("SerializerDebug", false) ~= true then return m end

for k, writer in pairs(writePrimitive) do
	if writeEnum[k] ~= nil then continue end -- Skip enums
	local allPassed = true
	for i=0, versionConfig.LatestVersion do
		versionConfig:change_version(i)
		local versionPassed = true
		
		local primTestData = testData[k]
		if primTestData == false then continue end
		if primTestData == nil then
			warn(`Writable datatype {k} has no test data, add some before submitting!`)
			continue
		end
		
		local reader = readPrimitive[k]
		if reader == nil then
			warn(`No Read implementation found for writable datatype {k} - potential error?`)
			continue
		end
		
		local passed = true
		for _, d in ipairs(primTestData) do
			local written = writer(d)
			local readback = reader(written, 1)
			if not compare(readback, d) then
				warn(`(v{i}) Read implementation for {k} output {readback} - this does not match the input ({d})`)
				versionPassed = false
				allPassed = false
			end
		end
		
		if versionPassed then
			print(`SerializerDebug : Read/Write tests for {k} on v{i} passed!`)
		end
	end
	if allPassed then
		print(`SerializerDebug : Read/Write tests for {k} passed on all versions!`)
	end
end

return m