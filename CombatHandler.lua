-- This is a server script inside of ServerScriptService

--> Variables <-- 
-- Game Services
local rs  = game:GetService("ReplicatedStorage")

-- Folders
local modules = rs.Modules
local eventsFolder = rs.Remotes
local animationsFolder = rs.Animations
local SoundsFolder = rs.Sounds

-- Modules
local animHandler = require(modules.AnimationHandler)
local soundModule = require(rs.Modules.SoundHandler)
local VfxModule = require(rs.Modules.VfxHandler)
local knockbackModule = require(rs.Modules.SimpleKnockback)

-- Logic Variables
local animationInProgress = {} -- Do not change
local knockbackForce = 1.5
local finalHitKnockbackMULTI = 25
local stunTimers = {} -- Tracks active stun timers per player
local stunDuration = 1 -- Seconds
local damage = 10
local baseWalkspeed = 16
local blockingDeduction = 2 -- This number will be divided into the base damage
local dashForce = 20000
local dashDB = 2 -- seconds before you can dash after a dash
local dashLength = 0.2 -- this is how long the force will be applied for
local dashDuration = 0.37 -- determains how long the anim is played for

local maxCombos = {}
local currentCombos = {}
local playerCanDash = {}

-- Remotes
local AttackEvent : RemoteFunction = eventsFolder.M1Attack 
local BlockEvent : RemoteFunction = eventsFolder.Block
local UnblockEvent : RemoteFunction = eventsFolder.Unblock
local DashEvent : RemoteFunction = eventsFolder.Dash

-- Attack Animations
local punch1Anim = animationsFolder.Punch1
local punch2Anim = animationsFolder.Punch2
local punch3Anim = animationsFolder.Punch3
local punch4Anim = animationsFolder.Punch4

-- Stun Animations
local stun1Anim = animationsFolder.Stun1
local stun2Anim = animationsFolder.Stun2

-- List of attack animations
local attackAnimations = {punch1Anim, punch2Anim, punch3Anim, punch4Anim}
local stunAnimations = {stun1Anim, stun2Anim}

-- Punch SFX
local PunchSFX1 = SoundsFolder.PunchSFX1
local PunchSFX2 = SoundsFolder.PunchSFX2
local PunchSFX3 = SoundsFolder.PunchSFX3

-- Swing SFX
local SwingSFX1 = SoundsFolder.Swing1
local SwingSFX2 = SoundsFolder.Swing2
local SwingSFX3 = SoundsFolder.Swing3

-- Slide Anim
local slideAnim = animationsFolder.Slide

-- List of all sounds
local punchSounds = {PunchSFX1, PunchSFX2, PunchSFX3}
local swingSounds = {SwingSFX1, SwingSFX2, SwingSFX3}
--> Variables END <--


--[[ 
  Player Setup
  Adds the "Stunned" and "Blocking" attributes when the player spawns
]]
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		character:SetAttribute("Stunned", false)
		character:SetAttribute("Blocking", false)
	end)
end)


--> Stun Logic <--

--[[ 
  Enables the "Stunned" attribute and starts a timer using task.delay for the stun duration
]]
function stunPlayer(character: Model)
	if not character then warn("Can't stun, no character") return end

	character:SetAttribute("Stunned", true)
	print("[StunPlayer] Stunning", character.Name)

	if stunTimers[character] then
		task.cancel(stunTimers[character])
	end

	stunTimers[character] = task.delay(stunDuration, function()
		if character and character.Parent then
			character:SetAttribute("Stunned", false)
			print("[StunPlayer] Unstunned", character.Name)
		end
		stunTimers[character] = nil
	end)
end

--[[ 
  Determines if a character is stunned by checking its "Stunned" attribute
]]
function amiStunned(character: Model)
	local isStunned = character:GetAttribute("Stunned")
	if isStunned == nil then
		warn(character.Name .. " has no Stunned attribute! Defaulting to stunned.")
		return true
	end
	return isStunned
end


--> Blocking Logic <--

--[[ 
  Determines if a character is blocking by checking its "Blocking" attribute
]]
function amiBlocking(character : Model)
	local isBlocking = character:GetAttribute("Blocking")
	if isBlocking == nil then
		warn("No blocking attribute found, defaulting to false")
		return false
	end
	return isBlocking
end

