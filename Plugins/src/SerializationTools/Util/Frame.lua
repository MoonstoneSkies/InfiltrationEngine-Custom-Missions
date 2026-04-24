local Actor = require(script.Parent.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived

local FrameMod = {}

local function merge(props, defaults)
	for k, v in pairs(defaults) do
		if props[k] == nil then
			props[k] = v
		end
	end
	return props
end

local function _frame(props, children)
	merge(props, { BorderSizePixel = 0, ClipsDescendants = true })
	return Create("Frame", props, children)
end

function FrameMod.Colored(color, props, children)
	props.BackgroundColor3 = color
	return _frame(
		props,
		children
	)
end

function FrameMod.Invisible(props, children)
	return _frame(
		merge(props, { BackgroundTransparency = 1 }),
		children
	)
end

function FrameMod.Standard(props, children)
	return _frame(
		merge(props, { BackgroundTransparency = 0.5, BackgroundColor3 = Color3.new(0,0,0) }),
		children
	)
end

function FrameMod.Round(frame, by)
	local corner = Create("UICorner", { CornerRadius = UDim.new(0, by) })

	corner.Parent = frame
	return frame, corner
end

local sideToRot = {
	Top = 90,
	Right = 180,
	Left = 0,
	Bottom = -90
}
function FrameMod.RoundSide(frame, by, side)
	-- Abuses some jank found on the devforum
	-- Why is this not a built-in thing?
	local corner = Create("UICorner", { CornerRadius = UDim.new(0, by) })

	local rot = sideToRot[side] or 0

	local stroke = Create("UIStroke", {
		Color = frame.BackgroundColor3,
		LineJoinMode = Enum.LineJoinMode.Bevel,
		Thickness = 0.1
	}, {
		Create("UIGradient", {
			Rotation = rot,
			Transparency = NumberSequence.new(0, 1)
		})
	})

	-- Extra sprinkle of weirdness on top
	-- Patches up some single-pixel holes around the edges
	local patchUp = FrameMod.Colored(frame.BackgroundColor3, {
		Size = UDim2.fromScale(1, 1)
	}, {
		corner:Clone()
	})

	local colorUpdate = frame:GetPropertyChangedSignal("BackgroundColor3"):Connect(function() stroke.Color = frame.BackgroundColor3 patchUp.BackgroundColor3 = frame.BackgroundColor3 end)
	frame.Destroying:Once(function() colorUpdate:Disconnect() end)

	patchUp.Parent = frame
	corner.Parent = frame
	stroke.Parent = frame
	return frame, corner, stroke
end

-- Please don't kill me for this
-- I figure it makes sense to at least imitate the interface of Button()
setmetatable( FrameMod, { __call = function(self, ...) return FrameMod.Standard(...) end } )

return FrameMod