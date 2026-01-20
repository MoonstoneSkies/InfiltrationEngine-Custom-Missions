local ENUM = script.Parent
local GUI_ENUM = ENUM.GUI
local PARTICLE_ENUM = ENUM.Particles

local ALL_ENUMS = {
	CollisionFidelity = ENUM.CollisionFidelity,
	Materials         = ENUM.Materials,
	MeshType          = ENUM.MeshType,
	NormalId          = ENUM.NormalId,
	PartTypes         = ENUM.PartTypes,
	RenderFidelity    = ENUM.RenderFidelity,

	ResamplerMode        = GUI_ENUM.ResamplerMode,
	SurfaceGuiSizingMode = GUI_ENUM.SurfaceGuiSizingMode,

	ParticleEmitterShape      = PARTICLE_ENUM.ParticleEmitterShape,
	ParticleEmitterShapeInOut = PARTICLE_ENUM.ParticleEmitterShapeInOut,
	ParticleEmitterShapeStyle = PARTICLE_ENUM.ParticleEmitterShapeStyle,
	ParticleOrientation       = PARTICLE_ENUM.ParticleOrientation
}

local enumsMain = {}

for k, v in pairs(ALL_ENUMS) do
	enumsMain[k] = require(v)
end

return enumsMain