--[[ 
  Called when player attempts to block. Verifies conditions and sets Blocking attribute
]]
BlockEvent.OnServerInvoke = function(player : Player)
	local character = player.Character
	if not character then warn("Character not found, will not block") return false end
	local humanoid = character:FindFirstChild("Humanoid")

	local blockAttribute = character:GetAttribute("Blocking")
	if blockAttribute == nil then warn("Attribute not found, blocking will not take place") return false end
	if character:GetAttribute("Stunned") == true then print("Can't block while stunned") return false end

	character:SetAttribute("Blocking", true)
	print("Player is blocking")
end

--[[ 
  Called when player stops blocking. Sets Blocking attribute to false
]]
UnblockEvent.OnServerInvoke = function(player : Player)
	local character = player.Character
	if not character then warn("Character not found, will not unblock") return false end
	local blockAttribute = character:GetAttribute("Blocking")
	if blockAttribute == nil then warn("Attribute not found, unblocking will not take place") return false end

	character:SetAttribute("Blocking", false)
	print("Player is not blocking")
end


--> Attack Logic <--

--[[ 
  Starts the attack sequence by calling the triggerAttack function
]]
AttackEvent.OnServerInvoke = function(player, currentCombo, maxCombo)
	return triggerAttack(player, currentCombo, maxCombo)
end

--[[ 
  Checks if all values are valid
  Plays swing animation
  Creates a hitbox and damages all humanoids inside it in hitBoxLogic()
  Destroys the hitbox for performance
  Returns success to the client
]]
function triggerAttack(player :Player, currentCombo, maxCombo)
	if currentCombo >= maxCombo then warn("Can't attack yet") return false end

	local character = player.Character
	if not character then return false end
	if animationInProgress[player] then return false end
	if amiStunned(character) then
		print("[AttackEvent] Player is stunned, attack cancelled")
		return false
	end
	if amiBlocking(character) then
		print("Can't attack while blocking")
		return false
	end

	maxCombos[player] = maxCombo
	currentCombos[player] = currentCombo

	local humanoid : Humanoid = character:WaitForChild("Humanoid")
	local root : Part = character:WaitForChild("HumanoidRootPart")

	playSwingAnim(player, humanoid)
	local hitbox = createHitbox(root)
	if hitbox == nil then return false end

	hitBoxLogic(hitbox, player, character)

	hitbox:Destroy()
	return true -- Tells the client to update their combo and run logic
end


--> Animation and Sound Logic <--

