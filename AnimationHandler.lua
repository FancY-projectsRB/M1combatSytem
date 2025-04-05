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

return module
