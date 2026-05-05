local StringConversion = require(script.Parent.Parent.Util.StringConversion)

local EnumTypes = require(script.Parent.Parent.Types.Enums.Main)

local function CreateEnumWriter(keys)
	return function(value)
		local index = keys[value.Name] or 1
		return StringConversion.NumberToString(index, 1)
	end
end

local WriteEnum

WriteEnum = {
	Material = CreateEnumWriter(EnumTypes.Materials),
	PartType = CreateEnumWriter(EnumTypes.PartTypes),
	NormalId = CreateEnumWriter(EnumTypes.NormalId),

	MeshType = CreateEnumWriter(EnumTypes.MeshType),
	RenderFidelity = CreateEnumWriter(EnumTypes.RenderFidelity),
	CollisionFidelity = CreateEnumWriter(EnumTypes.CollisionFidelity),

	ParticleEmitterShape = CreateEnumWriter(EnumTypes.ParticleEmitterShape),
	ParticleEmitterShapeInOut = CreateEnumWriter(EnumTypes.ParticleEmitterShapeInOut),
	ParticleEmitterShapeStyle = CreateEnumWriter(EnumTypes.ParticleEmitterShapeStyle),
	ParticleOrientation = CreateEnumWriter(EnumTypes.ParticleOrientation),

	ResamplerMode = CreateEnumWriter(EnumTypes.ResamplerMode),
	SurfaceGuiSizingMode = CreateEnumWriter(EnumTypes.SurfaceGuiSizingMode),

	TextureMode = CreateEnumWriter(EnumTypes.TextureMode),
}

return WriteEnum