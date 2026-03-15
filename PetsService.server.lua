-- PetService

local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local httpService = game:GetService("HttpService")
local debris = game:GetService("Debris")

local assets = replicatedStorage.Assets
local modules = replicatedStorage.Modules
local itemsFolder = modules.Shared.Pets
local remotes = replicatedStorage.Remotes
local petModels = assets.PetModels

local profiles = require("./DataService/Profiles")
local petLibrary = require(modules.Shared.PetLib)
local petReplicationFolder = workspace.Map.Game.PlayerPets

local Service = {}

function Service.inventoryFull(player: Player)
	local playerData = profiles[player]
	if playerData then
		local limit = playerData.Data.PetInventoryLimit
		local PetsInventory = playerData.Data.PetsInventory
		local count = 0
		for _,v in PetsInventory do
			count += 1
		end
		if count >= limit then
			return true
		end
		return false
	end
	return false
end
function Service.serializeSave(tbl: any) : string
	return httpService:JSONEncode(tbl)
end
function Service.deserializeSave(str: string) : any
	return httpService:JSONDecode(str)
end
function Service.generateKey(): string
	return string.sub(httpService:GenerateGUID(false), 1, 6)
end
function Service.playerHasPet(player: Player, itemName: string, ignoreUniqueID: boolean)
	if player and itemName then
		local playerData = profiles[player]
		if not playerData then return false end

		local inventory = playerData.Data.PetsInventory
		if ignoreUniqueID == true then
			for id: string, _ in inventory do
				local n = id:split("/")[1]
				if n == itemName then
					return true
				end
			end
		else
			return (inventory[itemName] and true) or false
		end
	end
	return false
end
function Service.givePet(player: Player, itemName: string, count: number)
	-- Getting PlayerData
	local playerData = profiles[player]
	if not playerData then return nil end

	-- Checking if Requires UniqueID (Ex. Pets)

	local foundItem = itemsFolder:FindFirstChild(itemName)
	if not foundItem then return nil end

	local saveValuesModule = require(foundItem.SaveValues)

	-- Finding Item in Inventory (if not UniqueID)
	local requiresUniqueID = foundItem:FindFirstChild("RequiresUniqueID")
	
	-- Checking if Inventory Full
	if Service.inventoryFull(player) then return nil end

	-- Increment Item If Found or Create New Item (w/ UniqueID if applicable)
	local itemsUpdated = {}
	if requiresUniqueID.Value == true then
		for i = 1, count do
			local identifier = foundItem.Name.."/"..Service.generateKey()

			local valueToSave = Service.serializeSave( saveValuesModule.newSave(player) )

			playerData.Data.PetsInventory[identifier] = valueToSave
			itemsUpdated[identifier] = Service.deserializeSave(playerData.Data.PetsInventory[identifier])			

			--print("Successfully gave item to ".. player.Name, identifier, valueToSave)

			if count == 1 then
				remotes.PetsInventory:FireClient(player, 
					{
						Action = "NewPet",
						PetInfo = { ID = identifier, Info = Service.deserializeSave(valueToSave) }
					}
				)
				return identifier
			end
		end
	else
		local foundItemSave = playerData.Data.PetsInventory[itemName]
		if foundItemSave then
			-- Increment
			local decoded = Service.deserializeSave(foundItemSave)
			if decoded then
				decoded.Count += count
			end
			playerData.Data.PetsInventory[itemName] = Service.serializeSave(decoded)
		else
			local valueToSave = Service.serializeSave( saveValuesModule.newSave(player) )
			playerData.Data.PetsInventory[itemName] = valueToSave
		end

		itemsUpdated[itemName] = Service.deserializeSave(playerData.Data.PetsInventory[itemName])
	end

	-- FireClient to UpdateFrame
	for index, val in itemsUpdated do
		--print(index, val)
		remotes.PetsInventory:FireClient(player, 
			{
				Action = "NewPet",
				PetInfo = { ID = index, Info = httpService:JSONDecode(val) }
			}
		)
	end
end
function Service.delete(player: Player, petId: string)
	local playerData = profiles[player]
	if playerData then
		if playerData.Data.PetsInventory[petId] then
			-- Delete
			local savedValue = Service.deserializeSave(playerData.Data.PetsInventory[petId])
			if savedValue and savedValue.CanDelete == false then
				remotes.Notify:FireClient(player, "You can't delete this Labubu!", 4)
				return
			end
			--			
			Service.unequip(player, petId) -- Unequipping if Neccessary
			playerData.Data.PetsInventory[petId] = nil
			remotes.PetsInventory:FireClient(player, {Action = "PetRemoved", ["PetId"] = petId})
		end
	end
