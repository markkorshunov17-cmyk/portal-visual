-- language: Lua
-- target: Roblox client (Portal Tower Defense by RMTD Development)
-- single-file AFK farm with GUI toggle button
-- place in executor, run once, use menu button to start/stop

-- ============================================================
-- CONFIG — правь только это, если имена ремоутов другие
-- ============================================================
local CONFIG = {
    Remotes = {
        SummonUnit  = "SummonUnit",
        UpgradeUnit = "UpgradeUnit",
        StartWave   = "StartWave",
    },
    UnitsFolder     = "Units",
    SummonDelay     = 0.8,
    UpgradeDelay    = 1.2,
    WaveDelay       = 2.0,
    AntiAFKDelay    = 60,
    UpgradePriority = "Cheapest", -- "Cheapest" | "MostExpensive" | "First"
}

-- ============================================================
-- SERVICES & STATE
-- ============================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

local RemoteCache = {}
local FarmRunning = false
local FarmThread  = nil

-- ============================================================
-- REMOTE DISCOVERY
-- ============================================================
local function FindRemote(name)
    if RemoteCache[name] then return RemoteCache[name] end
    local r = ReplicatedStorage:FindFirstChild(name, true)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
        RemoteCache[name] = r
        return r
    end
    warn(("[AFK] Remote не найден: %s — проверь CONFIG.Remotes через Dex"):format(name))
    return nil
end

local function Fire(remoteName, ...)
    local r = FindRemote(remoteName)
    if not r then return false end
    local ok, err = pcall(function(...)
        if r:IsA("RemoteFunction") then
            return r:InvokeServer(...)
        else
            r:FireServer(...)
        end
    end, ...)
    if not ok then
        warn(("[AFK] Fire %s: %s"):format(remoteName, tostring(err)))
    end
    return ok
end

-- ============================================================
-- UNIT DISCOVERY
-- ============================================================
local function GetMyUnits()
    local folder = workspace:FindFirstChild(CONFIG.UnitsFolder)
    if not folder then return {} end
    local out = {}
    for _, obj in ipairs(folder:GetChildren()) do
        local owner = obj:GetAttribute("Owner") or obj:GetAttribute("Player")
        if owner == LocalPlayer or owner == LocalPlayer.Name then
            table.insert(out, obj)
            continue
        end
        if obj:FindFirstChildOfClass("Humanoid") and not obj.Name:lower():find("enemy") then
            table.insert(out, obj)
        end
    end
    return out
end

-- ============================================================
-- FARM ACTIONS
-- ============================================================
local function TrySummon()
    Fire(CONFIG.Remotes.SummonUnit)
end

local function TryUpgrade()
    local units = GetMyUnits()
    if #units == 0 then return end

    if CONFIG.UpgradePriority ~= "First" then
        table.sort(units, function(a, b)
            local ca = a:GetAttribute("Cost") or a:GetAttribute("Value") or 0
            local cb = b:GetAttribute("Cost") or b:GetAttribute("Value") or 0
            if CONFIG.UpgradePriority == "MostExpensive" then
                return ca > cb
            else
                return ca < cb
            end
        end)
    end

    Fire(CONFIG.Remotes.UpgradeUnit, units[1])
end

local function TryStartWave()
    Fire(CONFIG.Remotes.StartWave)
end

-- ============================================================
-- ANTI-AFK
-- ============================================================
local function StartAntiAFK()
    task.spawn(function()
        while true do
            task.wait(CONFIG.AntiAFKDelay)
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:Button1Down(Vector2.new(0, 0))
                VirtualUser:Button1Up(Vector2.new(0, 0))
            end)
        end
    end)
end

-- ============================================================
-- FARM LOOP
-- ============================================================
local function FarmLoop()
    while FarmRunning do
        TrySummon()
        task.wait(CONFIG.SummonDelay)
        if not FarmRunning then break end

        TryUpgrade()
        task.wait(CONFIG.UpgradeDelay)
        if not FarmRunning then break end

        TryStartWave()
        task.wait(CONFIG.WaveDelay)
    end
end

local function StartFarm()
    if FarmRunning then return end
    FarmRunning = true
    FarmThread = task.spawn(FarmLoop)
end

local function StopFarm()
    FarmRunning = false
    if FarmThread then
        task.cancel(FarmThread)
        FarmThread = nil
    end
end

-- ============================================================
-- GUI
-- ============================================================
local function BuildGui()
    local old = PlayerGui:FindFirstChild("PTD_AFK_Menu")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "PTD_AFK_Menu"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.new(0, 260, 0, 120)
    frame.Position = UDim2.new(0, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 200, 100)
    stroke.Thickness = 1
    stroke.Transparency = 0.4
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 0, 28)
    title.Position = UDim2.new(0, 8, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "PTD AFK Farm"
    title.TextColor3 = Color3.fromRGB(0, 220, 110)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Name = "ToggleFarm"
    toggleBtn.Size = UDim2.new(1, -32, 0, 42)
    toggleBtn.Position = UDim2.new(0, 16, 0, 48)
    toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "▶  ЗАПУСТИТЬ ФАРМ"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 15
    toggleBtn.AutoButtonColor = false
    toggleBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = toggleBtn

    local status = Instance.new("TextLabel")
    status.Name = "Status"
    status.Size = UDim2.new(1, -32, 0, 18)
    status.Position = UDim2.new(0, 16, 0, 96)
    status.BackgroundTransparency = 1
    status.Text = "●  ОСТАНОВЛЕН"
    status.TextColor3 = Color3.fromRGB(180, 60, 60)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local function Refresh()
        if FarmRunning then
            toggleBtn.Text = "■  ОСТАНОВИТЬ ФАРМ"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
            status.Text = "●  РАБОТАЕТ"
            status.TextColor3 = Color3.fromRGB(0, 220, 110)
        else
            toggleBtn.Text = "▶  ЗАПУСТИТЬ ФАРМ"
            toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
            status.Text = "●  ОСТАНОВЛЕН"
            status.TextColor3 = Color3.fromRGB(180, 60, 60)
        end
    end

    toggleBtn.MouseButton1Click:Connect(function()
        if FarmRunning then
            StopFarm()
        else
            StartFarm()
        end
        Refresh()
    end)

    Refresh()
    return gui
end

-- ============================================================
-- BOOT
-- ============================================================
StartAntiAFK()
BuildGui()
print("[AFK] PTD Farm загружен. Кнопка в меню. Если warn про Remote — правь CONFIG.Remotes.")