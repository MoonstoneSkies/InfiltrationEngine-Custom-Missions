local coreGui = game:GetService("CoreGui")

local SERIALIZER_INDICATOR_NAME = "InfilEngine_SerializerAPIAvailable"

local serializerAPI = {}

serializerAPI.Public = require(script.Parent.Public)
serializerAPI.Internal = require(script.Parent.Internal)

serializerAPI.Events = {}
serializerAPI.PresenceIndicator = nil

function serializerAPI.PresenceIndicatorDestroying()
	serializerAPI.CreatePresenceIndicator(tostring(serializerAPI.Public), true)
end

function serializerAPI.PresenceIndicatorChanged()
	-- Resetting the indicator back would create an infinite loop
	-- Instead, force the indicator to be re-created
	serializerAPI.PresenceIndicator:Destroy()
end

function serializerAPI.CoreGuiChildAdded(child)
	if child.Name == SERIALIZER_INDICATOR_NAME then
		if child == serializerAPI.PresenceIndicator then return end
		warn("Attempted tampering of Serializer API presence indication detected - consider vetting plugins for undesirable behaviour")
		child:Destroy()
	end
end

function serializerAPI.CreatePresenceIndicator(tableId, shouldWarn)
	if shouldWarn == nil then shouldWarn = true end

	if shouldWarn then warn("Tampering of Serializer API presence indicator detected - consider vetting plugins for undesirable behaviour") end

	local presenceIndicator = Instance.new("StringValue")
	presenceIndicator.Archivable = false
	presenceIndicator.Name = SERIALIZER_INDICATOR_NAME
	presenceIndicator.Value = tableId
	presenceIndicator.Parent = coreGui

	serializerAPI.CleanIndicatorEvents()
	serializerAPI.Events[1] = presenceIndicator.Destroying:Connect(serializerAPI.PresenceIndicatorDestroying)
	serializerAPI.Events[2] = presenceIndicator.Changed:Connect(serializerAPI.PresenceIndicatorChanged)
	serializerAPI.Events[3] = presenceIndicator.AncestryChanged:Connect(serializerAPI.PresenceIndicatorChanged)
	serializerAPI.Events[4] = presenceIndicator:GetPropertyChangedSignal("Archivable"):Connect(serializerAPI.PresenceIndicatorChanged)
	serializerAPI.PresenceIndicator = presenceIndicator
end

function serializerAPI.AntiTamperInit()
	for _, child in coreGui:GetChildren() do
		if child.Name ~= SERIALIZER_INDICATOR_NAME then continue end
		serializerAPI.CoreGuiChildAdded(child)
	end
	serializerAPI.AntiCoreGuiTamper = coreGui.ChildAdded:Connect(serializerAPI.CoreGuiChildAdded)
end

function serializerAPI.Init()
	serializerAPI.AntiTamperInit()
	shared.InfilEngine_SerializerAPI = serializerAPI.Public
	serializerAPI.CreatePresenceIndicator(tostring(serializerAPI.Public), false)
end

function serializerAPI.Clean()
	serializerAPI.CleanIndicatorEvents()
	serializerAPI.AntiCoreGuiTamper:Disconnect()
	serializerAPI.PresenceIndicator:Destroy()
	serializerAPI.PresenceIndicator = nil
	serializerAPI.Internal.InvokeHook("SerializerUnloaded")
end

function serializerAPI.CleanIndicatorEvents()
	for i, e in ipairs(serializerAPI.Events) do
		e:Disconnect()
		e = nil
	end
end

return serializerAPI
