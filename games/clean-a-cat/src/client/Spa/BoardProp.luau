--!strict
-- BoardProp: the Tools board and the builder board as Model-Agent's models (CleanACat_Prop_ToolsBoard and
-- CleanACat_Prop_BuildBoard, #424 and #430), or the plain placeholder slab when a model is missing. Client only: each
-- player sees their own board on their own plot. The board's prompts go on its Row attachments (Row1 down), the
-- builder's bell prompt on its Bell attachment, and the title on its Screen part.
--
--   BoardProp.make(spec, at, rows)  the board standing at `at` (its pivot on the floor, front -Z the way the spot
--                                   faces) with `rows` row spots; a model with fewer Row attachments gets the rest
--                                   made below its last one
--   BoardProp.moveTo(board, at)     the plot moved: the board goes with it
--   BoardProp.showDisplay(board, name, shown)  shows or hides the model's child Model `<asset>_Display_<name>` (the
--                                   Tools board's Bubble Soap and Pro Brush on their shelves)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardProp = {}

export type Spec = {
	asset: string, -- the model's name in ReplicatedStorage.Assets
	title: string, -- the words on its Screen
	placeholder: string, -- the slab's name when the model is missing (PH_ToolsBoard)
	size: Vector3, -- the slab's size
	color: Color3, -- the slab's colour
}

export type Board = {
	root: PVInstance, -- what is parented to Workspace and destroyed
	rows: { Attachment }, -- row 1 at the top
	bell: Attachment, -- the builder's "Tell me when it's done" spot (the slab's foot)
	displays: { [string]: { Instance } }, -- the parts and decals of the model's _Display_ children, by name
}

local ROW_STEP = 0.58 -- studs between rows made below a model's last Row (its own Row spacing on the builder board)

local function screenText(screen: BasePart, title: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Title"
	gui.Face = Enum.NormalId.Front -- the front (-Z) faces the way the spot faces
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 80
	gui.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.TextColor3 = Color3.fromHex("45226B") -- the kit's ink
	text.Text = title
	text.Parent = gui
	gui.Parent = screen
end

local function fromModel(spec: Spec, count: number): Board?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local asset = if assets then assets:FindFirstChild(spec.asset) else nil
	if not (asset and asset:IsA("Model")) then
		return nil
	end
	local model = (asset :: Model):Clone() :: Model
	local frame = model.PrimaryPart
	if frame == nil then
		model:Destroy()
		return nil
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			local part = item :: BasePart
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy() -- our own models ship none; a copy never runs code
		end
	end
	-- the slab blocked the way; the model's frame does the same, so nobody walks through the board
	frame.CanCollide = true
	local rows: { Attachment } = {}
	local last: Attachment? = nil
	for index = 1, math.max(count, 1) do
		local found = model:FindFirstChild(`Row{index}`, true)
		if found and found:IsA("Attachment") then
			last = found :: Attachment
			table.insert(rows, found :: Attachment)
		else
			local extra = Instance.new("Attachment")
			extra.Name = `Row{index}`
			local above = last
			if above then
				extra.Parent = above.Parent
				extra.CFrame = above.CFrame * CFrame.new(0, -ROW_STEP, 0)
			else
				extra.Parent = frame
			end
			last = extra
			table.insert(rows, extra)
		end
	end
	local bell: Attachment
	local foundBell = model:FindFirstChild("Bell", true)
	if foundBell and foundBell:IsA("Attachment") then
		bell = foundBell :: Attachment
	else
		bell = Instance.new("Attachment")
		bell.Name = "Bell"
		bell.Parent = frame
	end
	local screen = model:FindFirstChild("Screen", true)
	if screen and screen:IsA("BasePart") then
		screenText(screen :: BasePart, spec.title)
	end
	-- a display hides by its look alone, so it stays in the model: it moves with the board and goes when the board
	-- does (Review-QA on #432)
	local displays: { [string]: { Instance } } = {}
	local prefix = `{spec.asset}_Display_`
	for _, item in model:GetDescendants() do
		if item:IsA("Model") and string.sub(item.Name, 1, #prefix) == prefix then
			local looks: { Instance } = {}
			for _, piece in item:GetDescendants() do
				if piece:IsA("BasePart") or piece:IsA("Decal") then
					table.insert(looks, piece)
				end
			end
			displays[string.sub(item.Name, #prefix + 1)] = looks
		end
	end
	local root: PVInstance = model
	return { root = root, rows = rows, bell = bell, displays = displays }
end

local function fromSlab(spec: Spec, count: number): Board
	local part = Instance.new("Part")
	part.Name = spec.placeholder
	part.Size = spec.size
	part.Color = spec.color
	part.Anchored = true
	local rows: { Attachment } = {}
	for index = 1, count do
		local spot = Instance.new("Attachment")
		spot.Name = `Row{index}`
		spot.Position = Vector3.new(0, spec.size.Y / 2 - index, -spec.size.Z / 2) -- down the front (-Z)
		spot.Parent = part
		table.insert(rows, spot)
	end
	local bell = Instance.new("Attachment")
	bell.Name = "Bell"
	bell.Position = Vector3.new(0, -spec.size.Y / 2 + 0.5, -spec.size.Z / 2) -- at the foot
	bell.Parent = part
	local root: PVInstance = part
	return { root = root, rows = rows, bell = bell, displays = {} }
end

local function pivotFor(board: Board, at: CFrame): CFrame
	local root = board.root
	if root:IsA("BasePart") then
		return at * CFrame.new(0, (root :: BasePart).Size.Y / 2, 0) -- the slab's middle, its foot on the floor
	end
	return at -- the models' pivots are on the floor
end

function BoardProp.make(spec: Spec, at: CFrame, count: number): Board
	local board = fromModel(spec, count) or fromSlab(spec, count)
	board.root:PivotTo(pivotFor(board, at))
	return board
end

function BoardProp.moveTo(board: Board, at: CFrame)
	board.root:PivotTo(pivotFor(board, at))
end

function BoardProp.showDisplay(board: Board, name: string, shown: boolean)
	local looks = board.displays[name]
	if looks == nil then
		return
	end
	for _, piece in looks do
		if piece:IsA("BasePart") then
			(piece :: BasePart).LocalTransparencyModifier = if shown then 0 else 1
		elseif piece:IsA("Decal") then
			(piece :: Decal).LocalTransparencyModifier = if shown then 0 else 1
		end
	end
end

return BoardProp
