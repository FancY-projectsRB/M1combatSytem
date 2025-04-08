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

-- Events
local AttackEvent : RemoteFunction = eventsFolder:WaitForChild("M1Attack")
local BlockEvent : RemoteFunction = eventsFolder.Block
local UnblockEvent : RemoteFunction = eventsFolder.Unblock
local DashEvent :RemoteFunction = eventsFolder.Dash

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

-- Increases combo count
function updateComboCount()
	if not isRunning then currentComboDuration = maxComboDuration end
	if not canAttack then return end

	local attackSuccess = hitRegestered()
	if attackSuccess then
		startComboCountdown()
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
	if CheckAttack() == true then
		currentCombo += 1
		currentComboDuration += 1
		print(currentCombo)
		return true
	end
	return false
end

-- Fires to Sevrer to see if you can attack or not and if you can preoceed with logic
function CheckAttack()
	if localPlayer:GetAttribute("Stunned") then
		print("You're stunned, can't attack")
		return false
	end
	
	canAttack = false
	local attackWorked = AttackEvent:InvokeServer(currentCombo, maxCombo) --bool/  fires server code to place hitbox and deal dmg to prevent exploits
	canAttack = true
	return attackWorked
end

-- Checks if the player can block
function block()
	local canBlock = canBlock()

end

function unblock()
	local unblocked = UnblockEvent:InvokeServer()
end

function canBlock()
	local canBlock = BlockEvent:InvokeServer()
	return canBlock
end

function module.handleInputEnd(rawInp)
	local inputKeycode = rawInp.KeyCode

	-- Stop blocking when F key is released
	if inputKeycode == Enum.KeyCode.F then
		unblock()
	end
end

function dash()
	local canDash = DashEvent:InvokeServer()
	print(canDash)
	if not canDash then return end
end

return module