end
function Service.equip(player: Player, petId: string)
	
	local maxPets = petLibrary.getMaxPets(player)
	
	local playerData = profiles[player]
	if playerData and maxPets and playerData.Data.PetsInventory[petId] then
		
		if #playerData.Data.EquippedPets >= maxPets then
			remotes.Notify:FireClient(player, "You already have the maximum number of pets equipped", 5)
			return
		end
		
		local foundPet = table.find(playerData.Data.EquippedPets, petId)
		if foundPet then
			-- Already Equipped
			return
		end
		
		local decodedValue = Service.deserializeSave(playerData.Data.PetsInventory[petId])
		if not decodedValue then return end
		
		-- Equip
		table.insert(playerData.Data.EquippedPets, petId)
		
		-- Updating Replication Folder
		local replicationFolder = petReplicationFolder.Server:FindFirstChild(player.Name)
		if replicationFolder then
			local index = table.find(playerData.Data.EquippedPets, petId)
			if index then
				local indexInFolder = replicationFolder:FindFirstChild(tostring(index))
				if indexInFolder then
					indexInFolder:SetAttribute("Blessing", decodedValue.Blessing)
					indexInFolder.Value = petId
				else
					local newValue = Instance.new("StringValue")
					newValue.Name = tostring(index)
					newValue.Value = petId
					newValue:SetAttribute("Blessing", decodedValue.Blessing)
					newValue.Parent = replicationFolder
				end
			end
		end
		remotes.PetsInventory:FireClient(player, {Action = "PetUpdated", PetId = petId})
		--
	end
end
function Service.unequipAll(player: Player)
	local playerData = profiles[player]
	if playerData then
		table.clear(playerData.Data.EquippedPets)
		local replicationFolder = petReplicationFolder.Server:FindFirstChild(player.Name)
		if replicationFolder then
			for _, child in replicationFolder:GetChildren() do
				if child:IsA("StringValue") then
					remotes.PetsInventory:FireClient(player, {Action = "PetUpdated", PetId = child.Value})
					child:Destroy()
				end
			end
		end
	end
end
function Service.unequip(player: Player, petId: string)
	local playerData = profiles[player]
	if playerData then
		local foundPet = table.find(playerData.Data.EquippedPets, petId)
		if foundPet then
			-- Remove
			table.remove(playerData.Data.EquippedPets, foundPet)
			
			local replicationFolder = petReplicationFolder.Server:FindFirstChild(player.Name)
			if replicationFolder then
				-- Remove all existing StringValues
				for _, child in ipairs(replicationFolder:GetChildren()) do
					if child:IsA("StringValue") then
						child:Destroy()
					end
				end
				-- Re-create StringValues for new order
				for i, petId in ipairs(playerData.Data.EquippedPets) do
					
					local decodedValue = Service.deserializeSave(playerData.Data.PetsInventory[petId])
					if not decodedValue then continue end
					
					local stringValue = Instance.new("StringValue")
					stringValue.Name = tostring(i)
					stringValue.Value = petId
					stringValue:SetAttribute("Blessing", decodedValue.Blessing)
					stringValue.Parent = replicationFolder
				end
				remotes.PetsInventory:FireClient(player, {Action = "PetUpdated", PetId = petId})
			end			
		end
	end
end
function Service.modifyInventoryLimit(target: Player, action: string, value: number)
	if target and action and value then
		local playerData = profiles[target]
		local replicationValue: IntValue = target:FindFirstChild("PetInventoryLimit")
		if playerData and replicationValue then
			if action == "Set" then
				playerData.Data.PetInventoryLimit = value
			elseif action == "Decrease" then
				playerData.Data.PetInventoryLimit = math.clamp(playerData.Data.PetInventoryLimit-value,0,math.huge)
			elseif action == "Increase" then
				playerData.Data.PetInventoryLimit += value
			end
			replicationValue.Value = playerData.Data.PetInventoryLimit
		end
	end
end

function Service.onCharacterAdded(character: Model)
end
function Service.updateInventoryLimit(player: Player)
	local playerData = profiles[player]
	if playerData then
		local additionalStorage = 0
		if game.MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1324526314) then
			-- +10 Storage
			additionalStorage += 10
		end
		if game.MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1317407448) then
			-- +25 Storage
			additionalStorage += 25
		end
		if game.MarketplaceService:UserOwnsGamePassAsync(player.UserId, 1317369342) then
			-- +50 Storage
			additionalStorage += 50
		end
		playerData.Data.PetInventoryLimit = 45+additionalStorage		
		remotes.Notify:FireClient(player, "Pet Inventory Limit Updated (Max: ".. playerData.Data.PetInventoryLimit..")", 5)
	end
