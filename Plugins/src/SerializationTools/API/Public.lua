local httpService = game:GetService("HttpService")

local attributesMap = require(script.Parent.Parent.AttributesMap)
local attributeTypes = require(script.Parent.Parent.PropAttributeTypes)
local versionCfg = require(script.Parent.Parent.Util.VersionConfig)

local internalAPI = require(script.Parent.Internal)

local function DeepClone(tbl)
	local cloned = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			cloned[k] = DeepClone(v)
		else
			cloned[k] = v
		end
	end
	return cloned
end

local function DeepFreeze(tbl)
	for _, v in pairs(tbl) do
		if type(v) == "table" then
			table.freeze(v)
		end
	end
	return table.freeze(tbl)
end

local function ValidateArgTypes(fname, ...)
	local args = {...}
	for _, argSettings in ipairs(args) do
		local argName = argSettings[1]
		local argValue = argSettings[2]
		local argType = type(argValue)
		local argExpectedType = argSettings[3]
		if argType ~= argExpectedType then
			warn(`Invalid argument {argName} passed to API function {fname} - expected type {argExpectedType} but got {argType}!`)
			return false
		end
	end
	return true
end

type APIExtension = { [string] : (...any) -> ...any }

local publicAPI = {}

--[[
	[Returns]
		1 - Returns an integer describing the current revision of the serializer plugin API
]]
function publicAPI.GetAPIVersion() : number
	return versionCfg.VersionNumber_API
end

--[[
	[Returns]
		1 - Integer describing the current version of the serializer's code format
]]
function publicAPI.GetCodeVersion() : number
	return versionCfg.VersionNumber
end

--[[
	[Returns]
		1 - Frozen copy of internal attributes map
]]
local frozenAttributesMap = DeepFreeze(DeepClone(attributesMap))
function publicAPI.GetAttributesMap() : { [string] : { any } }
	return frozenAttributesMap
end

--[[
	[Returns]
		1 - Frozen copy of internal attribute types
]]
local frozenAttributeTypes = DeepFreeze(DeepClone(attributeTypes))
function publicAPI.GetAttributeTypes() : { [string] : number }
	return frozenAttributeTypes
end

--[[
	[Returns]
		1 - Frozen copy of valid hook types table
]]
function publicAPI.GetHookTypes() : { string }
	return internalAPI.GetHookTypes()
end

--[[
	[Args]
		     Title // Description                                                                                // Example        //
		---------- // ------------------------------------------------------------------------------------------ // -------------- //
		  hookType // String corresponding to the hookType you're attempting to validate                         // "PreSerialize" //
		warnCaller // String corresponding to the name of the caller - if provided, an automated warn is emitted // "MyFunction"   //
	[Returns]
		1 - Boolean indicating whether or not the provided HookType is valid
]]
function publicAPI.IsHookTypeValid(hookType: string, warnCaller: string?) : boolean
	if not ValidateArgTypes("IsHookTypeValid", {"hookType", hookType, "string"}) then return false end
	local isValid = table.find(publicAPI.GetHookTypes(), hookType) ~= nil
	if not isValid and warnCaller ~= nil then
		warn(`Invalid HookType {hookType} passed to function {warnCaller}!`)
	end
	return isValid
end

--[[
	[Args]
		     Title // Description                                                                       // Example                                   //
		---------- // --------------------------------------------------------------------------------- // ----------------------------------------- //
		  hookType // String corresponding to the type of hook being removed                            // "PreSerialize"                            //
		registrant // String representing the source of the hook. May be non-unique                     // "MyPlugin"                                //
		      hook // Function to be invoked when the corresponding hookType is used                    // function() print("Hook!") end             //
		 hookState // (Optional) Extra state to be passed as the last argument to the hook when invoked // { PartCol = Color3.fromHex("#FFFFFF") } //
	[Returns]
		1 - Token which may be later used to securely de-register the hook
	[Notes]
		1) All valid hookTypes may be retrieved by calling GetHookTypes
]]
function publicAPI.AddHook(hookType: string, registrant: string, hook: (...any) -> nil, hookState: { any }?) : string
	hookState = if hookState == nil then {} else hookState
	if not ValidateArgTypes(
		"AddHook", 
		{"hookType", hookType, "string"},
		{"registrant", registrant, "string"},
		{"hook", hook, "function"},
		{"hookState", hookState, "table"}
		) then return end
	if not publicAPI.IsHookTypeValid(hookType, "AddHook") then return end
	local token = internalAPI.AddHook(hookType, registrant, hook, hookState) 
	return `{hookType}_{token}`
end

--[[
	[Args]
		   Title // Description                                            // Example        //
		-------- // ------------------------------------------------------ // -------------- // 
		   token // Value returned from corresponding call to AddHook      // n/a            //
]]
function publicAPI.RemoveHook(token: string)
	if not ValidateArgTypes(
		"RemoveHook",
		{"token", token, "string"}
		) then return end
	local splitToken = string.split(token, "_")
	if #splitToken ~= 2 then warn("Token provided to RemoveHook is invalid!") return end
	
	local hookType = splitToken[1]
	local realToken = splitToken[2]
	
	if not publicAPI.IsHookTypeValid(hookType, "RemoveHook") then return end
	
	internalAPI.RemoveHook(hookType, realToken)
end

--[[
	[Args] 
		   Title // Description                                       // Example                                                //
	    -------- // ------------------------------------------------- // ------------------------------------------------------ //
		    name // Name of the API extension                         // "MyPluginAPI"                                          //
		  author // Name/alias for the author(s) of the API extension // "Sprix"                                                //
		contents // Table of functions exposed via the API extension  // { HelloWorld = function() print("Hello, World!") end } //
	[Returns]
		1 - Token which may be used to securely de-register the APIExtension
	[Notes]
		1) Contents table is recursively frozen - plan accordingly!
		2) Name & Author pair *MUST* be unique
		3) Will invoke all APIExtensionLoadedCallbacks before returning
]]
function publicAPI.AddAPIExtension(name: string, author: string, contents: APIExtension) : string
	if not ValidateArgTypes("AddAPIExtension", {"name", name, "string"}, {"author", author, "string"}, {"contents", contents, "table"}) then return end
	return internalAPI.AddAPIExtension(name, author, DeepFreeze(contents))
end

--[[
	[Args]
		 Title // Description                                       // Example       //
		------ // ------------------------------------------------- // ------------- //
		  name // Name of the API extension                         // "MyPluginAPI" //
		author // Name/alias for the author(s) of the API extension // "Sprix"       //
	[Returns]
		1 - Table exposed via the API extension, nil if it doesn't exist or has yet to be registered
	[Notes]
		1) See AddAPIExtensionLoadedCallback if you need to run code whenever specific extension(s) are loaded 
]]
function publicAPI.GetAPIExtension(name: string, author: string) : APIExtension?
	if not ValidateArgTypes("GetAPIExtension", {"name", name, "string"}, {"author", author, "string"}) then return end
	return internalAPI.GetAPIExtension(name, author)
end

--[[
	[Args]
		Title // Description                                               //
		----- // --------------------------------------------------------- //
		token // Value returned from corresponding call to AddAPIExtension // 
]]
function publicAPI.RemoveAPIExtension(token: string)
	if not ValidateArgTypes("RemoveAPIExtension", {"token", token, "string"}) then return end
	return internalAPI.RemoveAPIExtension(token)
end

return table.freeze(publicAPI)