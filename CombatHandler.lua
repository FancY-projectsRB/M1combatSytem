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

-- Safley requires modules
local function safeRequire(module)
	if not module then return nil end
	local success, result = pcall(require, module)
	if success then
		return result
	else
		warn("Failed to require module:", module:GetFullName(), result)
		return nil
	end
end

local animHandler = safeRequire(modules:WaitForChild("AnimationHandler"))
local soundModule = safeRequire(modules:WaitForChild("SoundHandler"))
local VfxModule = safeRequire(modules:WaitForChild("VfxHandler"))
local knockbackModule = safeRequire(modules:WaitForChild("SimpleKnockback"))

-- Logic Variables
local animationInProgress = {} -- Do not change
local knockbackForce = 1.5
local finalHitKnockbackMULTI = 25
local stunTimers = {} -- Tracks active stun timers per player
local stunDuration = 1 -- Seconds
local damage = 10
local baseWalkspeed = 16
local blockingDeduction = 2 -- This number will be divided into the base damage
local dashForce = 19000
local dashDB = 2 -- seconds before you can dash after a dash
local dashLength = 0.2 -- this is how long the force will be applied for
local dashDuration = 0.37 -- determains how long the anim is played for
local HitboxSize = Vector3.new(11, 8, 6)


local maxCombos = {}
local currentCombos = {}
local playerCanDash = {}

-- Remotes
local AttackEvent : RemoteEvent = eventsFolder.M1Attack 
local AttackProccesedEventReturn : RemoteEvent = eventsFolder.AttackProccesedEventReturn
local BlockEvent : RemoteEvent = eventsFolder.Block
local UnblockEvent : RemoteEvent = eventsFolder.Unblock
local DashEvent : RemoteEvent = eventsFolder.Dash

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

 --  Player Setup

-- uses :FireClient() to tell client if attack was processed to increase combo cunt and run other logic
local function sendAttackProcessed(player, status)
	AttackProccesedEventReturn:FireClient(player, status)
end

-- Sets attributes for the player such as Stunned, and Blocking
-- This allows players to have certain actions placed upon them
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:SetAttribute("Stunned", false)
		character:SetAttribute("Blocking", false)
	end)
end)

-- Removes player from lists to reduce server memory usage by removing values
game.Players.PlayerRemoving:Connect(function(player)
	animationInProgress[player] = nil
	maxCombos[player] = nil
	currentCombos[player] = nil
	playerCanDash[player] = nil
end)

--> Stun Logic <--

--[[ 
	stunPlayer(character: Model)
	Temporarily stuns a player character by setting the "Stunned" attribute to true and 
	disabling their actions for a fixed duration (default 1 second). 
	Uses task.cancel() to ensure stun timers don't stack.
	@param character - Model representing the player's character
--]]
function stunPlayer(character: Model)
	-- checks if character exists
	if not character then
		warn("Can't stun, no character")
		return
	end
	-- Adds stunned attribute
	character:SetAttribute("Stunned", true)

	-- resets stun duration to not stack stunds resulting in a long unneeded stun
	if stunTimers[character] then
		task.cancel(stunTimers[character])
	end
	-- Starts a new stun duration to keep the combo going
	stunTimers[character] = task.delay(stunDuration, function()
		if character and character.Parent then
			character:SetAttribute("Stunned", false)
		end
		-- removes stun timer from list 
		stunTimers[character] = nil
	end)
end

 -- Determines if a character is stunned by checking its "Stunned" attribute

function amiStunned(character: Model)
	--gets stunned attribue and checks if the model contains it
	local isStunned = character:GetAttribute("Stunned")
	if isStunned == nil then
		warn(character.Name .. " has no Stunned attribute! Defaulting to stunned.")
		return true
	end
	-- returns the value of the Stunned attribute
	return isStunned
end

--> Blocking Logic <--

-- Determines if a character is blocking by checking its "Blocking" attribute
function amiBlocking(character : Model)
	-- Checks blocking attribute
	local isBlocking = character:GetAttribute("Blocking")
	if isBlocking == nil then
		warn("No blocking attribute found, defaulting to false")
		return false
	end
	-- returns the value of the Blocking attribute
	return isBlocking
end


--  Called when player attempts to block. Verifies conditions and sets Blocking attribute
BlockEvent.OnServerEvent:Connect( function(player : Player)
	-- finds character and humanoid
	local character = player.Character
	local humanoid = character:FindFirstChild("Humanoid")
	-- Checks if the humanoid and character exist
	if not character or not humanoid then
		warn("Values not found, will not block")
		return
	end
	-- Checks if the blocking Attribute exists
	local blockAttribute = character:GetAttribute("Blocking")
	if blockAttribute == nil then
		warn("Attribute not found, blocking will not take place")
		return
	end
	-- Checks if the player is stunned and returns if so
	if character:GetAttribute("Stunned") == true then print("Can't block while stunned") return end
	-- Enables blocking attribute
	character:SetAttribute("Blocking", true)
	
	-- possible logic for blocking such as anims, sfx, and more
end)


 -- Called when player stops blocking. Sets Blocking attribute to false
