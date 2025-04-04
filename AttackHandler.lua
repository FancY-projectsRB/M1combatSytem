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
local animationInProgress = false -- do not change
local knockbackForce = 1.5
local finalHitKnockbackMULTI = 25

-- Remotes
local AttackEvent : RemoteFunction = eventsFolder.M1Attack --remote function
-- Attack Animation
local punch1Anim = animationsFolder.Punch1
local punch2Anim = animationsFolder.Punch2
local punch3Anim = animationsFolder.Punch3
local punch4Anim = animationsFolder.Punch4

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

-- Initiats Attack logic when fired from client
AttackEvent.OnServerInvoke = function(player :Player, currentCombo, maxCombo)
	-- makes sure you are not over the combo limit
	if currentCombo >= maxCombo then warn("Cant attack yet") return false end
	local character = player.Character
	if not character then return false end
	if animationInProgress then return false end
		-- Grabs info about the other player
		local humanoid : Humanoid = character:WaitForChild("Humanoid")
		local root : Part = character:WaitForChild("HumanoidRootPart")
		local baseWalkspeed = humanoid.WalkSpeed
		--Lowers walksspeed when attacking
		humanoid.WalkSpeed = humanoid.WalkSpeed / 1.5
		soundModule.PlaySound(soundModule.RandSound(swingSounds), root)-- Plays swings sounds for when you attack
		animationInProgress = animHandler.PlayAnim(attackAnimations[currentCombo + 1], humanoid, function() -- plays swing anim
			animationInProgress = false
			humanoid.WalkSpeed = baseWalkspeed
		end)
		
		-- Gets data for where to place hitbox
		local lookVector = root.CFrame.LookVector
		local attackDirection = lookVector * 2  -- Multiplies the look vector to extend the range
		local attackPosition = root.Position + attackDirection  -- Find the target position
		local rotation = root.CFrame.Rotation
		
		-- Create Hitbox
		local part = Instance.new("Part", workspace)
		part.CFrame = CFrame.new(attackPosition) * rotation
		part.Size = Vector3.new(11, 8, 6)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 0.7
		part.Color = Color3.new(1, 0, 0.0156863)
	-- Gets objects inside of the hitbox
	local regionCF = part.CFrame
	local regionSize = part.Size
	local partsInRegion = workspace:GetPartBoundsInBox(regionCF, regionSize)

	local processedParents = {}

	-- Detect parts in the region
	for _, otherPart in ipairs(partsInRegion) do
		local parent = otherPart.Parent
		if parent and not processedParents[parent] then
			local enemyHumanoid = parent:FindFirstChild("Humanoid")
			if enemyHumanoid and parent ~= character then
				-- Logic for hitting an enemy
				enemyHumanoid.Health -= 10
				animHandler.PlayAnim(stunAnimations[math.random(1, #stunAnimations)], enemyHumanoid)
				soundModule.PlaySound(soundModule.RandSound(punchSounds), enemyHumanoid.Parent.HumanoidRootPart)
				VfxModule.PlayHitVFX(enemyHumanoid.Parent)
				print("HIT")
				
				--Slowing the enemy
				local originalSpeed = enemyHumanoid.WalkSpeed
				enemyHumanoid.WalkSpeed = enemyHumanoid.WalkSpeed / 1.5 
				task.delay(0.5, function()
					if enemyHumanoid and enemyHumanoid.Parent then
						enemyHumanoid.WalkSpeed = originalSpeed
					end
				end)
				
				-- Knockback
				local direction = (enemyHumanoid.Parent.HumanoidRootPart.Position - root.Position)
				if currentCombo >= maxCombo -1 then
					knockbackModule.ApplyKnockback(enemyHumanoid.Parent, direction, knockbackForce * finalHitKnockbackMULTI, 0.3)
				else
				knockbackModule.ApplyKnockback(enemyHumanoid.Parent, direction, knockbackForce, 0.3)
				end
			end
			processedParents[parent] = true
		end
	end
	
	-- Resets for next hitbox
	part:Destroy()
	processedParents = {}
	return true -- Tells the client to update combo adn run Combo Logic
end


function attackLogic()
	
end

