local httpService = game:GetService("HttpService")

local attributesMap = require(script.Parent.Parent.AttributesMap)

local internalAPI = {}
internalAPI.APIExtensions = {}

internalAPI.Hooks = {}
internalAPI.Hooks.APIExtensionLoaded = {}
internalAPI.Hooks.APIExtensionUnloaded = {}
internalAPI.Hooks.PreSerialize = {}
internalAPI.Hooks.SerializerUnloaded = {}
internalAPI.Hooks.PreSerializeMissionSetup = {}

internalAPI.HookTypes = {}

internalAPI.ProtectedStateKeys = {
	Present = true,
	Done = false
}

local function varargs(...)
	local n = select('#', ...)
	local t = { ... }
	local i = 0
	return function()
		i = i + 1
		if i <= n then return i, t[i], n end
	end, t
end

local function tblCount(t)
	local i = 0
	for k, v in pairs(t) do
		i = i + 1
	end
	return i
end

local function APIDevPrint(msg)
	if not workspace:GetAttribute("APIDev") then return end
	print(`SerializerAPI :\t{msg}`)
end

internalAPI.DeepClone = function(tbl)
	local cloned = {}
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			cloned[k] = internalAPI.DeepClone(v)
		else
			cloned[k] = v
		end
	end
	return cloned
end

internalAPI.DeepFreeze = function(tbl)
	for _, v in pairs(tbl) do
		if type(v) == "table" then
			table.freeze(v)
		end
	end
	return table.freeze(tbl)
end

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

internalAPI.SafeIndex = function(tbl, ...)
	local indexing = tbl
	for i, key in varargs(...) do
		if type(indexing) ~= "table" then
			return false, indexing
		end
		indexing = indexing[tostring(key)]
	end
	
	if type(indexing) == "table" then
		return true, internalAPI.DeepFreeze(internalAPI.DeepClone(indexing))
	end
	
	return true, indexing
end

internalAPI.CreateInvokationState = function(invoking)
	local underlyingState = {}
	local publicInterface = {}
	
	for _, hook in pairs(invoking) do
		underlyingState[`{hook.Registrant}_Present`] = true
		underlyingState[hook.Registrant] = internalAPI.DeepClone(internalAPI.ProtectedStateKeys)
	end
	
	publicInterface.Get = function(...)
		return internalAPI.SafeIndex(underlyingState, ...)
	end
	
	return table.freeze(publicInterface), underlyingState
end

internalAPI.AddHook = function(hookType: string, registrant, callback, state) : string
	local hookTbl = internalAPI.Hooks[hookType]
	for _, hook in pairs(hookTbl) do
		if hook.Registrant == registrant then
			warn(`{hookType}Hook Naming Collision! Name \"{registrant}\" already in-use!`)
			return
		end
	end
	APIDevPrint(`Adding {hookType}Hook \t{registrant}`)
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
	local removing = hookTbl[token] or {}
	APIDevPrint(`Removing {hookName} \t{removing.Registrant}`)
	internalAPI.RemoveTokenData(hookTbl, token, hookName)
end

internalAPI.InvokeHook = function(hookType, ...)
	APIDevPrint(`Running Hooks Of Type \t{hookType}`)
	
	local hooksToRun = internalAPI.Hooks[hookType]
	local unfinishedHooks = hooksToRun
	local invokeIterations = 1
	
	local invokeStatePublic, invokeState = internalAPI.CreateInvokationState(hooksToRun)
	
	local hookCoroutines = {}
	for _, hook in pairs(hooksToRun) do
		hookCoroutines[hook.Callback] = coroutine.create(hook.Callback)
	end
	
	while tblCount(unfinishedHooks) > 0 and invokeIterations <= 2000 do
		hooksToRun = unfinishedHooks
		unfinishedHooks = {}
		
		for _, hook in pairs(hooksToRun) do
			local hookCoroutine = hookCoroutines[hook.Callback]
			local success, stateVals = coroutine.resume(hookCoroutine, hook.CallbackState, invokeStatePublic, ...)
			
			if success and type(stateVals) == "table" then
				-- Set state values
				for k, v in pairs(stateVals) do
					if internalAPI.ProtectedStateKeys[k] ~= nil then
						warn(`Attempt by {hook.Registrant} to set protected InvokeState value {hook.Registrant}.{k}`)
						continue
					end
					invokeState[hook.Registrant][k] = v
				end
			end
			
			if success and coroutine.status(hookCoroutine) == "suspended" then
				unfinishedHooks[#unfinishedHooks+1] = hook
			elseif success and coroutine.status(hookCoroutine) == "dead" then
				invokeState[hook.Registrant].Done = true
			elseif not success then
				warn(`Error encountered when running {hookType}Hook {hook.Registrant} - {stateVals}`)
			end
		end
		
		invokeIterations = invokeIterations + 1
	end

	if invokeIterations > 2000 then
		warn(`Hook {hookType} ran for 2,000 stages and did not finish, unfinished hooks are as follows:`)
		for _, hook in ipairs(unfinishedHooks) do
			warn(`\t{hook.Registrant}`)
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