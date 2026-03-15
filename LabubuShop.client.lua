local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")
local runService = game:GetService("RunService")

local remotes = replicatedStorage:FindFirstChild("Remotes")
local modules = replicatedStorage:WaitForChild("Modules")

local rebirthLib = require(modules.Shared.RebirthLib)
local simpleFormat = require(modules.Packages.FormatNumber.Simple)
local petsLibrary = require(modules.Shared.PetLib)
local petsFolder = modules.Shared.Pets

local localPlayer = players.LocalPlayer
local gameFolder = workspace:WaitForChild("Map"):WaitForChild("Game")

local function Format(Int)
	return string.format("%02i", Int)
end

local function convertToHMS(Seconds)
	local Minutes = (Seconds - Seconds%60)/60
	Seconds = Seconds - Minutes*60
	local Hours = (Minutes - Minutes%60)/60
	Minutes = Minutes - Hours*60
	return Format(Hours)..":"..Format(Minutes)..":"..Format(Seconds)
end

local uiController = {}

function uiController.init()
	local playerGui = localPlayer.PlayerGui
	local mainGui = playerGui:WaitForChild("UI", math.huge)
	
	local labubuShopFrame = mainGui.LabubuShop
	local listFrame = labubuShopFrame.Background.Inner.Frames.Inner.Main
	local shopPart = gameFolder.LabubuShopPart
	
	local blessingsFrame = labubuShopFrame.BlessingInfo
	local blessingList = blessingsFrame.Inner.Frames.Inner.Main
	local descriptionFrame = labubuShopFrame.BlessingDesc
	
	descriptionFrame.Visible = true
	descriptionFrame.Inner.Frames.Inner.Desc.Text = "-"
	
	labubuShopFrame:TweenSize(UDim2.new(0,0,0,0))
	labubuShopFrame.Visible = true
	
	-- Updating Labubu Shop
	for _,v in listFrame:GetChildren() do
		if v:IsA("Frame") then
			v:Destroy()
		end
	end
	-- Clone Shop Items
	for _, petName: string in petsLibrary.labubuShopOrder do
		local foundFolder = petsFolder:FindFirstChild(petName)
		if foundFolder then
			--
			local rarity = foundFolder.Rarity.Value
			local rarityColor = petsLibrary.getColorFromRarity(rarity)
			
			local clone = script.ItemTemplate:Clone()
			clone.Name = petName
			
			clone.Container.Title.Text = petName
			clone.Container.Title.Title.Text = petName
			
			clone.Container.Title.UIGradient.Color = ColorSequence.new(rarityColor)
			clone.Container.Title.Title.UIGradient.Color = ColorSequence.new(rarityColor)
			
			clone.Image.Image = foundFolder.IconId.Image
			
			clone.Container.Buttons.Button.Price.Text = "$"..simpleFormat.Format(foundFolder.Price.Value)
			clone.Container.Desc.Text = foundFolder.InfoDisplay.Value
			
			clone.Stroke.UIStroke.UIGradient.Color = ColorSequence.new(rarityColor)
			
			clone.Container.Buttons.Button.MouseButton1Click:Connect(function()
				remotes.BuyLabubu:FireServer(petName)
			end)
			
			clone.Parent = listFrame
			--
		end
	end
	
	-- Updating Restock Timer
	local serverInfo = replicatedStorage:FindFirstChild("SERVER_INFO")
	local function updateRestockTimer()
		labubuShopFrame.RestockTimer.Text = "Restocking in ".. convertToHMS(serverInfo.RESTOCK_COUNTDOWN.Value)
		labubuShopFrame.RestockTimer.TextLabel.Text = "Restocking in ".. convertToHMS(serverInfo.RESTOCK_COUNTDOWN.Value)
	end
	updateRestockTimer()
	serverInfo.RESTOCK_COUNTDOWN.Changed:Connect(updateRestockTimer)
	
	-- Updating Stock Counts
	
	local Player_Pet_Shop = localPlayer:WaitForChild("Player_Pet_Shop", math.huge)
	
	local function handleStockUpdate(name: string, value: number)
		local foundFrame = listFrame:FindFirstChild(name)
		if foundFrame then
			foundFrame.Container.Stock.Text = "Stock: ".. tostring(value)
			foundFrame.NoStock.Visible = (value<=0)
		end
	end
	for _, folder: Folder in petsFolder:GetChildren() do
		local found = Player_Pet_Shop:FindFirstChild(folder.Name)
		if found then
			local currentStock: IntValue = found
			if currentStock then
				handleStockUpdate(folder.Name, currentStock.Value)
				currentStock.Changed:Connect(function()
					handleStockUpdate(folder.Name, currentStock.Value)
				end)
			end
		end
	end
	
	-- Updating Blessings
	for _,v in blessingList:GetChildren() do
		if v:IsA("TextLabel") then
			v:Destroy()
		end
	end
	
	local noneClone = script.BlessingTemplate:Clone()
	noneClone.Name = "None"
	noneClone.TextColor3 = Color3.fromRGB(255,255,255)
	noneClone.Text = "None - "..petsLibrary.blessingsLib.noneChance.."%"
	noneClone.Parent = blessingList
	
	for i = 1, #petsLibrary.blessingsLib.blessings do
		local clone = script.BlessingTemplate:Clone()
		clone.Name = petsLibrary.blessingsLib.blessings[i].name
		clone.TextColor3 = petsLibrary.blessingsLib.blessings[i].color
		clone.Text = petsLibrary.blessingsLib.blessings[i].name.." - "..petsLibrary.blessingsLib.blessings[i].chance.."%"
		clone.Parent = blessingList
		clone.MouseEnter:Connect(function()
			descriptionFrame.Inner.Frames.Inner.Desc.Text = petsLibrary.blessingsLib.blessings[i].description
		end)
		clone.MouseEnter:Connect(function()
			descriptionFrame.Inner.Frames.Inner.Desc.Text = "-"
		end)
	end
	--
	
	local open = false
	
	runService.RenderStepped:Connect(function()
		local character = localPlayer.Character
		if character then
			local rootPart: BasePart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local distance = vector.magnitude(rootPart.Position-shopPart.Position)
				-- handling visibility of mid "summon"
				task.spawn(function()
					if localPlayer:FindFirstChild("Summoning_Labubu") then
						labubuShopFrame.Visible = false
					else
						labubuShopFrame.Visible = true
					end
				end)
				----
				if distance <= 7.1 then
					if not open then
						open = true
						labubuShopFrame:TweenSize(UDim2.new(0.49,0,0.568,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, .5, true)
					end
				else
					if open then
						open = false
						labubuShopFrame:TweenSize(UDim2.new(0,0,0,0), Enum.EasingDirection.Out, Enum.EasingStyle.Quint, .5, true)
					end
				end
			end
		end
	end)
end

return uiController
