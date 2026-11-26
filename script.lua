
-- PORTAL HUB v2.0
-- Local visual prototype for Roblox Studio
-- Place as a LocalScript in StarterPlayerScripts

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local old = player.PlayerGui:FindFirstChild("PortalHub")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "PortalHub"
gui.ResetOnSpawn = false
gui.Parent = player.PlayerGui

local function create(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        obj[k] = v
    end
    obj.Parent = parent
    return obj
end

local main = create("Frame", {
    Size = UDim2.fromOffset(340, 440),
    Position = UDim2.new(0.5, -170, 0.5, -220),
    BackgroundColor3 = Color3.fromRGB(20, 16, 31),
    BorderSizePixel = 0
}, gui)

create("UICorner", {
    CornerRadius = UDim.new(0, 14)
}, main)

local title = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = Color3.fromRGB(100, 55, 170),
    Text = "PORTAL HUB",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 23,
    Font = Enum.Font.GothamBold
}, main)

local coins = 0
local inventory = {}
local selected = nil

-- Only provisional names; replace with verified unit names.
local units = {
    "Docs",
    "Milos",
    "News Milo",
    "Rick",
    "Evil Morty"
}

local coinInput = create("TextBox", {
    Size = UDim2.new(1, -30, 0, 38),
    Position = UDim2.fromOffset(15, 65),
    BackgroundColor3 = Color3.fromRGB(42, 32, 58),
    TextColor3 = Color3.new(1, 1, 1),
    PlaceholderText = "Enter visual coin amount",
    Text = "",
    TextSize = 15,
    Font = Enum.Font.Gotham
}, main)

local coinLabel = create("TextLabel", {
    Size = UDim2.new(1, -30, 0, 30),
    Position = UDim2.fromOffset(15, 105),
    BackgroundTransparency = 1,
    Text = "Visual Coins: 0",
    TextColor3 = Color3.fromRGB(210, 180, 255),
    TextSize = 17,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left
}, main)

local coinButton = create("TextButton", {
    Size = UDim2.new(1, -30, 0, 35),
    Position = UDim2.fromOffset(15, 140),
    BackgroundColor3 = Color3.fromRGB(100, 55, 170),
    Text = "SET VISUAL COINS",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Font = Enum.Font.GothamBold
}, main)

coinButton.MouseButton1Click:Connect(function()
    local amount = tonumber(coinInput.Text)
    if amount and amount >= 0 then
        coins = math.floor(amount)
        coinLabel.Text = "Visual Coins: " .. coins
    end
end)

local search = create("TextBox", {
    Size = UDim2.new(1, -30, 0, 36),
    Position = UDim2.fromOffset(15, 190),
    BackgroundColor3 = Color3.fromRGB(42, 32, 58),
    TextColor3 = Color3.new(1, 1, 1),
    PlaceholderText = "Search unit...",
    Text = "",
    TextSize = 14
}, main)

local unitList = create("ScrollingFrame", {
    Size = UDim2.new(1, -30, 0, 100),
    Position = UDim2.fromOffset(15, 232),
    BackgroundColor3 = Color3.fromRGB(30, 24, 43),
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    CanvasSize = UDim2.fromOffset(0, #units * 36)
}, main)

local layout = create("UIListLayout", {
    Padding = UDim.new(0, 3)
}, unitList)

local function refreshUnits()
    for _, child in ipairs(unitList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local count = 0

    for _, name in ipairs(units) do
        if string.find(string.lower(name), string.lower(search.Text), 1, true) then
            count += 1

            local button = create("TextButton", {
                Size = UDim2.new(1, -6, 0, 32),
                BackgroundColor3 = Color3.fromRGB(75, 48, 110),
                Text = name,
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 14,
                Font = Enum.Font.Gotham
            }, unitList)

            button.MouseButton1Click:Connect(function()
                selected = name
                search.Text = name
            end)
        end
    end

    unitList.CanvasSize = UDim2.fromOffset(0, count * 35)
end

search:GetPropertyChangedSignal("Text"):Connect(refreshUnits)
refreshUnits()

local giveButton = create("TextButton", {
    Size = UDim2.new(1, -30, 0, 35),
    Position = UDim2.fromOffset(15, 340),
    BackgroundColor3 = Color3.fromRGB(115, 65, 190),
    Text = "GIVE",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 16,
    Font = Enum.Font.GothamBold
}, main)

local inventoryLabel = create("TextLabel", {
    Size = UDim2.new(1, -30, 0, 45),
    Position = UDim2.fromOffset(15, 380),
    BackgroundTransparency = 1,
    Text = "Visual Inventory: Empty",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 13,
    Font = Enum.Font.Gotham,
    TextWrapped = true
}, main)

giveButton.MouseButton1Click:Connect(function()
    if not selected then
        inventoryLabel.Text = "Select a unit first!"
        return
    end

    table.insert(inventory, selected)

    inventoryLabel.Text =
        "Visual Inventory: " ..
        table.concat(inventory, ", ")
end)

local close = create("TextButton", {
    Size = UDim2.fromOffset(30, 30),
    Position = UDim2.new(1, -35, 0, 9),
    BackgroundColor3 = Color3.fromRGB(65, 35, 95),
    Text = "X",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 16
}, main)

close.MouseButton1Click:Connect(function()
    gui.Enabled = false
end)

print("PORTAL HUB v2.0 loaded")
