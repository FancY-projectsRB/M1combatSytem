local module = {}
local activeAnimations = {} -- Table to store multiple animations

function module.PlayAnim(Animation : Animation, Humanoid : Humanoid, onAnimationEnd)
	if not Animation then
		warn("Animation Not found, Will not play animation")
		return false
	end
	if not Humanoid then
		warn("Humanoid Not found, Will not play animation")
		return false
	end

	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn("No Animator found in Humanoid")
		return false
	end

	local animationTrack = animator:LoadAnimation(Animation)
	table.insert(activeAnimations, animationTrack) -- Store the animation track
	animationTrack:Play()

	-- Handle when the animation stops
	animationTrack.Stopped:Connect(function()
		for i, track in ipairs(activeAnimations) do
			if track == animationTrack then
				table.remove(activeAnimations, i)
				break
			end
		end
		if onAnimationEnd then
			onAnimationEnd() -- Call the callback function when animation ends
		end
	end)

	return true
end

-- Stop a specific animation if it is active
function module.StopAnim(Animation : Animation, Humanoid : Humanoid)
	if not Animation then
		warn("No animation provided to stop")
		return false
	end
	if not Humanoid then
		warn("No humanoid provided to stop animation")
		return false
	end

	local animator = Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		warn("No Animator found in Humanoid")
		return false
	end

	-- Find and stop the animation if it's currently active
	for i, track in ipairs(activeAnimations) do
		if track.Animation == Animation then
			track:Stop()
			table.remove(activeAnimations, i)
			print("Animation stopped: " .. Animation.Name)
			return true
		end
	end

	print("Animation not found in active animations")
	return false
end

return module
