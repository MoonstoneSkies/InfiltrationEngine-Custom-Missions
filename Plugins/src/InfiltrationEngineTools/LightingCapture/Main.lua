local module = {}

local Lighting = game:GetService("Lighting")

local LIGHTING_PROPS = {
	"Ambient", "Brightness", "ColorShift_Bottom", "ColorShift_Top",
	"EnvironmentDiffuseScale", "EnvironmentSpecularScale",
	"GlobalShadows", "OutdoorAmbient", "ShadowSoftness",
	"ClockTime", "GeographicLatitude", "ExposureCompensation",
	"FogColor", "FogEnd", "FogStart",
}

local EFFECT_PROPS = {
	Atmosphere           = { "Density", "Offset", "Color", "Decay", "Glare", "Haze" },
	Sky                  = {
		"SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp",
		"StarCount", "SunAngularSize", "SunTextureId", "MoonAngularSize", "MoonTextureId",
		"MoonPhase", "CelestialBodiesShown",
	},
	BloomEffect          = { "Intensity", "Size", "Threshold", "Enabled" },
	BlurEffect           = { "Size", "Enabled" },
	ColorCorrectionEffect = { "Brightness", "Contrast", "Saturation", "TintColor", "Enabled" },
	DepthOfFieldEffect   = { "FarIntensity", "FocusDistance", "InFocusRadius", "NearIntensity", "Enabled" },
	SunRaysEffect        = { "Intensity", "Spread", "Enabled" },
	Clouds               = { "Cover", "Density", "Color", "Enabled" },
}

function module.Capture()
	if not workspace:FindFirstChild("DebugMission") then
		warn("DebugMission not found in workspace!")
		return
	end

	local missionSetup = workspace.DebugMission:FindFirstChild("MissionSetup")
	if not missionSetup then
		warn("MissionSetup not found inside DebugMission!")
		return
	end

	local existing = missionSetup:FindFirstChild("CustomLighting")
	if existing then
		existing:Destroy()
	end

	local customLighting = Instance.new("BoolValue")
	customLighting.Name = "CustomLighting"
	customLighting.Value = true

	for _, prop in LIGHTING_PROPS do
		local ok, val = pcall(function() return Lighting[prop] end)
		if ok and val ~= nil then
			customLighting:SetAttribute(prop, val)
		end
	end

	for _, child in Lighting:GetChildren() do
		if not (child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") or child:IsA("Clouds")) then
			continue
		end

		local props = EFFECT_PROPS[child.ClassName]
		if not props then
			continue
		end

		local childVal = Instance.new("BoolValue")
		childVal.Name = child.Name
		childVal.Value = true
		childVal:SetAttribute("ClassName", child.ClassName)

		for _, prop in props do
			local ok, val = pcall(function() return child[prop] end)
			if ok and val ~= nil then
				childVal:SetAttribute(prop, val)
			end
		end

		childVal.Parent = customLighting
	end

	customLighting.Parent = missionSetup
	print("CustomLighting captured to DebugMission/MissionSetup/CustomLighting")
end

return module
