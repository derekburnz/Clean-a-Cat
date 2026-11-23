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
	-- SpaRules' checks on the server.
	"RequestCat", -- ()  1 a second; resends the current dirty cat or hands out a new one
	"ReportScrubbed", -- (catId: int)  2 a second; dirty -> clean
	"ReportBrushStroke", -- (catId: int)  8 a second; strokes at least SpaRules.MIN_STROKE_GAP apart count
	"RequestPickBow", -- (catId: int, bowId: one of SpaRules.BOWS)  2 a second; fluffed -> styled
	"RequestPhoto", -- (catId: int)  2 a second; styled -> done and pays once, MIN_VISIT_SECONDS after arrival
}

-- Server -> client.
Remotes.ServerToClient = {
	"Notice", -- (kind: "info" | "warning", text: string)  a short line the client shows as a toast
	"CatReady", -- (catId: number)  a dirty cat is in the tub
	"PhotoPaid", -- (catId: number, coins: number, total: number)  the photo paid; total is the save's coins
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
