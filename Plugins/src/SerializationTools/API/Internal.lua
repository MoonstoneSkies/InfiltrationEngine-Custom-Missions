local httpService = game:GetService("HttpService")

local attributesMap = require(script.Parent.Parent.AttributesMap)

local internalAPI = {}
internalAPI.APIExtensions = {}

internalAPI.Hooks = {}
internalAPI.Hooks.APIExtensionLoaded = {}
internalAPI.Hooks.APIExtensionUnloaded = {}
internalAPI.Hooks.PreSerialize = {}
internalAPI.Hooks.SerializerUnloaded = {}

internalAPI.HookTypes = {}

internalAPI.AddTokenData = function(tbl, data)
	local id = httpService:GenerateGUID(false)
	tbl[id] = data
	return id
end

internalAPI.RemoveTokenData = function(tbl, token, hookName)
	if tbl[token] == nil then
		warn(`Attempt made to remove {hookName} using invalid GUID!`)
		return
	end
	tbl[token] = nil
end

internalAPI.AddHook = function(hookType: string, registrant, callback, state) : string
	local hookTbl = internalAPI.Hooks[hookType]
	return internalAPI.AddTokenData(
		hookTbl, 
		{ 
			Registrant = registrant,
			Callback = callback,
			CallbackState = state
		}
	)
end

internalAPI.RemoveHook = function(hookType: string, token: string)
	local hookName = `{hookType}Hook`
	local hookTbl = internalAPI.Hooks[hookType]
	internalAPI.RemoveTokenData(hookTbl, token, hookName)
end

internalAPI.InvokeHook = function(hookType, ...)
	for _, hook in pairs(internalAPI.Hooks[hookType]) do
		--[[
			Nil here for future extensions without needing to bump API version

			The hope is adding a dynamic phase-based invocation system whereby we pass an "InvocationState"
				describing which callbacks have finished and which haven't, giving hooks read-only access to this
				and then letting them run as coroutines, yielding if a dependency has yet to run
		
			Any values returned by a yielding callback may then be published to the InvocationState for other hooks to read
				allowing for the export of useful intermediary data from partway through a hooks execution
		
			This allows a way to opt-in to deterministic execution order while also allowing for
				intercommunication of useful data without adding an explicit priority system
		]]
		local success, reason = pcall(hook.Callback, hook.CallbackState, nil, ...)

		if not success then
			warn(`Error encountered when running {hookType}Hook {hook.Registrant} - {reason}`)
		end
	end
end

function internalAPI.GetHookTypes()
	return internalAPI.HookTypes
end

internalAPI.AddAPIExtension = function(name, author, contents)
	for _, apiExtension in pairs(internalAPI.APIExtensions) do
		if apiExtension.Name.Name == name then
			warn(`APIExtension naming collision! Name \"{name}\" already in use!`)
			return
		end
	end

	local id = internalAPI.AddTokenData(
		internalAPI.APIExtensions,
		{
			Name = name,
			Author = author,
			Contents = contents
		}
	)

	internalAPI.InvokeHook("APIExtensionLoaded", name, author, contents)
	return id
end

internalAPI.GetAPIExtension = function(name, author)
	for _, extension in internalAPI.APIExtensions do
		if extension.Name == name and extension.Author == author then return extension.Contents end
	end
end

internalAPI.RemoveAPIExtension = function(guid)
	local removing = internalAPI.APIExtensions[guid]
	if removing then
		internalAPI.InvokeHook("APIExtensionUnloaded", removing.Name, removing.Author, removing.Contents)
	end

	internalAPI.RemoveTokenData(internalAPI.APIExtensions, guid, "APIExtension")

end

for k, _ in pairs(internalAPI.Hooks) do
	internalAPI.HookTypes[#internalAPI.HookTypes+1] = k
end
table.freeze(internalAPI.HookTypes)

return internalAPI