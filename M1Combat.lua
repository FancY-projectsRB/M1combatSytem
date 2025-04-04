-- This server runs on thw CLINET

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

-- Events
local AttackEvent : RemoteFunction = eventsFolder:WaitForChild("M1Attack")

local module = {}

-- O, I, Shift or any keybinds used by roblox can not be used as keybinds with this script

-- Watches for player inputs can calls acording logic, can be xpanded do add moves like 1,2,3,4 etc
function module.handleInput(rawInp)
	local inputType = rawInp.UserInputType
	local inputKeycode = rawInp.KeyCode

	if inputType == Enum.UserInputType.MouseButton1 then
		updateComboCount()
	end
end

-- Increases combo count
function updateComboCount()
	if not isRunning then currentComboDuration = maxComboDuration end
	if canAttack == false then return end
	hitRegestered()
	startComboCountdown()
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
	if CheckAttack() then
	currentCombo += 1
	currentComboDuration += 1
	print(currentCombo)
	--print("increased combo duration by ".. 1 .. "it is now " .. currentComboDuration)
	end
end

-- Fires to Sevrer to see if you can attack or not and fi you can preoceed with logic
function CheckAttack()
	canAttack = false
	local attackWorked = AttackEvent:InvokeServer(currentCombo, maxCombo) --bool/  fires server code to place hitbox and deal dmg to prevent exploits
	canAttack = true
	return attackWorked
end

return module
