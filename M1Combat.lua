-- This script runs on the CLINET SERVER

-- Game services
local RunService : RunService = game:GetService("RunService")
local rs  = game:GetService("ReplicatedStorage")

-- Folder
local eventsFolder = rs.Remotes

-- Logic Variables
local maxComboDuration = 2 --seconds
local currentComboDuration = 0
local comboCooldown = 0.8
local maxCombo = 4
local currentCombo = 0 -- do not change
local startTime = tick() -- do not change
local isRunning = false -- do not change
local canAttack = true -- do not change
local currentComboConection = nil -- do not change
local localPlayer = game.Players.LocalPlayer

local attackProcessedConnection = nil

-- Events
local AttackEvent : RemoteEvent = eventsFolder.M1Attack 
local AttackProccesedEventReturn : RemoteEvent = eventsFolder.AttackProccesedEventReturn
local BlockEvent : RemoteEvent = eventsFolder.Block
local UnblockEvent : RemoteEvent = eventsFolder.Unblock
local DashEvent : RemoteEvent = eventsFolder.Dash

local module = {}

-- O, I, Shift or any keybinds used by roblox can not be used as keybinds with this script

-- Watches for player inputs can calls acording logic, can be xpanded do add moves like 1,2,3,4 etc
function module.handleInput(rawInp)
	local inputType = rawInp.UserInputType
	local inputKeycode = rawInp.KeyCode

	if inputType == Enum.UserInputType.MouseButton1 then
		updateComboCount()
	end
	
	if rawInp.KeyCode == Enum.KeyCode.F then
		block()
	end
	
	if rawInp.KeyCode == Enum.KeyCode.Q then
		dash()
	end
end


-- Starts the cooldown before the combo is stopped the resest
function startComboCountdown()
	if isRunning then return end
		isRunning = true
		startTime = tick()
		currentComboConection = RunService.Heartbeat:Connect(function()
			updateComboTime()
		end)
end

-- Checks if combo is over
function updateComboTime()
	if isRunning then
		local TimePassed = tick() - startTime
		if TimePassed > currentComboDuration or currentCombo >= maxCombo then
			print("Combo Over")
			resetCombo()
		end
	end
end

-- Resets the combo and corosponding values
function resetCombo()
	if currentComboConection then
		currentComboConection:Disconnect()
		
		currentComboConection = nil
		currentCombo = 0
		isRunning = false
		canAttack = false
		task.wait(comboCooldown) -- cd before you can start attacking
		canAttack = true
		print("Combo reset")
	end
end

-- Increases combo count and increases combo duration
function hitRegestered()
	AttackEvent:FireServer(currentCombo, maxCombo)

	-- Clear previous connection before creating a new one to prevent memory leaks or multiple connections
	if attackProcessedConnection then
		attackProcessedConnection:Disconnect()
	end

	-- Wait for server response on attack processing
	attackProcessedConnection = AttackProccesedEventReturn.OnClientEvent:Connect(function(sucsess)
		attackSuccessFlag = sucsess
		if sucsess then
			currentCombo += 1
			currentComboDuration += 1
			print("Attack success, combo increased to:", currentCombo)
		end
	end)
end

-- Updates the combo count if attack is successful
function updateComboCount()
	if not isRunning then currentComboDuration = maxComboDuration end
	if not canAttack then return end

	hitRegestered() -- Fire the attack

	-- Delay until server response is received
	task.wait(0.1)  -- Adjust this wait time to allow time for the server to respond

	-- Check if attack was successful
	if attackSuccessFlag then
		startComboCountdown()
	end
end


-- Checks if the player can block
function block()
	BlockEvent:FireServer()
end

function unblock()
	 UnblockEvent:FireServer()
end



function module.handleInputEnd(rawInp)
	local inputKeycode = rawInp.KeyCode

	-- Stop blocking when F key is released
	if inputKeycode == Enum.KeyCode.F then
		unblock()
	end
end

function dash()
	DashEvent:FireServer()
end

return module
