local AttributesMap = require(script.Parent.AttributesMap)
local PropAttributeTypes = require(script.Parent.PropAttributeTypes)

local GlobalPropAttributes = {
	GlobalVariables = { PropAttributeTypes.OPTIONAL_BOOL, nil },
	OnProp = { PropAttributeTypes.OPTIONAL_BOOL, nil },
	ScriptMove = { PropAttributeTypes.OPTIONAL_BOOL, nil },
	Index = { PropAttributeTypes.OPTIONAL_INT, nil },
	CanShatter = { PropAttributeTypes.OPTIONAL_BOOL, nil },
	Tag = { PropAttributeTypes.STRING, nil },
	TagOffset = { PropAttributeTypes.VECTOR3, nil },
	StaticTag = { PropAttributeTypes.STRING, nil },
	HasTopBarrier = { PropAttributeTypes.OPTIONAL_BOOL, nil },
	Indestructible = { PropAttributeTypes.EXPRESSION, nil },
	NoPropDamage = { PropAttributeTypes.EXPRESSION, nil },
	IsSpawned = { PropAttributeTypes.EXPRESSION, nil },
	Color0 = { PropAttributeTypes.OPTIONAL_MISSION_COLOR, nil },
	Color1 = { PropAttributeTypes.OPTIONAL_MISSION_COLOR, nil },
	Color2 = { PropAttributeTypes.OPTIONAL_MISSION_COLOR, nil },
	Color3 = { PropAttributeTypes.OPTIONAL_MISSION_COLOR, nil },
	Color4 = { PropAttributeTypes.OPTIONAL_MISSION_COLOR, nil },
	Color5 = { PropAttributeTypes.OPTIONAL_MISSION_COLOR, nil },
	Material0 = { PropAttributeTypes.OPTIONAL_MATERIAL, nil },
	Material1 = { PropAttributeTypes.OPTIONAL_MATERIAL, nil },
	Material2 = { PropAttributeTypes.OPTIONAL_MATERIAL, nil },
	Material3 = { PropAttributeTypes.OPTIONAL_MATERIAL, nil },
	Material4 = { PropAttributeTypes.OPTIONAL_MATERIAL, nil },
	Material5 = { PropAttributeTypes.OPTIONAL_MATERIAL, nil },
	Type = { PropAttributeTypes.STRING, nil },
	AltProp = { PropAttributeTypes.STRING, nil },
	AltPropModel = { PropAttributeTypes.STRING, nil },
	FadeOutCondition = { PropAttributeTypes.STRING, nil },
	CollisionGroup = { PropAttributeTypes.STRING, nil },
	TagButton = { PropAttributeTypes.EXPRESSION, nil },
}