end
function Service.onDataLoaded(player: Player)
	
	-- give three pets for testing
	local playerData = profiles[player]
	if playerData then
		
		--
		local EquippedPets = playerData.Data.EquippedPets
		if EquippedPets then
			for indexxxxxxxxxxx,id:string in EquippedPets do
				local split = id:split("/")
				if not itemsFolder:FindFirstChild(split[1]) then
					table.remove(EquippedPets, indexxxxxxxxxxx)
				end
			end
		end
		for id:string in playerData.Data.PetsInventory do
			local split = id:split("/")
			if not itemsFolder:FindFirstChild(split[1]) then
				playerData.Data.PetsInventory[id] = nil
			end
		end
		
		-- creating replication value for pet inventory limit
		local PetInventoryLimit = Instance.new("IntValue")
		PetInventoryLimit.Name = "PetInventoryLimit"
		
		--
		Service.updateInventoryLimit(player)
		--
		
		PetInventoryLimit.Value = playerData.Data.PetInventoryLimit
		PetInventoryLimit.Parent = player
		
		-- og labubu
		if playerData.Data.FirstJoin == true then
			playerData.Data.FirstJoin = false
			if not Service.playerHasPet(player, "OG Labubu", true) then
				local newPet = Service.givePet(player, "OG Labubu", 1)
			end
		end
		
		-- creating actual pets
		local replicationFolder = petReplicationFolder.Server:FindFirstChild(player.Name)
		if replicationFolder then
			if #playerData.Data.EquippedPets > 0 then
				for i, petId in ipairs(playerData.Data.EquippedPets) do
					local decodedValue = Service.deserializeSave(playerData.Data.PetsInventory[petId])
					if not decodedValue then continue end

					local stringValue = Instance.new("StringValue")
					stringValue.Name = tostring(i)
					stringValue.Value = petId
					stringValue:SetAttribute("Blessing", decodedValue.Blessing)
					stringValue.Parent = replicationFolder

					remotes.PetsInventory:FireClient(player, {Action = "PetUpdated", PetId = petId})
				end
			end
		end
		
		--[[
		local pet1 = Service.givePet(player, "OG Labubu", 1)
		local pet2 = Service.givePet(player, "Monster Labubu", 1)
		local pet3 = Service.givePet(player, "White Labubu", 1)
		local pet4 = Service.givePet(player, "Blue Labubu", 1)
		local pet5 = Service.givePet(player, "Tan Labubu", 1)
		local pet6 = Service.givePet(player, "Horror Labubu", 1)

		Service.equip(player, pet1)
		Service.equip(player, pet2)
		Service.equip(player, pet3)
		Service.equip(player, pet4)
		Service.equip(player, pet5)
		Service.equip(player, pet6)
		]]

		--print(playerData.Data.EquippedPets)
	end
end
function Service.init()		
	remotes.GetPlayerInventory.OnServerInvoke = function(player: Player)
		local playerData = profiles[player]
		if not playerData then
			return nil
		end
		return playerData.Data.PetsInventory
	end
	remotes.PetsInventory.OnServerEvent:Connect(function(player: Player, action: string, ...: any)
		local playerData = profiles[player]
		if not playerData then return end
		
		if player:FindFirstChild("petDebounce") then return end
		local db = Instance.new("Folder")
		db.Name = "petDebounce"
		db.Parent = player
		debris:AddItem(db, .5)
		
		local arguments = {...}
		if action == "Equip" then
			Service.equip(player, arguments[1])
		elseif action == "Unequip" then
			Service.unequip(player, arguments[1])
		elseif action == "Delete" then
			Service.delete(player, arguments[1])
		elseif action == "EquipBest" then
			if #playerData.Data.EquippedPets > 0 then
				Service.unequipAll(player)
			end
			local bestPets = petLibrary.getBestPets(
				playerData.Data.PetsInventory
			)
			if #bestPets > 0 then
				for i = 1, petLibrary.getMaxPets(player) do
					if bestPets[i] then
						Service.equip(player, bestPets[i].PetId)
					end
				end
			end
		elseif action == "UnequipAll" then
			if #playerData.Data.EquippedPets <= 0 then return end
			Service.unequipAll(player)
		end
	end)
	--
	local function playerAdded(player: Player)
		local newFolder = Instance.new("Folder")
		newFolder.Name = player.Name
		newFolder.Parent = petReplicationFolder.Server
	end
	players.PlayerAdded:Connect(playerAdded)
	players.PlayerRemoving:Connect(function(player: Player)
		local foundFolder = petReplicationFolder.Server:FindFirstChild(player.Name)
		if foundFolder then foundFolder:Destroy() end
	end)
	for _, plr: Player in players:GetPlayers() do
		playerAdded(plr)
	end
end

return Service