UnblockEvent.OnServerEvent:Connect(function(player : Player)
	-- Checks if character and attribute exists
	local character = player.Character
	local blockAttribute = character:GetAttribute("Blocking")
	if not character or not blockAttribute then
		warn("Character not found, will not unblock")
		return
	end

	character:SetAttribute("Blocking", false)
end)

--> Attack Logic <--

--  Starts the attack sequence by calling the triggerAttack function
AttackEvent.OnServerEvent:Connect(function(player, currentCombo, maxCombo)
	return triggerAttack(player, currentCombo, maxCombo)
end)

-- Main Attack Function
--[[ 
	triggerAttack(player: Player, currentCombo: number, maxCombo: number)
	Handles attack validation and execution:
	- Validates combo limits, animation states, stun/block conditions
	- Spawns hitbox, plays swing animation and sound
	- Runs hit detection and damage application
	- Returns success state to client for further processing (like UI combo feedback)
--]]
function triggerAttack(player :Player, currentCombo, maxCombo)
	-- Returns if player is over combo limit
	if currentCombo >= maxCombo then
		warn("Can't attack yet")
		sendAttackProcessed(player, false)
		return
	end

	-- Checks if the character exists for the player
	local character = player.Character
	local humanoid : Humanoid = character.Humanoid
	local root : Part = character.HumanoidRootPart
	if not character  or not humanoid or not root then
		sendAttackProcessed(player, false)
		return
	end
	-- Checks if the player is already in an animation so they dont animation cancel or skip animations
	if animationInProgress[player] then
		sendAttackProcessed(player, false)
		return
	end
	-- Checks if the player is blocking or is stunned as they should not beable to attack during these states
	if amiStunned(character) or amiBlocking(character) then
		sendAttackProcessed(player, false)
		return 
	end
	-- Updates combo values for this player
	maxCombos[player] = maxCombo
	currentCombos[player] = currentCombo

	-- Plays swing animation for the player
	playSwingFeedback(player, humanoid)
	-- Creates hitbox that will be used for the player
	local hitbox = createHitbox(root)
	-- Checks if hitbox exists
	if hitbox == nil then sendAttackProcessed(player, false) return end
	-- Runs hitbox logic to damage other humanoids in range
	hitBoxLogic(hitbox, player, character)
	-- Destroys hitbox and returns TRUE to client for a sucsessful attack
	hitbox:Destroy()
	sendAttackProcessed(player, true)
end

--> Animation and Sound Logic <--

 -- Plays visual feedback on the enemy character