local testAttributeCompatibility = function(attributeType, value, objectName, attributeName)
	if attributeType == "NUMBER" then
		if type(value) == "number" then
			return true
		else
			warn("The " .. objectName .. " object's " .. attributeName .. " attribute must contain a number type.")
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "INT" then
		if type(value) == "number" then
			if value == math.round(value) then
				return true
			else
				warn("The " .. objectName .. " object's " .. attributeName .. " attribute must be an integer.")
				warn("Found value: " .. tostring(value))
			end
		else
			warn(
				"The "
					.. objectName
					.. " object's "
					.. attributeName
					.. " attribute must contain a number type (integer)."
			)
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "EXPRESSION" then
		if type(value) == "boolean" or type(value) == "string" or type(value) == "number" then
			return true
		else
			warn(
				"The "
					.. objectName
					.. " object's "
					.. attributeName
					.. " attribute must contain a boolean, string, or number type."
			)
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "STATE_VALUE" then
		if type(value) == "string" then
			if string.find(value, "%s") == nil then
				return true
			else
				warn("The " .. objectName .. " object's " .. attributeName .. " attribute must not contain whitespace.")
				warn("Found value: " .. tostring(value))
			end
		else
			warn(
				"The "
					.. objectName
					.. " object's "
					.. attributeName
					.. " attribute must contain a string type with no whitespace."
			)
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "STRING" then
		if type(value) == "string" then
			return true
		else
			warn("The " .. objectName .. " object's " .. attributeName .. " attribute must contain a string type.")
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "NETWORK_ID" then
		if type(value) == "string" then
			local int = tonumber(value)
			if not int or int ~= math.round(int) or int < 1 or int > 999 then
				warn(
					"The "
						.. objectName
						.. " object's "
						.. attributeName
						.. " attribute must contain a number type between 1 and 999."
				)
			end
		elseif type(value) == "number" then
			if value == math.round(value) and value >= 1 and value <= 999 then
				return true
			else
				warn(
					"The "
						.. objectName
						.. " object's "
						.. attributeName
						.. " attribute must contain a number type between 1 and 999."
				)
				warn("Found value: " .. tostring(value))
			end
		else
			warn(
				"The "
					.. objectName
					.. " object's "
					.. attributeName
					.. " attribute must contain a number type between 1 and 999."
			)
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "NETWORK_ID_STRING" then
		if value == "" then
			return true
		end
		local num = tonumber(value)
		if num == math.round(num) and num >= 1 and num <= 999 then
			return true
		else
			warn(
				"The "
					.. objectName
					.. " object's "
					.. attributeName
					.. ' attribute must contain a string type of a number between 1 and 999 or be blank "".'
			)
			warn("Found value: " .. tostring(value))
		end
		return false
	elseif attributeType == "OPTIONAL_BOOL" then
		if value == nil or type(value) == "boolean" then
			return true
		else
			warn("The " .. objectName .. " object's " .. attributeName .. " attribute must be a boolean or nil.")
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "OPTIONAL_MISSION_COLOR" then
		if value == nil or typeof(value) == "Color3" or type(value) == "string" then
			return true
		else
			warn(
				"The "
					.. objectName
					.. " object's "
					.. attributeName
					.. " attribute must be a nil, Color3, or a string."
			)
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "OPTIONAL_MATERIAL" then
		if value == nil or type(value) == "string" then
			return true
		else
			warn("The " .. objectName .. " object's " .. attributeName .. " attribute must be a nil or a string.")
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "VECTOR3" then
		if typeof(value) == "Vector3" then
			return true
		else
			warn(
				"The "
					.. objectName
					.. " object's "
					.. attributeName
					.. " attribute must contain a number type (integer)."
			)
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "OPTIONAL_INT" then
		if value == nil then
			return true
		elseif type(value) == "number" then
			if value == math.round(value) then
				return true
			else
				warn("The " .. objectName .. " object's " .. attributeName .. " attribute must be nil or an integer.")
				warn("Found value: " .. tostring(value))
			end
		else
			warn(
				"The "
					.. objectName
					.. " object's "
					.. attributeName
					.. " attribute must contain a number type (integer)."
			)
			warn("Found type: " .. type(value))
		end
		return false
	elseif attributeType == "BOOL" then
		if type(value) == "boolean" then
			return true
		else
			warn("The " .. objectName .. " object's " .. attributeName .. " attribute must be a boolean")
			warn("Found type: " .. type(value))
		end
		return false
	else
		error(`Attribute type does not exist: {tostring(attributeType)}`)
	end
end

return {
	Validate = function(className, instanceName, attributes, includeDefaults)
		if className == "Folder" then
			return attributes
		end

		if attributes.IKnowWhatImDoingDoNotValidate == true then
			warn(`Instance {instanceName} of Class {className} is intentionally opting out of attribute validation`)
			return attributes
		elseif attributes.Type == "StateScript" or instanceName == "StateScriptPart" then
			return attributes
		end

		local name = className == "BoolValue" and attributes.Type or instanceName
		if not AttributesMap[name] then
			return attributes -- If not included in the prop list, just return the normal attributes list
		elseif attributes.AltProp or attributes.AltPropModel then
			return attributes -- Skip validation for AltProp/AltPropModel
		else
			local newAttributes = {}
			local attributeTypes = AttributesMap[name]
			for attName, tableOfInfo in pairs(attributeTypes) do -- add attributes specifically listed in AttributesMap.lua
				if not attributes[attName] then
					if includeDefaults then
						newAttributes[attName] = tableOfInfo[2]
					end
					continue
				end
				local givenValue = attributes[attName]
				local attributeTypeName = ""
				for i, v in pairs(PropAttributeTypes) do
					if tableOfInfo[1] == v then
						attributeTypeName = i
					end
				end
				if attributeTypeName == "" then
					error(`attribute type does not exist: {name} {attName}`)
				end
				if not testAttributeCompatibility(attributeTypeName, givenValue, name, attName) then
					if includeDefaults then
						newAttributes[attName] = attributeTypes[attName][2]
					else
						continue
					end
				end
				-- If the value isn't default or is and the includeDefaults value is set to true, then add it to the list
				if (tableOfInfo[2] == givenValue and includeDefaults) or tableOfInfo[2] ~= givenValue then
					newAttributes[attName] = givenValue
				end
			end
			for attribute, value in pairs(attributes) do -- add the remaining attributes that are defined in the global attributes table above
				if GlobalPropAttributes[attribute] then
					local tableOfInfo = GlobalPropAttributes[attribute]
					local attributeTypeName = ""
					for i, v in pairs(PropAttributeTypes) do
						if tableOfInfo[1] == v then
							attributeTypeName = i
						end
					end
					if testAttributeCompatibility(attributeTypeName, value, name, attribute) then
						newAttributes[attribute] = value
					else
						newAttributes[attribute] = nil -- set to nil if it doesn't fit properly
					end
				elseif not attributeTypes[attribute] then
					warn("Unknown attribute will be discarded:", attribute, name)
				end
			end

			return newAttributes
		end
	end,
}
