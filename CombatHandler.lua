-- This is a server script inside of ServerScriptService

-- Game Services
local RunService : RunService = game:GetService("RunService")
local rs  = game:GetService("ReplicatedStorage")

-- Folder
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
local animationInProgress = {} -- do not change
local knockbackForce = 1.5
local finalHitKnockbackMULTI = 25
local stunTimers = {} -- Tracks active stun timers per player
local stunDuration = 1 -- seconds
local damage = 10
local blockingDeduction = 2 -- this number will be dived with the base dmg
-- Remotes
local AttackEvent : RemoteFunction = eventsFolder.M1Attack 
local BlockEvent : RemoteFunction = eventsFolder.Block
local UnblockEvent : RemoteFunction = eventsFolder.Unblock

-- Attack Animation
local punch1Anim = animationsFolder.Punch1
local punch2Anim = animationsFolder.Punch2
local punch3Anim = animationsFolder.Punch3
local punch4Anim = animationsFolder.Punch4

local blockAnim = animationsFolder.Block

-- Stun Animation
local stun1Anim = animationsFolder.Stun1
local stun2Anim = animationsFolder.Stun2

-- list of animation
local attackAnimations = {punch1Anim,punch2Anim,punch3Anim,punch4Anim}
local stunAnimations = {stun1Anim, stun2Anim}

-- Punch SFX
local PunchSFX1 = SoundsFolder.PunchSFX1
local PunchSFX2 = SoundsFolder.PunchSFX2
local PunchSFX3 = SoundsFolder.PunchSFX3

-- Swing SFX
local SwingSFX1 = SoundsFolder.Swing1
local SwingSFX2 = SoundsFolder.Swing2
local SwingSFX3 = SoundsFolder.Swing3

-- list of all sounds
local punchSounds = {PunchSFX1,PunchSFX2,PunchSFX3}
local swingSounds = {SwingSFX1, SwingSFX2, SwingSFX3}


-- Adds attributes to the player
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		task.wait(0.1)
		character:SetAttribute("Stunned", false)
		character:SetAttribute("Blocking", false)
	end)
end)

-- Stuns player not allowing them to attack back 
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

-- Checks if the provided player is stunned
function amiStunned(character: Model)
	local isStunned = character:GetAttribute("Stunned")
	if isStunned == nil then
		warn(character.Name .. " has no Stunned attribute! Defaulting to stunned.")
		return true
	end
	return isStunned
end

function amiBlocking(character : Model)
	local isBlocking = character:GetAttribute("Blocking")
	if isBlocking == nil then
		warn("No blocking attribute found, defaulting to false")
		return false
	end
	return isBlocking
end

-- removes player from lists
game.Players.PlayerRemoving:Connect(function(player)
	if stunTimers[player.Character] then
		task.cancel(stunTimers[player.Character])
		stunTimers[player.Character] = nil
	end
	animationInProgress[player] = nil
end)

--  gets top-level model with Humanoid from a part
local function getCharacterFromPart(part)
	local ancestor = part
	while ancestor and ancestor ~= workspace do
		if ancestor:FindFirstChild("Humanoid") then
			return ancestor
		end
		ancestor = ancestor.Parent
	end
	return nil
end

