local module = {}

function module.ApplyKnockback(character: Model, direction: Vector3, force: number, duration: number)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		warn("No HumanoidRootPart found for knockback")
		return
	end

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = direction.Unit * force
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.P = 1250
	bodyVelocity.Parent = hrp

	task.delay(duration or 0.25, function()
		bodyVelocity:Destroy()
	end)
end

return module
