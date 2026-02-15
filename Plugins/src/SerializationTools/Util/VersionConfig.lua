local VERSION_LATEST = 1

local CODE_VERSION_LOOKUP = {
	[0] = { ReplaceNewlines = false },
	[1] = { ReplaceNewlines = true  }
}

-- This works, Lua counts table lengths starting from 1
if #CODE_VERSION_LOOKUP > VERSION_LATEST then
	warn("SerializerDev : Version bumped but no lookup settings defined! Fix before submitting!")
end

local versionConfig = {
	LatestVersion = VERSION_LATEST,

	VersionNumber = VERSION_LATEST,
	VersionNumber_API = 1,
	
	ReplaceNewlines = true,
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

return versionConfig