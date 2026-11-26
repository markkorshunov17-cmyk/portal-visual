
-- PTD AFK v7
-- LocalScript
-- Place in StarterPlayer > StarterPlayerScripts
-- LOCAL TEST VERSION: does not modify PTD server data.

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local PG = LP:WaitForChild("PlayerGui")

local running = false
local towers = {}
local totalUpgrades = 0
local startedAt = 0

local CONFIG = {
    {name = "Jerry", cost = 250, color = Color3.fromRGB(90, 180, 255)},
    {name = "Buff Turkey", cost = 800, color = Color3.fromRGB(255, 180, 70)},
    {name = "President", cost = 1600, color = Color3.fromRGB(180, 100, 255)},
    {name = "Space Cruiser", cost = 2200, color = Color3.fromRGB(80, 220, 170)}
}

local gui = Instance.new("ScreenGui")
gui.Name = "PTD_AFK_V7"
gui.ResetOnSpawn = false
gui.Parent = PG

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(290, 330)
frame.Position = UDim2.new(0, 20, 0.3, 0)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 29)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local function label(text, y, height, color)
    local obj = Instance.new("TextLabel")
    obj.Size = UDim2.new(1, -24, 0, height)
    obj.Position = UDim2.fromOffset(12, y)
    obj.BackgroundTransparency = 1
    obj.Text = text
    obj.TextColor3 = color or Color3.new(1,1,1)
    obj.TextXAlignment = Enum.TextXAlignment.Left
    obj.Font = Enum.Font.GothamBold
    obj.TextSize = 13
    obj.Parent = frame
    return obj
end

label("PORTAL HUB  |  AFK v7", 10, 25,
    Color3.fromRGB(90, 230, 160))

local status = label("Status: STOPPED", 45, 22)
local timer = label("Time: 00:00", 72, 22,
    Color3.fromRGB(255, 205, 90))
local count = label("Upgrades: 0", 99, 22,
    Color3.fromRGB(110, 190, 255))

local start = Instance.new("TextButton")
start.Size = UDim2.new(1, -24, 0, 38)
start.Position = UDim2.fromOffset(12, 135)
start.BackgroundColor3 = Color3.fromRGB(0, 145, 80)
start.Text = "START"
start.TextColor3 = Color3.new(1,1,1)
start.Font = Enum.Font.GothamBold
start.TextSize = 14
start.Parent = frame
Instance.new("UICorner", start).CornerRadius = UDim.new(0, 7)

local stop = Instance.new("TextButton")
stop.Size = UDim2.new(1, -24, 0, 38)
stop.Position = UDim2.fromOffset(12, 180)
stop.BackgroundColor3 = Color3.fromRGB(155, 45, 55)
stop.Text = "STOP"
stop.TextColor3 = Color3.new(1,1,1)
stop.Font = Enum.Font.GothamBold
stop.TextSize = 14
stop.Parent = frame
Instance.new("UICorner", stop).CornerRadius = UDim.new(0, 7)

local log = label("Waiting...", 230, 80,
    Color3.fromRGB(180, 180, 190))
log.TextWrapped = true
log.TextYAlignment = Enum.TextYAlignment.Top

-- Create local demonstration objects.
local folder = workspace:FindFirstChild("PTD_AFK_Demo")
if folder then folder:Destroy() end

folder = Instance.new("Folder")
folder.Name = "PTD_AFK_Demo"
folder.Parent = workspace

local function spawnTower(data, index)
    local model = Instance.new("Model")
    model.Name = data.name

    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(4, 1, 4)
    base.Anchored = true
    base.Color = data.color
    base.Position = Vector3.new(index * 6, 2, 0)
    base.Parent = model

    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(2, 3, 2)
    body.Anchored = true
    body.Color = data.color:Lerp(Color3.new(1,1,1), 0.25)
    body.Position = base.Position + Vector3.new(0, 2, 0)
    body.Parent = model

    model.PrimaryPart = base
    model:SetAttribute("Level", 1)
    model.Parent = folder

    return model
end

local function spawnAll()
    for _, object in ipairs(folder:GetChildren()) do
        object:Destroy()
    end

    table.clear(towers)

    for i, data in ipairs(CONFIG) do
        local model = spawnTower(data, i)
        table.insert(towers, {
            model = model,
            level = 1,
            name = data.name
        })
    end

    log.Text = "Spawned 4 local demo towers."
end

local function upgradeOne(entry)
    if entry.level >= 4 then
        return
    end

    -- Random pause for local test pacing only.
    local pause = math.random(10, 25) / 10
    log.Text = ("Waiting %.1fs before %s upgrade...")
        :format(pause, entry.name)

    local deadline = os.clock() + pause
    while running and os.clock() < deadline do
        task.wait(0.1)
    end

    if not running then return end

    entry.level += 1
    entry.model:SetAttribute("Level", entry.level)

    local body = entry.model:FindFirstChild("Body")
    if body then
        body.Size = Vector3.new(2, 3 + entry.level, 2)
        body.Position = entry.model.PrimaryPart.Position
            + Vector3.new(0, 1.5 + entry.level / 2, 0)
    end

    totalUpgrades += 1
    count.Text = "Upgrades: " .. totalUpgrades
    log.Text = entry.name .. " upgraded to level " .. entry.level
end

local function runTest()
    while running do
        local found = false

        for _, entry in ipairs(towers) do
            if not running then break end

            if entry.level < 4 then
                found = true
                upgradeOne(entry)
            end
        end

        if not found then
            status.Text = "Status: ALL LEVEL 4"
            running = false
            break
        end

        task.wait(0.5)
    end
end

start.MouseButton1Click:Connect(function()
    if running then return end

    if #towers == 0 then
        spawnAll()
    end

    running = true
    startedAt = os.clock()
    status.Text = "Status: RUNNING"
    task.spawn(runTest)
end)

stop.MouseButton1Click:Connect(function()
    running = false
    status.Text = "Status: STOPPED"
    log.Text = "Test stopped."
end)

task.spawn(function()
    while gui.Parent do
        if running then
            local elapsed = math.floor(os.clock() - startedAt)
            timer.Text = ("Time: %02d:%02d")
                :format(math.floor(elapsed / 60), elapsed % 60)
        end
        task.wait(0.5)
    end
end)

spawnAll()
print("[PTD AFK v7] Local demo ready.")
