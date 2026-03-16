local runService = game:GetService("RunService")

local commonColour  = require(script.Parent.Parent.Parent.Util.CommonColors)
local notifSeverity = require(script.Parent.Severity)

-- We get to do UI, yay!
local Actor = require(script.Parent.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local Frame = require(script.Parent.Parent.Parent.Util.Frame)

local textBoundsParams = Instance.new("GetTextBoundsParams")

return function(sizeState, timeState)

	return function(data)

		local severityData = data.Severity
		local duration = timeState._Value * severityData.TimeMult

		local livedDuration = State(0)
		local lifetimeFac  = Derived(function(dur)
			if math.isinf(duration) then
				return 0
			end
			return dur / duration
		end, livedDuration)

		local lifetimeCol  = Derived(function(fac)
			if math.isinf(duration) then
				return severityData.Color
			end
			return commonColour.SOLO_GREEN:Lerp(commonColour.LEGEND_RED, fac)
		end, lifetimeFac)
		local lifetimeSize = Derived(function(fac) return UDim2.new(1 - fac, 0, 0, 8) end, lifetimeFac)

		local lifetimePanel = Frame.RoundSide(Frame.Colored(
			lifetimeCol,
			{
				AnchorPoint = Vector2.yAxis,

				Size = lifetimeSize,
				Position = UDim2.new(0, 0, 1, 0),
				Name = "LifetimeBar"
			}
		), 8, "Top")

		local notifContentTitleIcon = Create(
			"ImageLabel",
			{
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size     = UDim2.fromOffset(24, 24),
				SizeConstraint = Enum.SizeConstraint.RelativeYY,
				BackgroundTransparency = 1,
				ImageTransparency = 0.5,
				Image = `rbxassetid://{severityData.ImageID}`,
				-- Not a fan of how this looks
				--ImageColor3 = severityData.Color
			}
		)

		local notifContentTitle = Create(
			"TextLabel",
			{
				Text = data.Title,
				TextColor3 = commonColour.WHITE,
				Name = "Title",
				Size = UDim2.fromScale(1, 0.25),
				FontFace = Font.fromName("Zekton", Enum.FontWeight.Bold),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
			},
			{
				notifContentTitleIcon,
				Create("UITextSizeConstraint", { MaxTextSize = 21 })
			}
		)

		local notifContentSeparator = Frame.Colored(
			severityData.Color,
			{
				Name = "Separator",
				Size = UDim2.new(1, 0, 0, 2),
			}
		)

		local notifContentDesc = Create(
			"TextLabel",
			{
				Text = data.Description,
				TextColor3 = commonColour.WHITE,
				TextTruncate = Enum.TextTruncate.SplitWord,
				TextWrapped = true,
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Name = "Description",
				Size = UDim2.new(1, -8, 1, 0),
				BackgroundTransparency = 1,
				FontFace = Font.fromName("Zekton"),
				RichText = data.Rich or false,
			}
		)

		-- TODO: Figure this out later
		-- Got some incredibly buggy results with trying to use the built-in auto-scaling on the canvas
		-- I've been sitting on these changes for like a week now and I would like to get a patch up
		-- This can be revisited when I come back to add support for using these as help/keybind dialogues
		local notifContentDescPanel = Create(
			"ScrollingFrame",
			{
				Name = "Description_Panel",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0.75, -14),
				ScrollBarThickness = 8,
				CanvasSize = UDim2.fromScale(0, 0)
			},
			{
				notifContentDesc
			}
		)

		local notifContentPanelList = Create("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalFlex = Enum.UIFlexAlignment.Fill
		})

		local notifContentPanelPad = Create("UIPadding", {
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft   = UDim.new(0, 4),
			PaddingRight  = UDim.new(0, 4),
			PaddingTop    = UDim.new(0, 4),
		})

		local notifContentPanel = Frame.Round(Frame.Colored(
			commonColour.GRAY,
			{
				Name = "Content",
				Size = UDim2.fromScale(1, 1)
			},
			{
				notifContentPanelList,
				notifContentPanelPad,
				notifContentTitle,
				notifContentSeparator,
				notifContentDescPanel
			}
		), 8)

		local notifPanel = Frame.Invisible(
			{
				Name = `Notif_{data.Title:gsub("%s", "")}_Panel`,
				Size = UDim2.new(1, 0, 0, sizeState._Value),
			},
			{
				notifContentPanel,
				lifetimePanel
			}
		)

		local consume = function()
			task.spawn(function()
				local runServiceSignal = runService.Heartbeat:Connect(function(dt)
					if notifPanel == nil then return end
					if notifPanel.GuiState == Enum.GuiState.Idle then
						livedDuration:set(livedDuration._Value + dt)
					end
					if notifPanel.GuiState == Enum.GuiState.Press then
						livedDuration:set(math.huge)
					end
					if livedDuration._Value >= duration then
						notifPanel:Destroy()
					end
				end)
				notifPanel.Destroying:Wait()
				runServiceSignal:Disconnect()
			end)
		end

		return notifPanel, consume
	end
end