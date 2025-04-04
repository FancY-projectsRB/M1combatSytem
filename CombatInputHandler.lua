-- Game services
local players = game:GetService("Players")
local uis : UserInputService = game:GetService("UserInputService")
local rs = game:GetService("ReplicatedStorage")

-- Folders
local modules = rs.Modules
local combatModules = modules.Combat

-- Modules
local localCombatHanderModule = require(combatModules.Local.M1Combat)

-- Logic Variables
local localPlayer = players.LocalPlayer

-- When an input is detected send it to the combat system for processing
uis.InputBegan:Connect(function(inp, proc)
	if proc then print("user is in a game proc event canciling input check")return end
	localCombatHanderModule.handleInput(inp)
end)








