local StringConversion = require(script.Parent.Parent.Util.StringConversion)
local EnumTypes = require(script.Parent.Parent.Types.Enums.Main)

local function CreateEnumReader(enum, map)
	local ids = {}
	for i, v in map do
		ids[v] = i
	end
	return function(str, cursor)
		local num = StringConversion.StringToNumber(str, cursor, 1)
		return enum[ids[num]], cursor + 1
	end
end

local ReadEnum

ReadEnum = {
	Material = CreateEnumReader(Enum.Material, EnumTypes.Materials),
	PartType = CreateEnumReader(Enum.PartType, EnumTypes.PartTypes),
	NormalId = CreateEnumReader(Enum.NormalId, EnumTypes.NormalId),

	MeshType = CreateEnumReader(Enum.MeshType, EnumTypes.MeshType),
	RenderFidelity = CreateEnumReader(Enum.RenderFidelity, EnumTypes.RenderFidelity),
	CollisionFidelity = CreateEnumReader(Enum.CollisionFidelity, EnumTypes.CollisionFidelity),

	ParticleEmitterShape = CreateEnumReader(Enum.ParticleEmitterShape, EnumTypes.ParticleEmitterShape),
	ParticleEmitterShapeInOut = CreateEnumReader(Enum.ParticleEmitterShapeInOut, EnumTypes.ParticleEmitterShapeInOut),
	ParticleEmitterShapeStyle = CreateEnumReader(Enum.ParticleEmitterShapeStyle, EnumTypes.ParticleEmitterShapeStyle),
	ParticleOrientation = CreateEnumReader(Enum.ParticleOrientation, EnumTypes.ParticleOrientation),

	ResamplerMode = CreateEnumReader(Enum.ResamplerMode, EnumTypes.ResamplerMode),
	SurfaceGuiSizingMode = CreateEnumReader(Enum.SurfaceGuiSizingMode, EnumTypes.SurfaceGuiSizingMode),

	TextureMode = CreateEnumReader(Enum.TextureMode, EnumTypes.TextureMode),
}

return ReadEnum