
-- PORTAL HUB | Version 1.0
-- Local visual interface prototype

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "PortalHub"
gui.ResetOnSpawn = false

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(340, 420)
main.Position = UDim2.new(0.5, -170, 0.5, -210)
main.BackgroundColor3 = Color3.fromRGB(18, 15, 29)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundColor3 = Color3.fromRGB(85, 45, 145)
title.Text = "PORTAL HUB"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextSize = 23
title.Font = Enum.Font.GothamBold
title.Parent = main

local coins = 999999
local inventory = {}

local function makeLabel(text, y)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -30, 0, 35)
    label.Position = UDim2.fromOffset(15, y)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.new(1, 1, 1)
    label.TextSize = 17
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = main
    return label
end

local coinLabel = makeLabel("Visual Coins: " .. coins, 65)

local coinInput = Instance.new("TextBox")
coinInput.Size = UDim2.new(1, -30, 0, 38)
coinInput.Position = UDim2.fromOffset(15, 105)
coinInput.PlaceholderText = "Enter coin amount"
coinInput.Text = ""
coinInput.TextSize = 16
coinInput.Parent = main

local coinButton = Instance.new("TextButton")
coinButton.Size = UDim2.new(1, -30, 0, 38)
coinButton.Position = UDim2.fromOffset(15, 150)
coinButton.Text = "SET VISUAL COINS"
coinButton.BackgroundColor3 = Color3.fromRGB(105, 60, 175)
coinButton.TextColor3 = Color3.new(1, 1, 1)
coinButton.Parent = main

coinButton.MouseButton1Click:Connect(function()
    local amount = tonumber(coinInput.Text)
    if amount and amount >= 0 then
        coins = math.floor(amount)
        coinLabel.Text = "Visual Coins: " .. coins
    end
end)

local units = {
    "Rick",
    "Evil Morty",
    "Doofus Jerry",
    "Milos",
    "Docs"
}

local selected = nil

makeLabel("UNIT SELECTION", 200)

local unitButton = Instance.new("TextButton")
unitButton.Size = UDim2.new(1, -30, 0, 40)
unitButton.Position = UDim2.fromOffset(15, 240)
unitButton.Text = "SELECT UNIT"
unitButton.BackgroundColor3 = Color3.fromRGB(55, 45, 80)
unitButton.TextColor3 = Color3.new(1, 1, 1)
unitButton.Parent = main

local giveButton = Instance.new("TextButton")
giveButton.Size = UDim2.new(1, -30, 0, 40)
giveButton.Position = UDim2.fromOffset(15, 290)
giveButton.Text = "ADD TO VISUAL INVENTORY"
giveButton.BackgroundColor3 = Color3.fromRGB(105, 60, 175)
giveButton.TextColor3 = Color3.new(1, 1, 1)
giveButton.Parent = main

local inventoryLabel = makeLabel("Inventory: Empty", 345)

unitButton.MouseButton1Click:Connect(function()
    selected = units[math.random(1, #units)]
    unitButton.Text = selected
end)

giveButton.MouseButton1Click:Connect(function()
    if selected then
        table.insert(inventory, selected)
        inventoryLabel.Text = "Inventory: " .. #inventory .. " units"
    end
end)

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -35, 0, 10)
close.Text = "X"
close.Parent = main

close.MouseButton1Click:Connect(function()
    gui.Enabled = false
end)

gui.Parent = player:WaitForChild("PlayerGui")
print("PORTAL HUB loaded!")
