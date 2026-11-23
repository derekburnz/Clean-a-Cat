--!strict
-- ToolsBoardController: the Tools board beside the tub, as a placeholder part with one prompt per tool. The
-- player walks up and taps the prompt (a button on touch, a key or gamepad button elsewhere); the server
-- (ToolService) checks and takes the coins. An owned tool's prompt goes away. Nothing opens by itself.
-- Behind the LiveFlags switch `toolsBoard`.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local ToolRules = require(Shared:WaitForChild("ToolRules"))

local FLAG = "toolsBoard"
local BOARD_SIZE = Vector3.new(4, 5, 0.4)

local ToolsBoardController = {}

local board: Part? = nil
local connections: { RBXScriptConnection } = {}

local function owns(id: string): boolean
	return Players.LocalPlayer:GetAttribute(ToolRules.ATTRIBUTE_PREFIX .. id) == true
end

local function enable()
	if board then
		return
	end
	local part = Instance.new("Part")
	part.Name = "PH_ToolsBoard"
	part.Size = BOARD_SIZE
	part.Color = Color3.fromRGB(180, 140, 100)
	part.Anchored = true
	part.CanCollide = true
	part.CFrame = CFrame.new(ToolRules.BOARD_POSITION + Vector3.new(0, BOARD_SIZE.Y / 2, 0))
	for index, id in ToolRules.IDS do
		local tool = ToolRules.TOOLS[id]
		local spot = Instance.new("Attachment")
		spot.Name = id
		-- Rows down the front of the board, which faces the spawn (+Z).
		spot.Position = Vector3.new(0, BOARD_SIZE.Y / 2 - index, BOARD_SIZE.Z / 2)
		spot.Parent = part
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `Buy {tool.name}`
		prompt.ObjectText = `{tool.price} coins`
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = ToolRules.PROMPT_REACH
		prompt.RequiresLineOfSight = false
		prompt.Enabled = not owns(id)
		prompt.Parent = spot
		table.insert(
			connections,
			prompt.Triggered:Connect(function()
				Remotes.event("RequestBuyTool"):FireServer(id)
			end)
		)
		table.insert(
			connections,
			Players.LocalPlayer
				:GetAttributeChangedSignal(ToolRules.ATTRIBUTE_PREFIX .. id)
				:Connect(function()
					prompt.Enabled = not owns(id)
				end)
		)
	end
	part.Parent = Workspace
	board = part
end

local function disable()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
	if board then
		board:Destroy()
		board = nil
	end
end

local function refresh()
	if LiveFlags.isOn(FLAG) then
		enable()
	else
		disable()
	end
end

function ToolsBoardController.Init(_controllers: { [string]: any }) end

function ToolsBoardController.Start()
	ReplicatedStorage:GetAttributeChangedSignal(LiveFlags.ATTRIBUTE_PREFIX .. FLAG):Connect(refresh)
	refresh()
end

return ToolsBoardController
