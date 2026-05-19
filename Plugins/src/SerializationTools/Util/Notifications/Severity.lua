local commonColours = require(script.Parent.Parent.Parent.Util.CommonColors)

local function severity_data(id, time_mult, img, color) return { ID = id, ImageID = img, TimeMult = time_mult, Color = color } end
local SEVERITY_DATA = {
	INFO       = severity_data(0, 1,   "17829948066", commonColours.RECRUIT_BLUE),
	WARN       = severity_data(1, 1.5, "17829955945", commonColours.CHALLENGE_YELLOW),
	ERR        = severity_data(2, 2,   "17829927053", commonColours.LEGEND_RED),
	ERR_SEVERE = severity_data(3, 2.5, "13201179730", commonColours.LEGEND_RED)
}

local IDS = {}
local MIN, MAX = nil, nil
local ID_MIN, ID_MAX = math.huge, -math.huge
for k, v in pairs(SEVERITY_DATA) do
	IDS[k] = v.ID
	if ID_MIN > v.ID then
		MIN = v
		ID_MIN = v.ID
	elseif ID_MAX < v.ID then
		MAX = v
		ID_MAX = v.ID
	end
end

SEVERITY_DATA.MIN = MIN
SEVERITY_DATA.MAX = MAX

local sevmod = {}
sevmod.Data = SEVERITY_DATA
sevmod.IDs  = IDS

function sevmod.FromId(id)
	local clamped = math.clamp(id, ID_MIN, ID_MAX)
	if clamped ~= id then
		warn(`Notifications.Severity.FromId > ID {id} is out of bounds? Will default to {clamped}`)
	end
	return sevmod.Data[clamped]
end

function sevmod.FromName(name)
	local found = SEVERITY_DATA[name]
	return found ~= nil, found
end

function sevmod.FromInput(input)
	local inT = type(input)
	if inT == "number" then
		return true, sevmod.FromId(input)
	elseif inT == "string" then
		return sevmod.FromName(input)
	else
		return false, nil
	end
end

return sevmod