--[[ 
  Plays visual feedback on the enemy character
]]
function EnemyswingFeedback(enemyHumanoid, humanoid)
	print("Played visual feedback from the enemy player")
	animHandler.PlayAnim(stunAnimations[math.random(1, #stunAnimations)], enemyHumanoid)
	soundModule.PlaySound(soundModule.RandSound(punchSounds), enemyHumanoid.Parent.HumanoidRootPart)
	VfxModule.PlayHitVFX(enemyHumanoid.Parent)
end

--[[ 
  Plays swing animation and sound for the attacking player
]]
function playSwingAnim(player, humanoid)
	animationInProgress[player] = true
	local randSwingSound = soundModule.RandSound(swingSounds)
	soundModule.PlaySound(randSwingSound, humanoid.Parent)
	animHandler.PlayAnim(attackAnimations[currentCombos[player] + 1], humanoid, function()
		animationInProgress[player] = false
		humanoid.WalkSpeed = baseWalkspeed
	end)
end


--> Knockback Logic <--

--[[ 
  Applies knockback to the enemy based on combo
  player is the player who is sending the knockback to the other player, this is used to find what values to set the combo to
]]
function applyKnockBack(enemyHumanoid, root, player)
	local direction = (enemyHumanoid.Parent.HumanoidRootPart.Position - root.Position)
	if currentCombos[player] >= maxCombos[player] - 1 then
		knockbackModule.ApplyKnockback(enemyHumanoid.Parent, direction, knockbackForce * finalHitKnockbackMULTI, 0.3)
	else
		knockbackModule.ApplyKnockback(enemyHumanoid.Parent, direction, knockbackForce, 0.3)
	end
end


--> Hitbox Logic <--

--[[ 
  Gets dimensions of the hitbox
  Finds all parts inside the box
  Runs logic for each valid target
  Prevents hitting the same player more than once
]]
function hitBoxLogic(hitboxPart, player, character)
	local regionCF = hitboxPart.CFrame
	local regionSize = hitboxPart.Size
	local partsInRegion = workspace:GetPartBoundsInBox(regionCF, regionSize)

	local processedParents = {}

	for _, otherPart in ipairs(partsInRegion) do
		local targetCharacter = getCharacterFromPart(otherPart)

		if targetCharacter and targetCharacter ~= character and not processedParents[targetCharacter] then
			local enemyHumanoid = targetCharacter:FindFirstChild("Humanoid")
			if enemyHumanoid then
				processedParents[targetCharacter] = true

				print("[Hitbox] HIT! Target:", targetCharacter.Name)
				if not amiBlocking(enemyHumanoid.Parent) then
					enemyHumanoid:TakeDamage(damage)
				else
					enemyHumanoid:TakeDamage(damage / blockingDeduction)
				end

				applyKnockBack(enemyHumanoid, character.HumanoidRootPart, player)
				EnemyswingFeedback(enemyHumanoid, character)
				stunPlayer(targetCharacter)
			end
		end
	end
end

--[[ 
  Returns the character associated with a given part (for hit detection purposes)
]]
function getCharacterFromPart(part)
	if part and part.Parent then
		local character = part.Parent
		if character:FindFirstChild("Humanoid") then
			return character
		end
	end
	return nil
end


--> Create Hitbox Function <-- 

--[[ 
  Creates a hitbox that will detect all parts within its dimensions
]]
function createHitbox(root)
	local lookVector = root.CFrame.LookVector
	local attackDirection = lookVector * 2 -- Distance in front of the character
	local attackPosition = root.Position + attackDirection

	-- Create the part (hitbox) and set its position and rotation based on the character's look vector
	local part = Instance.new("Part", workspace)

	-- Set the CFrame to position the hitbox in front of the character and rotate it accordingly
	part.CFrame = CFrame.new(attackPosition, attackPosition + lookVector) -- Attack position + direction

	part.Size = Vector3.new(11, 8, 6)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.7
	part.Color = Color3.new(1, 0, 0.0156863)

	return part
end

-- Dash System 

--[[
	Adds the force to the player
	Disables the ability to dash as you are mid dash using playerCanDash[player]
	Calls db and allows player to dash again
	You may use the return for client function but it must return TRUE (slide worked) or FALSE (slide did not work or started)
]]

DashEvent.OnServerInvoke = function(player: Player)
	-- Sanity checks
	if playerCanDash[player] == false then print("player is already dashing") return false end
	
	local character = player.Character
	if not character then warn("Character not found") return false end

	local humanoid = character:FindFirstChild("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then warn("Missing parts") return false end

	if character:GetAttribute("Stunned") == true then return false end

	-- Creates an attachment to apply the force to
	local attachment = root:FindFirstChild("DashAttachment") or Instance.new("Attachment")
	attachment.Name = "DashAttachment"
	attachment.Parent = root

	-- Plays feedback before force to make the feedback play smoother
	playDashFeedback(humanoid, player)

	-- Create the VectorForce to apply slide force
	local dashForce = Instance.new("VectorForce")
	dashForce.Attachment0 = attachment
	dashForce.RelativeTo = Enum.ActuatorRelativeTo.World 
	dashForce.Force = root.CFrame.LookVector * 20000 -- Change this value to control dash speed
	dashForce.Parent = root
	humanoid.UseJumpPower = true
	
	-- Logic DURING dash
	humanoid.JumpPower = 0 -- disables jumping by setting jump power to 0
	playerCanDash[player] = false

	-- Removes the force after a short duration and starts the DB and disables anim
	task.delay(dashLength, function()
		print("player is done dashing")
		humanoid.JumpPower = 50 
		dashForce:Destroy()
		attachment:Destroy()
		startDashDB(player)
		task.wait(dashDuration)
		animHandler.StopAnim(slideAnim, humanoid)
	end)

	return true
end

-- Starts the cooldown and wont be resumed until given time after next cycle using task.delay
function startDashDB(player)
	playerCanDash[player] = false
	task.delay(dashDB, function()
		print("dash debounce over for " .. player.Name)
		playerCanDash[player] = true
	end)
end

-- Plays dash animation and calls a callback function when it ends to allow another animation to be played on a character
function playDashFeedback(humanoid, player)
	animationInProgress[player] = true
	animHandler.PlayAnim(slideAnim, humanoid, function()
		print("slide animation done")
		animationInProgress[player] = false
	end)
end
