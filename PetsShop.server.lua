-- PetService.shop.lua

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")
local debris = game:GetService("Debris")

local assets = replicatedStorage.Assets
local modules = replicatedStorage.Modules
local itemsFolder = modules.Shared.Pets
local remotes = replicatedStorage.Remotes
local playSound = game.ReplicatedStorage.Remotes.PlaySound
local petModels = assets.PetModels

local profiles = require("./DataService/Profiles")
local petLibrary = require(modules.Shared.PetLib)
local petReplicationFolder = workspace.Map.Game.PlayerPets
local petService = require("./PetService")
local serverInfo = replicatedStorage.SERVER_INFO


local shop = {
	RANDOM = Random.new(),
	ROLL_ATTEMPTS = 5,
	MAX_STOCK_COUNT = 3,
}

function shop.restock()
	for _, player: Player in players:GetPlayers() do
		local playerData = profiles[player]
		if playerData then
			--
			local Player_Pet_Shop = player:FindFirstChild("Player_Pet_Shop")
			if not Player_Pet_Shop then continue end
			-- Restocking Each Player's PetShop
			local givenCounts = {}
			for i = 1,shop.ROLL_ATTEMPTS do
				local random = shop.RANDOM:NextInteger(0, 100)
				local chosenRarity = "Common"
				if random <= 1 then
					-- Mythic
					chosenRarity = "Mythic"
				elseif random <= 4 then
					-- Legendary
					chosenRarity = "Legendary"
				elseif random <= 10 then
					-- Epic
					chosenRarity = "Epic"
				elseif random <= 15 then
					-- Rare
					chosenRarity = "Rare"
				elseif random <= 25 then
					-- Uncommon
					chosenRarity = "Uncommon"
				elseif random <= 45 then
					-- Common
					chosenRarity = "Common"
				end
				-- Giving Random Pet of Chosen Rarity
				local labubuPool = {}
				for _,v in itemsFolder:GetChildren() do 
					if v:IsA("Folder") and v:FindFirstChild("Rarity") and v.Rarity.Value == chosenRarity then
						table.insert(labubuPool, v) 
					end 
				end
				if #labubuPool > 0 then
					local chosenPet = labubuPool[shop.RANDOM:NextInteger(1, #labubuPool)].Name
					local randomCount = math.random(1, 3)
					if givenCounts[chosenPet] and givenCounts[chosenPet]+randomCount >= 3 then
					else
						if not givenCounts[chosenPet] then
							givenCounts[chosenPet] = randomCount
						else
							givenCounts[chosenPet] += randomCount
						end
					end
				end
			end
			-- Giving Labubus to Player's Shop
			for petName: string, count: number in givenCounts do
				if Player_Pet_Shop[petName].Value+count >= shop.MAX_STOCK_COUNT then
					continue
				end
				Player_Pet_Shop[petName].Value += count
			end
		end
	end
	
	--
	
	remotes.Notify:FireAllClients("🐰 The Pet Shop has been Restocked! 🐰", 5, {Gradient = "Shop_Restocked"})
end
function shop.onDataLoaded(player: Player)
	-- Loading PetShop Replication Folder
	local function changedFunction(player: Player, object: IntValue)
		local playerData = profiles[player]
		if playerData then
			playerData.Data.PetShop[object.Name] = object.Value
			object.Changed:Connect(function()
				playerData.Data.PetShop[object.Name] = object.Value
			end)
		end
	end
	if player then
		local playerData = profiles[player]
		if playerData then
			local petShopFolder = Instance.new("Folder")
			petShopFolder.Name = "Player_Pet_Shop"
			
			for petName: string, petCount: number in playerData.Data.PetShop do
				if not itemsFolder:FindFirstChild(petName) then
					playerData.Data.PetShop[petName] = nil
				else
					local intValue = Instance.new("IntValue")
					intValue.Name = petName
					intValue.Value = petCount
					intValue.Parent = petShopFolder
					changedFunction(player, intValue)
				end
			end
			-- Reconciling
			for _,v in itemsFolder:GetChildren() do
				if v:IsA("Folder") and not playerData.Data.PetShop[v.Name] then
					playerData.Data.PetShop[v.Name] = 0
					local intValue = Instance.new("IntValue")
					intValue.Name = v.Name
					intValue.Value = 0
					intValue.Parent = petShopFolder
					changedFunction(player, intValue)
				end
			end
			petShopFolder.Parent = player
		end
	end
	--
end
function shop.init()
	--[[
		Make Shop Rotate like Grow a Garden / Blox Fruits (Every 5 Minutes Labubus in stock rotate)
	]]
	
	-- Compute the next restock time, globally, using os.time()
	local function getNextRestockTime()
		local now = os.time()
		return now - (now % serverInfo.PET_SHOP_RESTOCK_TIME.Value) + serverInfo.PET_SHOP_RESTOCK_TIME.Value
	end

	local nextRestockTime = getNextRestockTime()
	
	task.spawn(function()		
		while task.wait(1) do
			local secondsLeft = nextRestockTime - os.time()
			if secondsLeft <= 0 then
				-- Restock shop
				shop.restock()
				-- Schedule next restock
				nextRestockTime = getNextRestockTime()
			end
			serverInfo.RESTOCK_COUNTDOWN.Value = math.max(0, secondsLeft)
		end
	end)
	
	remotes.BuyLabubu.OnServerEvent:Connect(function(player: Player, petName: string)
		local playerData = profiles[player]
		if not playerData then return end
		
		local foundFolder = modules.Shared.Pets:FindFirstChild(petName)
		local Player_Pet_Shop = player:FindFirstChild("Player_Pet_Shop")
		
		if foundFolder and Player_Pet_Shop then
			
			local found_pet = Player_Pet_Shop:FindFirstChild(petName)
			
			local price = foundFolder.Price.Value
			local leaderstats = player:FindFirstChild("leaderstats")

			if leaderstats and found_pet then
				-- Checking In Stock
				local currentStock = found_pet
				if not currentStock then return end
				if currentStock.Value <= 0 then
					remotes.Notify:FireClient(player, "This pet is not in stock!", 5)
					playSound:FireClient(player,"FailPurchase")
					return
				end
				
				-- Checking if Inventory Full
				if petService.inventoryFull(player) then
					remotes.Notify:FireClient(player, "Your inventory is full.", 5)
					return
				end
				
				-- Checking Enough Cash
				local cash = leaderstats.Cash
				if cash.Value < price then
					remotes.Notify:FireClient(player, "You don't have enough cash to purchase this!", 5)
					playSound:FireClient(player,"FailPurchase")
					return
				end
				
				currentStock.Value = math.clamp(currentStock.Value-1 ,0, math.huge)
				script.Parent.DataService.IncrementCash:Fire(player, -price)
				--
				remotes.Notify:FireClient(player, "Purchase Successfull!", 5, {Gradient = "Quest_Completed"})
				petService.givePet(player, petName, 1)
				replicatedStorage.Remotes.NewLabubu:FireClient(player, petName)
				playSound:FireClient(player,"SuccessPurchase")
				--
			end
		end
	end)
end

return shop
