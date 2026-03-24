local ReadBuild = {}
ReadBuild.rootNode = nil

local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CachedUserMeshFolder = workspace:FindFirstChild("CachedUserMeshes")
local ENABLE_ARBITRARY_MESHES = true

local protectedBuild
local build

-- Limit threads to not nuke the scheduler
local threadsLimit = 16
local threadsActive = 0
local threadsQueue = {}
local function runNextThread()
	if threadsActive >= threadsLimit then return end
	local job = table.remove(threadsQueue, 1)
	if not job then return end
	
	threadsActive += 1
	task.spawn(function()
		job()
		threadsActive -= 1
		runNextThread()
	end)
end

local function enqueueThread(job)
	table.insert(threadsQueue, job)
	runNextThread()
end

-- // Helper Functions | All functions not necessary outside the module should stay localized for faster lookup
local function resolvePath(pathString)
	local path = string.split(pathString, `.`)
	local current = ReadBuild.rootNode
	for _, v in path do
		local index = tonumber(v)
		current = current.Children[index]
	end
	
	if not current.Instance then repeat task.wait() until current.Instance end
	return current.Instance
end

local function applyAttributes(instance, attributes)
	for k, v in (attributes) do
		instance:SetAttribute(k, v)
	end
end

local function applyProperties(instance, properties)
	for k, v in (properties) do
		instance[k] = v
	end
end

local function applyProtectedProperties(instance, properties)
	for k, v in (properties) do
		pcall(function()
			instance[k] = v
		end)
	end
end

local function checkChildren(node, parent)
	for _, child in (node.Children) do
		if child.Protected then
			enqueueThread(function()
				protectedBuild(child, parent)
			end)
		else
			build(child, parent)
		end
	end
end

local function applyNodeKeys(node, newInstance, parent)
	checkChildren(node, newInstance)
	node.Instance = newInstance
	newInstance.Parent = parent
end

local function applyProtectedNodeKeys(node, newInstance, parent)
	applyProtectedProperties(newInstance, node.Properties)
	applyNodeKeys(node, newInstance, parent)
end

local function handleExpensive(node, newInstance)
	local expensive = node.Expensive
	if expensive then
		for k,v in (expensive) do
			enqueueThread(function()
				newInstance[k] = resolvePath(v)
			end)
		end
	end
end

-- // Instance Construction
protectedBuild = function(node, parent)
	local newInstance = Instance.new(`Part`)
	local instanceInitialized = false
	local meshId = node.Properties.MeshId
	local id = meshId and node.Properties.MeshId:match("%d+")
	if id and #id > 3 then
		meshId = id
	end
	node.Properties.MeshId = nil

	local cachedMeshPart = meshId
		and (
			(
				game.ReplicatedStorage:FindFirstChild("Assets")
				and game.ReplicatedStorage.Assets:FindFirstChild("ImportParts")
				and game.ReplicatedStorage.Assets.ImportParts:FindFirstChild(meshId)
			) or (CachedUserMeshFolder and CachedUserMeshFolder:FindFirstChild(meshId))
		)
	
	if cachedMeshPart then
		newInstance = cachedMeshPart:Clone()
		node.Properties.CollisionFidelity = nil
		node.Properties.RenderFidelity = nil
		instanceInitialized = true
	elseif meshId and ENABLE_ARBITRARY_MESHES then
		-- CreateMeshPartAsync is likely less reliable than cloning, so prefer using ImportParts when possible
		local success, instOrReason = pcall(function()
			local part = InsertService:CreateMeshPartAsync(
				`rbxassetid://{meshId}`,
				node.Properties["CollisionFidelity"] or Enum.CollisionFidelity.Default,
				node.Properties["RenderFidelity"] or Enum.RenderFidelity.Automatic
			)
			if CachedUserMeshFolder then
				local copy = part:Clone()
				copy.Name = meshId
				copy.Parent = CachedUserMeshFolder
			end
			return part
		end)
		node.Properties.CollisionFidelity = nil
		node.Properties.RenderFidelity = nil
		if success then
			newInstance = instOrReason
			instanceInitialized = true
		end
	end

	if not instanceInitialized then
		applyProtectedNodeKeys(node, newInstance, parent)
	else
		applyProperties(newInstance, node.Properties)
		applyAttributes(newInstance, node.Attributes)
		applyNodeKeys(node, newInstance, parent)
	end
	
	ReadBuild.rootNode.Processed += 1
	return newInstance
end

build = function(node, parent)
	local newInstance = Instance.new(node.Type)
	
	handleExpensive(node, newInstance)
	applyProperties(newInstance, node.Properties)
	applyAttributes(newInstance, node.Attributes)
	applyNodeKeys(node, newInstance, parent)
	return newInstance
end

ReadBuild.construct = function(node, parent)
	local newInstance = Instance.new(node.Type)
	
	applyProperties(newInstance, node.Properties)
	applyAttributes(newInstance, node.Attributes)
	applyNodeKeys(node, newInstance, parent)
	repeat task.wait() until ReadBuild.rootNode.Processed >= ReadBuild.rootNode.Expensives -- Ensure all parallels are done processing before returning the root node
	return newInstance
end

return ReadBuild