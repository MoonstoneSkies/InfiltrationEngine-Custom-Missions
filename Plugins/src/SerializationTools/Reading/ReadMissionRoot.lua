-- Stopgap code for handling state of the Mission root (i.e. the DebugMission folder)
-- This was previously a global in Read.lua but that doesn't work anymore having extracted Instance References to ReadPrimitive
-- As such, the global state has been extracted to this module
-- This will likely be removed as further restructuring continues, with more significant logic changes

local ReadMissionRoot = {}
ReadMissionRoot._missionRoot = nil

function ReadMissionRoot.IsSet(self)
	return self._missionRoot ~= nil
end

function ReadMissionRoot.Get(self)
	return self._missionRoot
end

function ReadMissionRoot.Set(self, mission)
	self._missionRoot = mission
	if mission == nil then return end
	mission:SetAttribute("Loaded", false)
end

function ReadMissionRoot.WaitForFinalize(self)
	if self._missionRoot:GetAttribute("Loaded") == true then return end
	self._missionRoot:GetAttributeChangedSignal("Loaded"):Wait()
end

function ReadMissionRoot.Finalize(self)
	self._missionRoot:SetAttribute("Loaded", true)
end

function ReadMissionRoot.TrySet(self, mission)
	if self._missionRoot ~= nil then return end
	if mission.Name ~= "DebugMission" then return end
	self._missionRoot = mission
end

return ReadMissionRoot