-- Initiates Attack logic when fired from client
AttackEvent.OnServerInvoke = function(player :Player, currentCombo, maxCombo)
	-- Checks if player is over combo limit
	if currentCombo >= maxCombo then warn("Cant attack yet") return false end
	
	-- Finds character and makes sure it is in the game
	local character = player.Character
	if not character then return false end
	if animationInProgress[player] then return false end
	-- Checks if player is stunned, if they are they will not be able to attack
	if amiStunned(player.Character) then
		warn("[AttackEvent] Player is stunned, attack cancelled")
		return false
	end
	if amiBlocking(player.Character) then
		print("Cant attack while blocking")
		return false
	end
	
	animationInProgress[player] = true
	
	-- Character info
	local humanoid : Humanoid = character:WaitForChild("Humanoid")
	local root : Part = character:WaitForChild("HumanoidRootPart")
	local baseWalkspeed = humanoid.WalkSpeed

	-- Slows player in attack
	humanoid.WalkSpeed = humanoid.WalkSpeed / 1.5
	soundModule.PlaySound(soundModule.RandSound(swingSounds), root)

	-- Plays swing Animation
	animHandler.PlayAnim(attackAnimations[currentCombo + 1], humanoid, function()
		animationInProgress[player] = false
		humanoid.WalkSpeed = baseWalkspeed
	end)

	-- Gets values for the hitbox
	local lookVector = root.CFrame.LookVector
	local attackDirection = lookVector * 2
	local attackPosition = root.Position + attackDirection
	local rotation = root.CFrame.Rotation

	-- Creates the hit box
	local part = Instance.new("Part", workspace)
	part.CFrame = CFrame.new(attackPosition) * rotation
	part.Size = Vector3.new(11, 8, 6)
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 0.7
	part.Color = Color3.new(1, 0, 0.0156863)

	local regionCF = part.CFrame
	local regionSize = part.Size
	local partsInRegion = workspace:GetPartBoundsInBox(regionCF, regionSize)

	local processedParents = {}
	-- Gets objects found inside of hit box and runs corosponding attack logic
	for _, otherPart in ipairs(partsInRegion) do
		local targetCharacter = getCharacterFromPart(otherPart)

		if targetCharacter and targetCharacter ~= character and not processedParents[targetCharacter] then
			local enemyHumanoid = targetCharacter:FindFirstChild("Humanoid")

			if enemyHumanoid then
				processedParents[targetCharacter] = true

				print("[Hitbox] HIT! Target:", targetCharacter.Name)
				if not amiBlocking(enemyHumanoid.Parent) then
					enemyHumanoid.Health -= damage
				else 
					print("Hit blocked! decreasing damage dealt")
					enemyHumanoid.Health -= damage / blockingDeduction
				end
					
				-- Plays feedback via animations,sounds, and cfx
				animHandler.PlayAnim(stunAnimations[math.random(1, #stunAnimations)], enemyHumanoid)
				soundModule.PlaySound(soundModule.RandSound(punchSounds), enemyHumanoid.Parent.HumanoidRootPart)
				VfxModule.PlayHitVFX(enemyHumanoid.Parent)

				-- Stuns enemy player
				stunPlayer(enemyHumanoid.Parent)

				-- Slows enemy
				local originalSpeed = enemyHumanoid.WalkSpeed
				enemyHumanoid.WalkSpeed = originalSpeed / 2
				task.delay(stunDuration, function()
					if enemyHumanoid and enemyHumanoid.Parent then
						enemyHumanoid.WalkSpeed = originalSpeed
					end
				end)
			
				-- Knockback logic
				local direction = (enemyHumanoid.Parent.HumanoidRootPart.Position - root.Position)
				if currentCombo >= maxCombo - 1 then
					knockbackModule.ApplyKnockback(enemyHumanoid.Parent, direction, knockbackForce * finalHitKnockbackMULTI, 0.3)
				else
					knockbackModule.ApplyKnockback(enemyHumanoid.Parent, direction, knockbackForce, 0.3)
				end
			else
				warn("[Hitbox] Found model, but no humanoid in", targetCharacter.Name)
			end
		end
	end
	-- deletes hitbox and checked parents 
	part:Destroy()
	processedParents = {}

	return true -- tells the client to update their combo and run logic
end

-- determins if the player can block and runs corosponding logic
BlockEvent.OnServerInvoke = function(player : Player)
	-- Determains if the character is loaded and if it contains the blocking attribute
	local character = player.Character
	if not character then warn("Character not found will not block") return false end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then warn("humanoid not found, will not block") return false end
	
	local blockAttribute = character:GetAttribute("Blocking")
	
	if blockAttribute == nil then warn("Attribute not found, blocking will not take place") return false end
	if character:GetAttribute("Stunned") == true then print("Cant block while stunned") return false end
	
	--Blocking logic
	character:SetAttribute("Blocking", true)

	print("player is blocking")
end

-- handles when the player wants to unblock
UnblockEvent.OnServerInvoke = function(player : Player)
	-- Determains if the character is loaded and if it contains the blocking attribute
	local character = player.Character
	if not character then warn("Character not found will not block") return false end
	local blockAttribute = character:GetAttribute("Blocking")
	if blockAttribute == nil then warn("Attribute not found, blocking will not take place") return false end
	
	character:SetAttribute("Blocking", false)
	print("player is not blocking")
end
