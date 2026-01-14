--[[
	Serializer features may be enabled in one of three ways, from highest-to-lowest priority:
		The feature-specific attribute (i.e. "ReadDocs")
		The SerializerFeatures attribute
		The SerializerEnableAllFeatures attribute
	
	Feature-specific attributes may be of any type, with some features expecting specific types
	
	The SerializerFeatures attribute is a string of settings, each separated by pipe characters ("|")
		Settings may either be defined as a flag, or with an explicit string/number/boolean value
		To give some examples:
			"ReadDocs|MissionCompression=23" - ReadDocs is a flag, so ReadDocs = true, MissionCompression would return as 23
			"ReadDocs="Yes, I have read the docs, LET ME MAKE A GIST!!!!""  - Strings work, although maybe don't be so mean to the serializer :(
			"ReadDocs='Sorry, Mr. Serializer! We love and appreciate you!'" - Both types of quotes are supported
			"ReadDocs=true|APIDev=false"     - Booleans also work!
	
	The SerializerEnableAllFeatures attribute must be a boolean to function, it enables all features that have not had an explicit value set
]]

-- Cache these, don't want to be parsing the whole thing for every APIDev print - we get boatloads of those if a third party plugin breaks
local featureCache = setmetatable({}, {__mode='v'})
local function parseSerializerFeatures()
	local featStr = workspace:GetAttribute("SerializerFeatures")
	if featStr == nil then return {} end
	if type(featStr) ~= "string" then
		warn("SerializerFeatures attribute on workspace must be a string or nil!")
		return {}
	end
	
	local existing = featureCache[featStr]
	if existing then return existing end
	
	local featureDict = {}
	
	for _, substr in ipairs(string.split(featStr, '|')) do
		substr = substr:match("^%s*(.-)%s*$")

		local flagged = substr:match("^[^=]+$")
		if flagged ~= nil then
			featureDict[flagged] = true
			continue
		end

		local feature, value = substr:match("^([^=]+)%s*=%s*([^=]+)$")
		if feature == nil or value == nil then
			warn(`SerializerFeature {substr} is invalid! Setting will be ignored.`)
			continue
		end

		local valNum = tonumber(value)
		if valNum ~= nil then 
			featureDict[feature] = valNum
			continue
		end

		local valStr = value:match("^\"(.*)\"$") or value:match("^\'(.*)\'$")
		if valStr ~= nil then
			featureDict[feature] = valStr
			continue
		end

		value = value:lower()
		local valBool = value:match("^true$") and true or value:match("^false$") and false
		if valBool ~= nil then
			featureDict[feature] = valBool
			continue
		end
		
		warn(`Specified SerializerFeature "{feature}" was not set to a valid value! Setting will be ignored.`)
	end
	
	featureCache[featStr] = featureDict
	return featureDict
end

return function(featureName)
	local featureValue = workspace:GetAttribute(featureName)
	if featureValue ~= nil then
		return featureValue
	end
	
	local featCfg = parseSerializerFeatures()
	if featCfg[featureName] ~= nil then
		return featCfg[featureName]
	end
	
	if workspace:GetAttribute("SerializerEnableAllFeatures") == true then
		return true
	end
end