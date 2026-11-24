--!strict
-- Wallet: how the coin counter reads the server's coins. Pure, so it is tested in tests/specs/Wallet.spec.luau.
--
-- The server mirrors the save's coins onto the Player attribute ATTRIBUTE after every change (Services/WalletService)
-- so the HUD can show them (#210). It is display only: the server never reads the attribute back, so a client that
-- changes its own copy changes nothing.
local Wallet = {}

Wallet.ATTRIBUTE = "Coins"
Wallet.SHORT_FROM = 1_000_000 -- from here the counter shows 1.2M, 3.4B (the screens' fit rule)

local SUFFIXES: { { size: number, letter: string } } = {
	{ size = 1e12, letter = "T" },
	{ size = 1e9, letter = "B" },
	{ size = 1e6, letter = "M" },
}

-- 1240 -> "1,240"; 1_250_000 -> "1.2M"; 3_400_000_000 -> "3.4B". Negative, NaN or missing reads as 0, and fractions
-- round down, so a bad value never shows as a weird string.
function Wallet.format(coins: unknown): string
	local n = if type(coins) == "number"
			and coins == coins
			and coins > 0
		then math.floor(coins)
		else 0
	if n >= Wallet.SHORT_FROM then
		for _, suffix in SUFFIXES do
			local size, letter = suffix.size, suffix.letter
			if n >= size then
				-- one decimal, rounded down so 1,999,999 never shows as 2.0M
				local tenths = math.floor(n / size * 10)
				local whole, part = tenths // 10, tenths % 10
				return if part == 0 then `{whole}{letter}` else `{whole}.{part}{letter}`
			end
		end
	end
	local digits = tostring(n)
	local out = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

return Wallet
