local module = {}

function module.PlaySound(Sounds, Object)
	if not Sounds then
		warn("No sound(s) provided")
		return
	end
	if not Object then
		warn("Object not found, sound(s) will not play")
		return
	end

	-- Convert single sound to a table
	if typeof(Sounds) == "Instance" and Sounds:IsA("Sound") then
		Sounds = {Sounds}
	end

	for _, sound in ipairs(Sounds) do
		local newSound = sound:Clone()
		newSound.Parent = Object
		newSound:Play()

		newSound.Ended:Connect(function()
			newSound:Destroy()
		end)
	end
end



function module.RandSound(soundtable)
	if #soundtable < 1 then
		warn("No sounds in the soundtable")
		return nil
	end
	local randomIndex = math.random(1, #soundtable)
	local randomSound = soundtable[randomIndex]
	return randomSound
end
return module
