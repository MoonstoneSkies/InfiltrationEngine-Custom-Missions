local HistoryService = {}

local CHS = game:GetService("ChangeHistoryService")

function HistoryService.Record(label, fn)
	local recording = CHS:TryBeginRecording(label)
	if not recording then
		fn()
		return
	end

	local success, err = pcall(fn)

	if success then
		CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
	else
		CHS:FinishRecording(recording, Enum.FinishRecordingOperation.Cancel)
		error(err)
	end
end

return HistoryService