function EnemyswingFeedback(enemyHumanoid)
	if not enemyHumanoid then
		warn("Feedback not applied, humanoid not found")
		return
	end
	-- Plays swing anim
	animHandler.PlayAnim(stunAnimations[math.random(1, #stunAnimations)], enemyHumanoid)
	-- Plays hit sound
	soundModule.PlaySound(soundModule.RandSound(punchSounds), enemyHumanoid.Parent.HumanoidRootPart)
	-- Plays VFX on enemy
	VfxModule.PlayHitVFX(enemyHumanoid.Parent)
end

--  Plays swing animation and sound for the attacking player
function playSwingFeedback(player, humanoid)
	-- Sets the value for when a Player is in an anim is true for the given player
	animationInProgress[player] = true
	-- Gets random song using a table of SFXs
	local randSwingSound = soundModule.RandSound(swingSounds)
	-- Plays swing SFX
	soundModule.PlaySound(randSwingSound, humanoid.Parent)
	-- Plays swing anim for the given player based off where they are in their combo
	animHandler.PlayAnim(attackAnimations[currentCombos[player] + 1], humanoid, function()
		-- Player is not in an animation anymore
		animationInProgress[player] = false
		-- Returns walkspeed to normal
		humanoid.WalkSpeed = baseWalkspeed
	end)
end

--> Knockback Logic <--

--  Applies knockback to the enemy based on combo
function applyKnockBack(enemyHumanoid, root, player)
	-- Finds direction of knockback
	local direction = (enemyHumanoid.Parent.HumanoidRootPart.Position - root.Position)
	-- Determains if it is the final hit of the combo
	if currentCombos[player] >= maxCombos[player] - 1 then
		-- Applies Knockback using knockback module
		knockbackModule.ApplyKnockback(enemyHumanoid.Parent, direction, knockbackForce * finalHitKnockbackMULTI, 0.3)
	else
		-- Applies Knockback using knockback module
		knockbackModule.ApplyKnockback(enemyHumanoid.Parent, direction, knockbackForce, 0.3)
	end
end

--> Hitbox Logic <--

-- Finds all objects in a given part and damages their humanoid
function hitBoxLogic(hitboxPart, player, character)
	-- Grab dimenstions for Region3
	local regionSize = hitboxPart.Size
	local region = Region3.new(hitboxPart.Position - regionSize / 2, hitboxPart.Position + regionSize / 2)
	-- Grabs all objects in given range
	local partsInRegion = workspace:FindPartsInRegion3(region, nil, math.huge)  -- Finds parts in region
	-- List of parents processed by hitbox, Prevents multiple hits on one humanoid
	local processedParents = {}

	-- Loops thorugh all parts found
	for _, otherPart in ipairs(partsInRegion) do
		-- Finds character from other part
		local targetCharacter = getCharacterFromPart(otherPart)

		-- Determains if the charcter exists and that this part has not already been processed by using its parent
		if targetCharacter and targetCharacter ~= character and not processedParents[targetCharacter] then
			-- Grabs enemy humanoid
			local enemyHumanoid = targetCharacter:FindFirstChild("Humanoid")
			
			if enemyHumanoid then
				-- Adds parent to processed Parrents list
				processedParents[targetCharacter] = true
				
				-- Detramins damage output based on if the enemy is blocking or not
				local isBlocking = amiBlocking(enemyHumanoid.Parent)
				if not isBlocking then
					-- Deals damage to enemy
					enemyHumanoid:TakeDamage(damage)
				else
					-- Deals reduced damage to enemy
					enemyHumanoid:TakeDamage(damage / blockingDeduction)
				end
				-- Applies knockback in a diffrent thread 
				task.spawn(function()
					applyKnockBack(enemyHumanoid, character.HumanoidRootPart, player)
				end)
				-- Plays feedback on the enemy such as VFX, SFX, and ANIMS
				EnemyswingFeedback(enemyHumanoid)
				-- Stuns the enemy to prevent them from attacking mid combo
				stunPlayer(targetCharacter)
			end
		end
	end
	processedParents = {}
end

--[[ 
	getCharacterFromPart(part: BasePart)
	Traverses upward to get the Model of the character based on part's parent.
	Returns Model if it has a Humanoid; otherwise, returns nil.
	Used to determine if a detected part belongs to a valid player character.
--]]

function getCharacterFromPart(part)
	-- Checks if the part has a parent
	if part and part.Parent then
		local character = part.Parent
		-- Determains if the charcter contains a Humanoid signifying that it is a character
		if character:FindFirstChild("Humanoid") then
			return character
		end
	end
	return nil
end

--> Hitboxs <-- 

--[[ 
	createHitbox(root: Part)
	Generates a transparent red hitbox (Part) positioned in front of the player.
	This temporary object is used to define an area of effect for melee attacks.
	Returns: the hitbox Part object for collision/detection processing.
--]]

function createHitbox(root)
	if not root then
		warn("Given root does not exist, Cant create hitbox")
		return
	end
	
	-- Gets location values for the hitbox
	local lookVector = root.CFrame.LookVector
	local attackDirection = lookVector * 2 -- Distance in front of the character
	local attackPosition = root.Position + attackDirection

	-- Create the part (hitbox) and set its position and rotation based on the character's look vector
	local part = Instance.new("Part")
	part.Parent = workspace.ActiveHitboxes

	-- Set the CFrame to position the hitbox in front of the character and rotate it accordingly
	part.CFrame = CFrame.new(attackPosition, attackPosition + lookVector) -- Attack position + direction
	-- Set values for the new part
	part.Size = HitboxSize
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.7
	part.Color = Color3.new(1, 0, 0.0156863)

	return part
end 

-- Dash System

-- Adds force to player to create a dash
DashEvent.OnServerEvent:Connect(function(player: Player)
	-- Prevent dash spamming
	if playerCanDash[player] == false then
		return
	end
	playerCanDash[player] = false

	-- Call dash cooldown indicator (e.g., UI dimming, cooldown bar)
	startDashDB(player)

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		warn("Missing humanoid or root part during dash")
		playerCanDash[player] = true
		return
	end

	-- Prevent dashing while stunned
	local isStunned = character:GetAttribute("Stunned")
	if isStunned then
		return
	end

	-- Play dash animation
	animHandler.PlayAnim(slideAnim, humanoid)
	
	-- Make sure the HumanoidRootPart has an Attachment
	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "RootAttachment"
		attachment.Parent = root
	end
	
	-- Create and configure the VectorForce
	local vectorForce = Instance.new("VectorForce")
	vectorForce.Name = "DashVelocity"
	vectorForce.Force = root.CFrame.LookVector * dashForce
	vectorForce.Attachment0 = attachment
	vectorForce.ApplyAtCenterOfMass = true -- generally true for better physics behavior
	vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World -- or .Attachment0 if you want local force
	vectorForce.Parent = root

	-- Remove the force after dash ends
	task.delay(dashLength, function()
		if vectorForce and vectorForce.Parent then
			vectorForce:Destroy()
			task.wait(0.3)
			animHandler.StopAnim(slideAnim, humanoid)
		end
	end)

	-- Cooldown reset
	task.delay(dashDB, function()
		playerCanDash[player] = true
	end)
end)

-- Starts the cooldown and wont be resumed until given time after next cycle using task.delay
function startDashDB(player)
	-- Disables ability to dash
	playerCanDash[player] = false
	-- Starts delay until ability to dash again
	task.delay(dashDB, function()
		playerCanDash[player] = true
	end)
end
