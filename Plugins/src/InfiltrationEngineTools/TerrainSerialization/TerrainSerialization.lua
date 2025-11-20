local MaterialId = require(script.Parent.MaterialReference)

local BLOCK_SIZE = 16
local VOXEL_SIZE = 4

local BLOCK_STUD_SIZE = BLOCK_SIZE * VOXEL_SIZE
local BLOCK_STUD_HALF_SIZE = BLOCK_STUD_SIZE / 2

local BUFFER_OFFSET = 32 -- Avoiding adding control characters to the buffer
local BUFFER_RANGE = 127 - BUFFER_OFFSET

local StandardAttributes = {
	WaterColor = true,
	WaterTransparency = true,
	WaterReflectance = true,
	WaterWaveSize = true,
	WaterWaveSpeed = true,
}

local SaveMaterialColors = {
	Enum.Material.Asphalt,
	Enum.Material.Basalt,
	Enum.Material.Brick,
	Enum.Material.Cobblestone,
	Enum.Material.Concrete,
	Enum.Material.CrackedLava,
	Enum.Material.Glacier,
	Enum.Material.Grass,
	Enum.Material.Ground,
	Enum.Material.Ice,
	Enum.Material.LeafyGrass,
	Enum.Material.Limestone,
	Enum.Material.Mud,
	Enum.Material.Pavement,
	Enum.Material.Rock,
	Enum.Material.Salt,
	Enum.Material.Sand,
	Enum.Material.Sandstone,
	Enum.Material.Slate,
	Enum.Material.Snow,
	Enum.Material.WoodPlanks,
}

