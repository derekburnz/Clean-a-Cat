--!strict
-- The one list of RemoteEvents. The server (NetService) creates them in ReplicatedStorage.Remotes at start;
-- the client waits for them. Every client -> server call is validated and rate limited in NetService.
-- Write each remote's arguments and what the server checks beside its name, so a reviewer can compare.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FolderName = "Remotes"

-- Client -> server: (args) and what the server checks.
Remotes.ClientToServer = {
	"Ping", -- ()  an example to copy: no arguments, 2 a second at most
	-- Spa loop (SpaService, behind scrubPrototype). catId must be the player's current cat; order and timing are
	-- SpaRules' checks on the server. seq numbers the client's reports; the server echoes it in CatStage.
	"RequestCat", -- ()  1 a second; resends the current dirty cat or hands out a new one
	"ReportScrubbed", -- (catId: int, seq: int)  2 a second; dirty -> clean
	"ReportBrushStroke", -- (catId: int, seq: int)  8 a second; counts toward SpaRules.BRUSH_STROKES
	"RequestPickBow", -- (catId: int, seq: int, bowId: one of SpaRules.BOWS)  2 a second; fluffed -> styled
	"RequestPhoto", -- (catId: int, seq: int)  2 a second; styled -> done and pays once, no sooner than MIN_VISIT_SECONDS
	-- Tools board (ToolService, behind toolsBoard).
	"RequestBuyTool", -- (toolId: one of ToolRules.IDS)  1 a second; switch on, save loaded, near the board, enough coins, not owned
}

-- Server -> client.
Remotes.ServerToClient = {
	"Notice", -- (kind: "info" | "warning", text: string)  a short line the client shows as a toast
	"CatReady", -- (catId: number, kind: string?, needs: { CatRules.Need }?, locked: { CatRules.Need }?, stray: boolean?)
	-- a dirty cat is in the tub; kind and needs come with a customer's cat or a stray, locked lists needs whose station
	-- is not built, stray is true for a stray (switch strays) that moves into the window once clean
	"CustomerQueue", -- (kinds: { string })  the cats waiting at the door, front first (switch customers)
	"Residents", -- (list: { { cat: string, bow: string? } })  the display window's cats, in order (switch strays)
	"WindowTips", -- (coins: number, total: number)  window cats tipped; total is the save's coins (switch strays)
	"PhotoPaid", -- (catId: number, coins: number, total: number)  the photo paid; total is the save's coins
	"CatStage", -- (catId: number, seq: number, stage: SpaRules.Stage, strokes: number, photoWaiting: boolean)  the server's view
	-- after every spa report, so a client whose step was refused falls back to it instead of getting stuck
}

function Remotes.folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Remotes.FolderName)
	if existing ~= nil then
		return existing :: Folder
	end
	return ReplicatedStorage:WaitForChild(Remotes.FolderName) :: Folder
end

function Remotes.event(name: string): RemoteEvent
	return Remotes.folder():WaitForChild(name) :: RemoteEvent
end

return Remotes
