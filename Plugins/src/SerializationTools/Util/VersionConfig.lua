local VERSION_LATEST = 3

local settings = {
	ReplaceNewlines = false,
	UseCompression  = false,
	UseVectorMap    = false,
}
local function vdef(tbl)
	for k, _ in pairs(tbl) do
		if settings[k] == nil then
			warn(`Unrecognised version setting {k} - fix before submitting`)
		end
	end
	
	for k, default in pairs(settings) do
		if tbl[k] == nil then
			tbl[k] = default
		end
	end
end

local CODE_VERSION_LOOKUP = {
	[0] = vdef{},
	[1] = vdef{
		ReplaceNewlines = true
	},
	[2] = vdef{
		ReplaceNewlines = true,
		UseCompression  = true,
	},
	[3] = vdef{
		ReplaceNewlines = true,
		UseCompression  = true,
		UseVectorMap    = true
	}
}

-- This works, Lua counts table lengths starting from 1
if #CODE_VERSION_LOOKUP > VERSION_LATEST then
	warn("SerializerDev : Version bumped but no lookup settings defined! Fix before submitting!")
end

local versionConfig = {
	Distribution  = "Official",
	LatestVersion = VERSION_LATEST,

	VersionNumber = VERSION_LATEST,
	VersionNumber_API = 1,
	
	ReplaceNewlines = true,
	UseCompression  = true,
	UseVectorMap    = true
}

function versionConfig.change_version(self, to)
	local verSettings = CODE_VERSION_LOOKUP[to]
	if verSettings == nil then
		return false, "Code Version " .. tostring(to) .. " is not recognised!"
	end
	for k, v in pairs(verSettings) do
		self[k] = v
	end
	self.VersionNumber = to
	return true, nil
end

versionConfig:change_version(VERSION_LATEST)

versionConfig.OfficialDistro = (versionConfig.Distribution == "Official")

return versionConfig