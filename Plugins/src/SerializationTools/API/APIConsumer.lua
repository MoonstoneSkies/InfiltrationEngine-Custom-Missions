--[[
	This module is provided for convenience of consumers of the serializer API
	providing a reference implementation for correctly retrieving and validating a reference to the API table

	For a working example of a plugin making use of this API via this module
	see: https://github.com/Sprixitite/InfiltrationEngine-PrefabSystem
]]

local coreGui = game:GetService("CoreGui")

export type Token = string
export type Hook = (...any) -> nil
export type HookType = "APIExtensionLoaded"|"APIExtensionUnloaded"|"PreSerialize"|"PreSerializeMissionSetup"|"SerializerUnloaded"
export type APIExtension = { [string] : (...any) -> ...any }

export type APIReference = {
	-- Generic
	GetAPIVersion 			: () -> number,
	GetCodeVersion 			: () -> number,
	GetAttributesMap 		: () -> { [string] : { [number] : any } },
	GetAttributeTypes 		: () -> { [string] : number },
	GetRegistrantFactory	: (author: string, plugin: string) -> ((hookName: string) -> string), 

	-- HookTypes
	GetHookTypes 			: () -> { [number] : string },
	IsHookTypeValid 		: (hookType: string, warnCaller: string?) -> boolean,

	-- Hooks
	AddHook 				: (hookType: HookType, registrant: string, hook: Hook, hookState: {any}?) -> Token,
	RemoveHook 				: (token: Token) -> nil,

	-- APIExtensions
	AddAPIExtension 		: (name: string, author: string, contents: APIExtension) -> Token,
	GetAPIExtension			: (name: string, author: string) -> APIExtension,
	RemoveAPIExtension		: (token: Token) -> nil
}

type AnyTbl = { [string] : any }

local APIConsumer = {}

local function ValidateArgTypes(fname: string, ...) : boolean
	local args = {...}
	for _, argSettings in ipairs(args) do
		local argName = argSettings[1]
		local argValue = argSettings[2]
		local argType = type(argValue)
		local argExpectedType = argSettings[3]
		if argType ~= argExpectedType then
			warn(`Invalid argument {argName} passed to function {fname} - expected type {argExpectedType} but got {argType}!`)
			return false
		end
	end
	return true
end

APIConsumer.ValidateArgTypes = ValidateArgTypes

-- Yields until timeOut is elapsed or API is found
APIConsumer.WaitForAPI = function(timeOut: number?) : APIReference?
	timeOut = if timeOut == nil then math.huge else timeOut

	if not ValidateArgTypes(
		"WaitForAPI",
		{"timeOut", timeOut, "number"}
		) then return end

	local presenceIndicator = coreGui:WaitForChild("InfilEngine_SerializerAPIAvailable", timeOut)
	if not presenceIndicator then return end

	local apiTbl = shared.InfilEngine_SerializerAPI
	if not (tostring(apiTbl) == presenceIndicator.Value) then return end

	return apiTbl
end

-- Attempt to get the API without blocking - returns false + nil if unavailable, otherwise returns true + APIReference
APIConsumer.TryGetAPI = function() : (boolean, APIReference?)
	local presenceIndicator = coreGui:FindFirstChild("InfilEngine_SerializerAPIAvailable")
	if not presenceIndicator then return false, nil end

	local apiTbl = shared.InfilEngine_SerializerAPI
	if not (tostring(apiTbl) == presenceIndicator.Value) then return false, nil end

	return true, apiTbl
end

-- Never returns unless there's an error
-- Continually wires up handling of serializer load/unload as well as unloading of consumer plugin as needed
-- Avoid doing this yourself if you can help it
APIConsumer.DoAPILoop = function<StateT>(
	callerPlugin: Plugin,
	srcname: string,
	loadedClbck: (api: APIReference, state: StateT) -> nil,
	unloadedClbck: (api: APIReference, state: StateT) -> nil, 
	state: StateT?
) : never
	state = if state == nil then {} else state

	if typeof(callerPlugin) ~= "Instance" then
		warn(`Invalid argument callerPlugin passed to DoAPILoop - expected type Plugin but got {typeof(callerPlugin)}!`)
		return
	end

	if callerPlugin.ClassName ~= "Plugin" then
		warn(`Invalid argument callerPlugin passed to DoAPILoop - expected type Plugin but got {callerPlugin.ClassName}!`)
		return
	end

	if not ValidateArgTypes(
		"DoAPILoop", 
		{"srcname", srcname, "string"},
		{"loadedClbck", loadedClbck, "function"},
		{"unloadedClbck", unloadedClbck, "function"},
		{"state", state, "table"}
		) then return end

	local api = APIConsumer.WaitForAPI()
	if api == nil then return APIConsumer.DoAPILoop(callerPlugin, srcname, loadedClbck, unloadedClbck, state) end

	loadedClbck(api, state)

	local pluginUnloadCallback
	local unloadToken

	pluginUnloadCallback = callerPlugin.Unloading:Connect(function()
		pluginUnloadCallback:Disconnect()
		pluginUnloadCallback = nil
		unloadedClbck(api, state)
		if unloadToken ~= nil then api.RemoveHook(unloadToken) end
	end)

	unloadToken = api.AddHook("SerializerUnloaded", `APIConsumerFramework_{srcname}`, function()
		if pluginUnloadCallback then pluginUnloadCallback:Disconnect() pluginUnloadCallback = nil end
		unloadedClbck(api, state)
		task.spawn(APIConsumer.DoAPILoop, callerPlugin, srcname, loadedClbck, unloadedClbck, state)
	end)
end

return APIConsumer