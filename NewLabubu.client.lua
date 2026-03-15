local players = game:GetService("Players")
local runService = game:GetService("RunService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local debris = game:GetService("Debris")
local tweenService = game:GetService("TweenService")
local userInputService = game:GetService("UserInputService")

local remotes = replicatedStorage:WaitForChild("Remotes")
local assets = replicatedStorage:WaitForChild("Assets")
local modules = replicatedStorage:WaitForChild("Modules")

local viewportManager = require(modules.Packages.ViewportManager)
local localPlayer = players.LocalPlayer

local Controller = {}

function Controller.init()
	remotes.NewLabubu.OnClientEvent:Connect(function(name: string)
		local foundModel = assets.PetModels:FindFirstChild(name)
		if foundModel then

			local mouseConnection = nil
			local stopSummoning = false

			if not localPlayer:FindFirstChild("Summoning_Labubu") then
				local sl = Instance.new("BoolValue")
				sl.Name = "Summoning_Labubu"
				sl.Parent = localPlayer
			end

			--
			local viewportClone = assets.NewLabubuViewport:Clone()

			local modelClone: Model = foundModel:Clone()
			--
			--

			modelClone.Parent = viewportClone

			task.spawn(function()
				task.wait()
				for _,v in modelClone:GetDescendants() do
					local s,e = pcall(function()
						local t = v.CanCollide
					end)
					if s then
						v.CanCollide = false
						v.CanQuery = false
						v.CanTouch = false
						v.Massless = true
						v.CollisionGroup = "NoCollide"
					end
				end
			end)

			local weld = Instance.new("Weld")
			weld.Part0 = modelClone.PrimaryPart
			weld.Part1 = viewportClone.PrimaryPart
			weld.Parent = viewportClone

			viewportClone.Parent = workspace.Terrain

			task.delay(1, function()
				mouseConnection = userInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
					local shouldSkip = false
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						-- PC Left Mouse Button
						shouldSkip = true
					elseif input.UserInputType == Enum.UserInputType.Touch then
						-- Mobile Touch
						shouldSkip = true
					elseif input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonA then
						-- Console A Button
						shouldSkip = true
					end
					if shouldSkip then
						mouseConnection:Disconnect()
						mouseConnection = nil
						stopSummoning = true
					end
				end)
			end)

			--
			local depthOffset = Instance.new("NumberValue")
			depthOffset.Name = "DepthOffset"
			depthOffset.Value = -10
			depthOffset.Parent = viewportClone

			local yOffset = Instance.new("NumberValue")
			yOffset.Value = 5
			yOffset.Name = "yOffset"
			yOffset.Parent = viewportClone

			local spinOffset = Instance.new("NumberValue")
			spinOffset.Value = -540
			spinOffset.Name = "SpinOffset"
			spinOffset.Parent = viewportClone

			tweenService:Create(depthOffset, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Value = -8
			}):Play()
			tweenService:Create(yOffset, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Value = 0
			}):Play()
			tweenService:Create(spinOffset, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Value = 180
			}):Play()
			--

			task.spawn(function()

				task.spawn(function()

					local cheerAnim = modelClone.Humanoid:LoadAnimation(modelClone.AnimateScript.cheer.CheerAnim)
					cheerAnim:Play()
					cheerAnim.Looped = true

					task.wait(1)

					cheerAnim:Stop(.1)

					local anim = modelClone.Humanoid:LoadAnimation(modelClone.AnimateScript.wave.WaveAnim)
					anim:Play()
					anim.Looped = true
				end)
				task.delay(1, function()
					local Goals = TweenInfo.new(.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out,0,false,0)
					local Tween = tweenService:Create(viewportClone.Highlight,Goals,{OutlineTransparency = 1, FillTransparency = 1})
					Tween:Play()
					coroutine.wrap(function()
						Tween.Completed:Wait()
						Tween:Destroy()
					end)()
				end)
				task.delay(3, function()
					stopSummoning = true
				end)

				local tweenOut = tweenService:Create(yOffset, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Value = -10
				})
				local played = false

				while viewportClone.Parent do
					if stopSummoning == true then
						if not played then
							played = true
							for _,v in localPlayer:GetChildren() do
								if v.Name == "Summoning_Labubu" then
									v:Destroy()
								end
							end
							tweenOut:Play()
						end
					end
					viewportClone:SetPrimaryPartCFrame(workspace.CurrentCamera.CFrame * CFrame.new(0,yOffset.Value,depthOffset.Value) * CFrame.fromEulerAnglesXYZ(0,math.rad(spinOffset.Value),0))
					runService.RenderStepped:Wait()
				end
			end)

			debris:AddItem(viewportClone, 4)
			task.delay(4, function()
				if mouseConnection then
					for _,v in localPlayer:GetChildren() do
						if v.Name == "Summoning_Labubu" then
							v:Destroy()
						end
					end
					mouseConnection:Disconnect()
					mouseConnection = nil
				end
			end)
		end
	end)
end

return Controller
