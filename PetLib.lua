-- PetLibrary
--[[
	Shared pet functions
]]

local replicatedStorage = game:GetService("ReplicatedStorage")
local marketPlaceService = game:GetService("MarketplaceService")

local modules = replicatedStorage:WaitForChild("Modules")
local petsFolder = modules.Shared.Pets

local library = {
	blessingsLib = require(script.Blessings),
	rarityOrder = {
		"Common",
		"Uncommon",
		"Rare",
		"Epic",
		"Legendary",
		"Exclusive"
	},
	Rarities = {
		Common = {
			Color = Color3.fromRGB(67, 255, 46)
		},
		Uncommon = {
			Color = Color3.fromRGB(255, 167, 43)
		},
		Rare = {
			Color = Color3.fromRGB(49, 200, 255)
		},
		Epic = {
			Color = Color3.fromRGB(162, 56, 255)
		},
		Legendary = {
			Color = Color3.fromRGB(255, 57, 60)
		},
		Exclusive = {
			Color = Color3.fromRGB(255, 63, 5)
		},
	},
	labubuShopOrder = {
		"OG Labubu",
		"Blue Labubu",
		"Green Labubu",
		"Pink Labubu",
		"Grey Labubu",
		"Tan Labubu",
		"White Labubu",
		"Monster Labubu"
	},
}

function library.getColorFromRarity(rarity: string)
	if library.Rarities[rarity] then
		return library.Rarities[rarity].Color
	end
	return Color3.fromRGB(255,255,255)
end
function library.getBestPets(allPets: any)
	local sorted = {}
	for petId: string, _ in allPets do
		local trueName = petId:split("/")[1]
		if trueName then
			local foundFolder = petsFolder:FindFirstChild(trueName)
			if foundFolder then
				table.insert(sorted, {PetId = petId, BoostValue = foundFolder.SpeedBoost.Value})
			end
		end
	end
	table.sort(sorted, function(a, b)
		return a.BoostValue > b.BoostValue
	end)
	return sorted
end
function library.getMaxPets(player: Player)
	if marketPlaceService:UserOwnsGamePassAsync(player.UserId, 1329957565) then
		return 5
	end
	return 3
end

return library
