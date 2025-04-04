local rs = game:GetService("ReplicatedStorage")

local module = {}

-- Adds highlight onto an object for a short duration
function module.PlayHitVFX(Object)
	if not Object then warn("Object Not found, VFX not playing") end
	task.spawn(function()
		local newHighlight = rs.VFX.HitHighlight:Clone()
		newHighlight.Parent = Object
		task.wait(0.2)
		newHighlight:Destroy()
	end)
end

return module
