local FeatureCheck = require(script.Parent.Parent.Parent.Util.FeatureCheck)

local NotifSeverity = require(script.Parent.Severity)

-- We get to do UI, yay!
local Actor = require(script.Parent.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived

local NOTIF_PAD = 8
local SCROLLBAR_SIZE = 8

local NOTIF_SIZE_FEAT = "SerializerNotifSize"
local DEFAULT_NOTIF_SIZE = 125

local NOTIF_TIME_FEAT = "SerializerNotifDuration"
local DEFAULT_NOTIF_TIME = 5

local NotificationManager = {}

local _stackPos = 1
local _notifStack = {}

local canvasSizeState = State(0)
local notifSizeState  = State(0)
local notifTimeState  = State(0)

local GuiFactory = require(script.Parent.GuiFactory)(notifSizeState, notifTimeState)

local desc_tags = { ["%[tab%]"] = '\t' }

local function description_sanitise(desc)
	desc = desc:gsub("[ \r\t]*\n[ \r\t]*", "\n"):gsub("^%s*", ""):gsub("%s*$", "")
	for tag, repl in pairs(desc_tags) do
		desc = desc:gsub(tag, repl)
	end
	return desc
end

local function feature_state_updator(state, featName, default, minimum, falseValue)
	if falseValue == nil then falseValue = minimum end
	return function()
		local setVal = FeatureCheck(featName, false)
		local setType = type(setVal)

		if setType ~= "number" and setType ~= "nil" and setType ~= "boolean" then
			warn(`{featName} set to non-numeric non-nil value! Will use default of {default}`)
			NotificationManager.Push{
				Title = `Bad {featName} Value!`,
				Description = `{featName} must be nil or a number!\n\nA default of {default} will be used.`,
				Severity = "INFO"
			}
		end

		if setType == "boolean" then
			setVal = setVal and default or falseValue
		end

		setVal = setVal or default

		if setVal < minimum then
			warn(`{featName} set to unreasonably small value (< {minimum})! Will use default of {default}`)
			NotificationManager.Push{
				Title = `Bad {featName} Value!`,
				Description = `{featName} was set to an unreasonably small value of {setVal}! A value of {minimum} or greater is expected.\n\n` ..
							  `A default of {default} will be used.`,
				Severity = "INFO"
			}
			setVal = DEFAULT_NOTIF_SIZE
		end

		state:set(
			setVal
		)
	end
end

local update_notif_size = feature_state_updator(notifSizeState, NOTIF_SIZE_FEAT, DEFAULT_NOTIF_SIZE, 100)
local update_notif_time = feature_state_updator(notifTimeState, NOTIF_TIME_FEAT, DEFAULT_NOTIF_TIME, 1.5, math.huge)

local function fuzzy_compare(num1, num2, epsilon)
	return math.abs(num1 - num2) <= epsilon
end

local function update_canvas_size(by)
	local pad = NOTIF_PAD * math.sign(by)
	canvasSizeState:set(canvasSizeState._Value + by + pad)
end

local function update_canvas_size_sticky(frame, by)
	local beforePos = frame.CanvasPosition.Y
	local canvasExtra = frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y

	-- Yes, floating point imprecision was breaking this code
	-- No, I'm not happy about it
	local sticky = fuzzy_compare(beforePos, canvasExtra, 0.01)

	update_canvas_size(by)

	if sticky then
		frame.CanvasPosition = Vector2.new(frame.CanvasPosition.X, (frame.AbsoluteCanvasSize.Y - frame.AbsoluteWindowSize.Y))
	end
end

function NotificationManager.Push(notif_data)
	if NotificationManager.Panel == nil then return false end
	local success, sev = NotifSeverity.FromInput(notif_data.Severity)
	if not success then
		warn(`Severity "{notif_data.Severity}" is not valid!`)
		return false
	end
	notif_data.Severity = sev
	notif_data.Description = description_sanitise(notif_data.Description)
	local notif, consume = GuiFactory(notif_data)
	notif.Parent = NotificationManager.Panel
	update_canvas_size_sticky(NotificationManager.Panel, notif.AbsoluteSize.Y)
	notif.Destroying:Once( function() 
		if NotificationManager.Panel == nil then return end
		update_canvas_size_sticky(NotificationManager.Panel, -notif.AbsoluteSize.Y)
	end )
	consume()
	return true
end

function NotificationManager.Init()
	if NotificationManager.Active then
		return NotificationManager.Panel
	end
	NotificationManager.Active = true

	canvasSizeState:set(0)

	local panel = Create(
		"ScrollingFrame",
		{
			Name = "NotificationPanel",
			BackgroundTransparency = 1,
			Position = UDim2.new(1, -50, 1, -50),
			Size = UDim2.new(0.5, -50, 0.5, -50),
			AnchorPoint = Vector2.new(1, 1),
			ScrollBarThickness = SCROLLBAR_SIZE,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = Derived(function(newSize)
				return UDim2.fromOffset(0, newSize)
			end, canvasSizeState),
			BorderSizePixel = 0,
			--ScrollingEnabled = false
		},
		{
			Create(
				"UIListLayout",
				{
					Padding = UDim.new(0, NOTIF_PAD),
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					VerticalAlignment = Enum.VerticalAlignment.Bottom
				}
			),
			Create(
				"UIPadding",
				{
					PaddingRight = UDim.new(0, SCROLLBAR_SIZE)
				}
			)
		}
	)

	NotificationManager.Panel = panel

	update_notif_size()
	update_notif_time()

	local signals = {}
	signals[1] = workspace:GetAttributeChangedSignal(NOTIF_SIZE_FEAT):Connect(update_notif_size)
	signals[2] = workspace:GetAttributeChangedSignal(NOTIF_TIME_FEAT):Connect(update_notif_time)

	NotificationManager.Signals = signals

	return panel
end

local signals = {}


function NotificationManager.Clean()
	if not NotificationManager.Active then
		return
	end
	NotificationManager.Active = false

	if NotificationManager.Panel ~= nil then
		NotificationManager.Panel:Destroy()
		NotificationManager.Panel = nil
	end

	for i, signal in ipairs(signals) do
		signal:Disconnect()
		signals[i] = nil
	end
end

return NotificationManager