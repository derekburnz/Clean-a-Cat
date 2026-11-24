--!strict
-- MascotController: a tap on Suds on his bed (MascotService, switch sudsMascot, #285) fires Moments.SudsTapped, so
-- effects and sound play the purr and the hop. Only a look: nothing goes to the server, and no window opens. Any
-- player's Suds can be tapped, so a friend visiting the spa can pet him too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveFlags = require(Shared:WaitForChild("LiveFlags"))
local Moments = require(Shared:WaitForChild("Moments"))
local SpaLayout = require(Shared:WaitForChild("SpaLayout"))
local SudsRules = require(Shared:WaitForChild("SudsRules"))

local TAP_GAP = 0.6 -- seconds between taps that count, so mashing plays one hop at a time

local MascotController = {}

local hooked: { [ClickDetector]: boolean } = {}
local lastTap = -math.huge

local function hook(instance: Instance)
	if not instance:IsA("ClickDetector") or hooked[instance :: ClickDetector] then
		return
	end
	local model = instance.Parent
	if model == nil or not model:IsA("Model") or model:GetAttribute("Mascot") ~= true then
		return
	end
	local detector = instance :: ClickDetector
	hooked[detector] = true
	detector.MouseClick:Connect(function()
		if not LiveFlags.isOn(SudsRules.MASCOT_FLAG) or os.clock() - lastTap < TAP_GAP then
			return
		end
		lastTap = os.clock()
		Moments.SudsTapped:Fire(model :: Model)
	end)
	detector.Destroying:Connect(function()
		hooked[detector] = nil
	end)
end

function MascotController.Init(_controllers: { [string]: any }) end

local function watch(plots: Instance)
	plots.DescendantAdded:Connect(hook)
	for _, descendant in plots:GetDescendants() do
		hook(descendant)
	end
end

function MascotController.Start()
	-- The street's plots folder comes and goes with spaPlot (PlotService).
	Workspace.ChildAdded:Connect(function(child: Instance)
		if child.Name == SpaLayout.PLOTS_FOLDER then
			watch(child)
		end
	end)
	local plots = Workspace:FindFirstChild(SpaLayout.PLOTS_FOLDER)
	if plots then
		watch(plots)
	end
end

return MascotController