local module = {
	GetCoordinateBoundsFromPart = function(self, basePart)
		local minX, minY, minZ
		minX = math.round(basePart.Position.X / BLOCK_STUD_SIZE)
		minY = math.round(basePart.Position.Y / BLOCK_STUD_SIZE)
		minZ = math.round(basePart.Position.Z / BLOCK_STUD_SIZE)
		local maxX, maxY, maxZ = minX, minY, minZ

		local halfSize = basePart.Size / 2
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner =
						basePart.CFrame:PointToWorldSpace(Vector3.new(x * halfSize.X, y * halfSize.Y, z * halfSize.Z))
					minX = math.min(minX, math.round(corner.X / BLOCK_STUD_SIZE))
					maxX = math.max(maxX, math.round(corner.X / BLOCK_STUD_SIZE))
					minY = math.min(minY, math.round(corner.Y / BLOCK_STUD_SIZE))
					maxY = math.max(maxY, math.round(corner.Y / BLOCK_STUD_SIZE))
					minZ = math.min(minZ, math.round(corner.Z / BLOCK_STUD_SIZE))
					maxZ = math.max(maxZ, math.round(corner.Z / BLOCK_STUD_SIZE))
				end
			end
		end

		return Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)
	end,
	GetBlockRegion = function(self, coordinates)
		local basePos = coordinates * BLOCK_STUD_SIZE
		local rangeMin = basePos + Vector3.new(-BLOCK_STUD_HALF_SIZE, -BLOCK_STUD_HALF_SIZE, -BLOCK_STUD_HALF_SIZE)
		local rangeMax = basePos + Vector3.new(BLOCK_STUD_HALF_SIZE, BLOCK_STUD_HALF_SIZE, BLOCK_STUD_HALF_SIZE)
		return Region3.new(rangeMin, rangeMax)
	end,
	HasData = function(self, channel)
		for x = 1, BLOCK_SIZE do
			for y = 1, BLOCK_SIZE do
				for z = 1, BLOCK_SIZE do
					if channel[x][y][z] ~= 0 then
						return true
					end
				end
			end
		end
		return false
	end,
	CompressChannel = function(self, channel)
		local counts = {}
		local values = {}
		local lastValue = channel[1][1][1]
		local sequenceLength = 0
		for x = 1, BLOCK_SIZE do
			for y = 1, BLOCK_SIZE do
				for z = 1, BLOCK_SIZE do
					local value = channel[x][y][z]
					if value ~= lastValue or sequenceLength == BUFFER_RANGE then
						table.insert(counts, sequenceLength)
						table.insert(values, lastValue)
						lastValue = value
						sequenceLength = 0
					end
					sequenceLength += 1
				end
			end
		end

		table.insert(counts, sequenceLength)
		table.insert(values, lastValue)

		local channelBuffer = buffer.create(#counts * 2)
		for index, count in counts do
			buffer.writeu8(channelBuffer, index * 2 - 2, count + BUFFER_OFFSET)
			buffer.writeu8(channelBuffer, index * 2 - 1, values[index] + BUFFER_OFFSET)
		end

		return buffer.tostring(channelBuffer)
	end,
	DecompressChannel = function(self, channelDataString)
		local channelBuffer = buffer.fromstring(channelDataString)

		local applyCount = buffer.readu8(channelBuffer, 0) - BUFFER_OFFSET
		local applyValue = buffer.readu8(channelBuffer, 1) - BUFFER_OFFSET

		local readIndex = 2
		local bufferLen = buffer.len(channelBuffer)

		local channel = {}
		for x = 1, BLOCK_SIZE do
			channel[x] = {}
			for y = 1, BLOCK_SIZE do
				channel[x][y] = {}
				for z = 1, BLOCK_SIZE do
					if applyCount <= 0 and readIndex < bufferLen then
						applyCount = buffer.readu8(channelBuffer, readIndex) - BUFFER_OFFSET
						applyValue = buffer.readu8(channelBuffer, readIndex + 1) - BUFFER_OFFSET
						readIndex += 2
					end
					applyCount -= 1
					channel[x][y][z] = applyValue
				end
			end
		end

		return channel
	end,
	TransformChannel = function(self, channel, modify)
		for x = 1, BLOCK_SIZE do
			for y = 1, BLOCK_SIZE do
				for z = 1, BLOCK_SIZE do
					channel[x][y][z] = modify(channel[x][y][z])
				end
			end
		end
		return channel
	end,
	SaveBlock = function(self, coordinates)
		local channels = workspace.Terrain:ReadVoxelChannels(
			self:GetBlockRegion(coordinates),
			VOXEL_SIZE,
			{ "SolidMaterial", "SolidOccupancy", "LiquidOccupancy" }
		)

		local hasWater = self:HasData(channels.LiquidOccupancy)
		local hasLand = self:HasData(channels.SolidOccupancy)
		if not hasLand and not hasWater then
			return
		end

		local folder = Instance.new("Folder")
		folder.Name = `{coordinates.X},{coordinates.Y},{coordinates.Z}`
		folder:SetAttribute("Coordinates", coordinates)
		if hasLand then
			folder:SetAttribute(
				"SolidMaterial",
				self:CompressChannel(self:TransformChannel(channels.SolidMaterial, function(material)
					return MaterialId[material] or MaterialId.Air
				end))
			)
			folder:SetAttribute(
				"SolidOccupancy",
				self:CompressChannel(self:TransformChannel(channels.SolidOccupancy, function(occupancy)
					return math.round(occupancy * BUFFER_RANGE)
				end))
			)
		end
		if hasWater then
			folder:SetAttribute(
				"LiquidOccupancy",
				self:CompressChannel(self:TransformChannel(channels.LiquidOccupancy, function(occupancy)
					return math.round(occupancy * BUFFER_RANGE)
				end))
			)
		end

		return folder
	end,
	LoadBlock = function(self, dataFolder)
		local attributes = dataFolder:GetAttributes()
		local coordinates = attributes.Coordinates
		local channels = {
			SolidMaterial = if attributes.SolidMaterial
				then self:TransformChannel(self:DecompressChannel(attributes.SolidMaterial), function(id)
					return MaterialId[id] or Enum.Material.Air
				end)
				else nil,
			SolidOccupancy = if attributes.SolidOccupancy
				then self:TransformChannel(self:DecompressChannel(attributes.SolidOccupancy), function(occupancy)
					return occupancy / BUFFER_RANGE
				end)
				else nil,
			LiquidOccupancy = if attributes.LiquidOccupancy
				then self:TransformChannel(self:DecompressChannel(attributes.LiquidOccupancy), function(occupancy)
					return occupancy / BUFFER_RANGE
				end)
				else nil,
		}

		workspace.Terrain:WriteVoxelChannels(self:GetBlockRegion(coordinates), 4, channels)
	end,

	SaveArea = function(self, dataFolder, areaMin, areaMax)
		local clearedOldData = false

		local minX, maxX = math.min(areaMin.X, areaMax.X), math.max(areaMin.X, areaMax.X)
		local minY, maxY = math.min(areaMin.Y, areaMax.Y), math.max(areaMin.Y, areaMax.Y)
		local minZ, maxZ = math.min(areaMin.Z, areaMax.Z), math.max(areaMin.Z, areaMax.Z)

		local blocksRead = 0
		local blocksTotal = (maxX - minX + 1) * (maxY - minY + 1) * (maxZ - minZ + 1)

		for x = minX, maxX do
			for y = minY, maxY do
				for z = minZ, maxZ do
					blocksRead += 1
					print(`Saving block {blocksRead} of {blocksTotal} ({math.floor(blocksRead / blocksTotal * 100)}%)`)
					if blocksRead % 20 == 0 then
						task.wait()
					end

					local folder = self:SaveBlock(Vector3.new(x, y, z))
					if folder then
						if not clearedOldData then
							clearedOldData = true
							dataFolder:ClearAllChildren()
						end
						folder.Parent = dataFolder
					end
				end
			end
		end

		if clearedOldData then
			for attribute in StandardAttributes do
				dataFolder:SetAttribute(attribute, workspace.Terrain[attribute])
			end
			for _, material in SaveMaterialColors do
				dataFolder:SetAttribute(material.Name, workspace.Terrain:GetMaterialColor(material))
			end
		end

		if not clearedOldData and next(dataFolder:GetChildren()) then
			warn(
				"No terrain found. If you're trying to delete the terrain from this mission, manually delete the TerrainData folder"
			)
		end
	end,
	LoadArea = function(self, dataFolder)
		for _, blockData in dataFolder:GetChildren() do
			self:LoadBlock(blockData)
		end

		for attribute in StandardAttributes do
			local value = dataFolder:GetAttribute(attribute)
			if value ~= nil then
				workspace.Terrain[attribute] = value
			end
		end
		for _, material in SaveMaterialColors do
			local loadedColor = dataFolder:GetAttribute(material.Name)
			if loadedColor then
				workspace.Terrain:SetMaterialColor(material, loadedColor)
			end
		end
	end,
	DeleteArea = function(self, areaMin, areaMax)
		local channels = {
			SolidMaterial = {},
			SolidOccupancy = {},
			LiquidOccupancy = {},
		}
		for x = 1, BLOCK_SIZE do
			channels.SolidMaterial[x] = {}
			channels.SolidOccupancy[x] = {}
			channels.LiquidOccupancy[x] = {}
			for y = 1, BLOCK_SIZE do
				channels.SolidMaterial[x][y] = {}
				channels.SolidOccupancy[x][y] = {}
				channels.LiquidOccupancy[x][y] = {}
				for z = 1, BLOCK_SIZE do
					channels.SolidMaterial[x][y][z] = Enum.Material.Air
					channels.SolidOccupancy[x][y][z] = 0
					channels.LiquidOccupancy[x][y][z] = 0
				end
			end
		end

		local minX, maxX = math.min(areaMin.X, areaMax.X), math.max(areaMin.X, areaMax.X)
		local minY, maxY = math.min(areaMin.Y, areaMax.Y), math.max(areaMin.Y, areaMax.Y)
		local minZ, maxZ = math.min(areaMin.Z, areaMax.Z), math.max(areaMin.Z, areaMax.Z)

		for x = minX, maxX do
			for y = minY, maxY do
				for z = minZ, maxZ do
					workspace.Terrain:WriteVoxelChannels(self:GetBlockRegion(Vector3.new(x, y, z)), 4, channels)
				end
			end
		end
	end,
	DeleteCoordinates = function(self, coordinates)
		local channels = {
			SolidMaterial = {},
			SolidOccupancy = {},
			LiquidOccupancy = {},
		}
		for x = 1, BLOCK_SIZE do
			channels.SolidMaterial[x] = {}
			channels.SolidOccupancy[x] = {}
			channels.LiquidOccupancy[x] = {}
			for y = 1, BLOCK_SIZE do
				channels.SolidMaterial[x][y] = {}
				channels.SolidOccupancy[x][y] = {}
				channels.LiquidOccupancy[x][y] = {}
				for z = 1, BLOCK_SIZE do
					channels.SolidMaterial[x][y][z] = Enum.Material.Air
					channels.SolidOccupancy[x][y][z] = 0
					channels.LiquidOccupancy[x][y][z] = 0
				end
			end
		end

		for _, coordinate in coordinates do
			workspace.Terrain:WriteVoxelChannels(self:GetBlockRegion(coordinate), 4, channels)
		end
	end,
}

return module
