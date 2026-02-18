local httpService = game:GetService("HttpService")

local attributesMap = require(script.Parent.Parent.AttributesMap)
local featureCheck = require(script.Parent.Parent.Util.FeatureCheck)

local internalAPI = {}
internalAPI.APIExtensions = {}

internalAPI.RunningThread = nil
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

local wait_event = Instance.new("BindableEvent")
internalAPI.StateCommands = {
	CMD_WAIT = function(caller, duration)
		local validDuration = duration
		if type(duration) ~= "number" then validDuration = 0 end
		validDuration = math.clamp(validDuration, 0, 2.5)
		if validDuration ~= duration then
			warn(`SerializerAPI : {caller}'s CMD_WAIT stateCommand provided invalid waiting duration - number between 0 & 2.5 expected, got {duration} - will wait for {validDuration} instead!`)
		end
		return { task.wait(validDuration) }
	end,
	CMD_WAIT_EVENT = function(caller, event)
		if typeof(event) ~= "RBXScriptSignal" then return { `Expected RBXScriptSignal, got {typeof(event)}!` } end
		local fired = false
		local args = {}
		task.spawn(function()
			task.wait(2.5)
			if fired then return end
			wait_event:Fire(false)
		end)
		
		local connection
		connection = event:Connect(function(...)
			if fired then return end
			wait_event:Fire(true)
			args = { ... }
		end)
		local success = wait_event.Event:Wait()
		fired = true
		connection:Disconnect()
		return { success, unpack(args) }
	end,
}

local function arg_merge(...)
	local n = select('#', ...)
	local t = table.create(n, nil)
	for i=1, n do
		t[#t+1] = select(i, ...)
	end
	return unpack(t)
end

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

local function co_xpcall(co, ...)
	local out = { coroutine.resume(co, ...) }
	if out[1] == false then return false, debug.traceback(co, out[2]) end
	return unpack(out)
end

local function APIDevPrint(msg)
	if not featureCheck("APIDev") then return end
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
		local outMsg = `Attempt made to remove {hookName} using invalid GUID!`
		if featureCheck("APIDev") then
			outMsg = debug.traceback(outMsg)
		end
		warn(outMsg)
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
			CallbackState = state,
			CMD_Result = {}
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
			
			internalAPI.RunningThread = hookCoroutine
			local success, stateOut, arg1 = co_xpcall(hookCoroutine, arg_merge(unpack(hook.CMD_Result), hook.CallbackState, invokeStatePublic, ...))
			internalAPI.RunningThread = nil

			if type(stateOut) == "string" then
				stateOut = stateOut:upper()
			else
				hook.CMD_Result = {}
			end

			if stateOut == "CMD_STATE_SET" then
				stateOut = arg1
				arg1 = nil
			end

			if success and type(stateOut) == "table" then
				-- Set state values
				for k, v in pairs(stateOut) do
					if internalAPI.ProtectedStateKeys[k] ~= nil then
						warn(`Attempt by {hook.Registrant} to set protected InvokeState value {hook.Registrant}.{k}`)
						continue
					end
					invokeState[hook.Registrant][k] = v
				end
			elseif success and type(stateOut) == "string" then
				hook.CMD_Result = internalAPI.StateCommands[stateOut](hook.Registrant, arg1)
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