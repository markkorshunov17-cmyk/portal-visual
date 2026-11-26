-- language: Lua
-- target: Roblox client (Portal Tower Defense)
-- AFK farm — leaderstats.money aware, waits for funds, GUI toggle

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PlaceTower     = Remotes:WaitForChild("PlaceTower")
local UpgradeTower   = Remotes:WaitForChild("UpgradeTower")
local DifficultyVote = Remotes:WaitForChild("DifficultyVote")
local TowersFolder   = workspace:WaitForChild("Towers")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    Difficulty      = "Nightmare",
    MoneyStatName   = "money",   -- имя статы в leaderstats
    PlaceDelay      = 0.3,
    UpgradeDelay    = 0.15,
    UpgradeMaxTries = 60,
    ClickInterval   = 5,
    StartTexts      = { "start", "начать", "wave", "волна", "next", "далее", "play", "играть" },
    MoneyWaitTimeout = 120,       -- максимум секунд ждать деньги
}

local PLACEMENTS = {
    { name = "Jerry",        pos = Vector3.new(115.77935791015625, 7.954591751098633, -46.52529525756836), rot = 0 },
    { name = "Jerry",        pos = Vector3.new(113.5140380859375,  7.933708190917969, -49.838958740234375), rot = 0 },
    { name = "Buff Turkey",  pos = Vector3.new(105.41456604003906, 7.935329437255859, -50.34072494506836), rot = 0 },
    { name = "President",    pos = Vector3.new(109.55278778076172, 7.922641754150391, -46.534759521484375), rot = 0 },
    { name = "President",    pos = Vector3.new(109.61953735351562, 7.935300827026367, -50.340065002441406), rot = 0 },
    { name = "Space Cruiser", pos = Vector3.new(131.7823028564453, 8.261308670043945, -51.3819694519043), rot = 0 },
}

-- ============================================================
-- LEADERSTATS MONEY
-- ============================================================
local function GetMoney()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end
    local stat = ls:FindFirstChild(CONFIG.MoneyStatName)
    if not stat then return nil end
    return stat.Value
end

-- Ждём, пока денег станет >= target (или таймаут)
local function WaitForMoney(target, timeoutSec)
    timeoutSec = timeoutSec or CONFIG.MoneyWaitTimeout
    local start = os.clock()
    while os.clock() - start < timeoutSec do
        local m = GetMoney()
        if m and m >= target then return true, m end
        task.wait(1)
    end
    local m = GetMoney()
    return false, m
end

-- ============================================================
-- VOTE
-- ============================================================
local function VoteDifficulty(diff)
    pcall(function()
        DifficultyVote:FireServer(diff)
    end)
end

-- ============================================================
-- PLACE — ставим по одному, ждём деньги если отказ
-- ============================================================
local function PlaceAll()
    local placed = 0
    for i, e in ipairs(PLACEMENTS) do
        local success = false
        for attempt = 1, 30 do
            local ok, ret = pcall(function()
                return PlaceTower:InvokeServer(e.name, e.pos, e.rot or 0)
            end)
            if ok and ret ~= false and ret ~= nil then
                success = true
                print(("[AFK] %s поставлен (%d/%d)"):format(e.name, i, #PLACEMENTS))
                break
            end
            -- отказ: ждём деньги и пробуем снова
            local before = GetMoney()
            print(("[AFK] %s отказ. Баланс: %s. Ждём..."):format(e.name, tostring(before)))
            WaitForMoney((before or 0) + 1, 30)   -- ждём, пока баланс хоть немного вырастет
        end
        if success then placed = placed + 1
        else warn(("[AFK] %s не поставлен после 30 попыток"):format(e.name)) end
        task.wait(CONFIG.PlaceDelay)
    end
    print(("[AFK] Итого: %d/%d"):format(placed, #PLACEMENTS))
end

-- ============================================================
-- UPGRADE — качаем, ждём деньги при отказе
-- ============================================================
local function FindTowersBySuffix(suffix)
    local out = {}
    for _, obj in ipairs(TowersFolder:GetChildren()) do
        if obj.Name:sub(-#suffix) == suffix then table.insert(out, obj) end
    end
    return out
end

local function UpgradeOne(tower)
    local levels = 0
    local fails = 0
    while levels < CONFIG.UpgradeMaxTries and fails < 10 do
        local ok, ret = pcall(function()
            return UpgradeTower:InvokeServer(tower)
        end)
        if not ok then
            warn(("[AFK] %s upgrade error: %s"):format(tower.Name, tostring(ret)))
            break
        end
        if ret == false or ret == nil then
            fails = fails + 1
            local before = GetMoney()
            print(("[AFK] %s уровень %d отказ. Баланс: %s. Ждём..."):format(tower.Name, levels + 1, tostring(before)))
            WaitForMoney((before or 0) + 1, 20)
        else
            levels = levels + 1
            fails = 0
            print(("[AFK] %s -> уровень %d"):format(tower.Name, levels + 1))
        end
        task.wait(CONFIG.UpgradeDelay)
    end
    return levels
end

local function UpgradeAll()
    for _, suffix in ipairs({ "Jerry", "Buff Turkey", "President", "Space Cruiser" }) do
        for _, t in ipairs(FindTowersBySuffix(suffix)) do
            local lv = UpgradeOne(t)
            print(("[AFK] %s итог: +%d уровней"):format(t.Name, lv))
        end
    end
end

-- ============================================================
-- AUTO-CLICK START
-- ============================================================
local function FindStartButton()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("TextButton") then
                    local txt = obj.Text:lower()
                    for _, key in ipairs(CONFIG.StartTexts) do
                        if txt:find(key) then return obj end
                    end
                end
            end
        end
    end
    return nil
end

local function ClickButton(btn)
    pcall(function()
        if btn.Activate then btn:Activate()
        else
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(pos); VirtualUser:Button1Up(pos)
        end
    end)
end

-- ============================================================
-- FARM LOOP
-- ============================================================
local FarmRunning = false
local FarmThread = nil

local function FarmLoop()
    while FarmRunning do
        VoteDifficulty(CONFIG.Difficulty)
        task.wait(1)
        if not FarmRunning then break end

        PlaceAll()
        task.wait(1)
        if not FarmRunning then break end

        UpgradeAll()
        if not FarmRunning then break end

        while FarmRunning do
            local btn = FindStartButton()
            if btn and btn.Visible then ClickButton(btn) end
            task.wait(CONFIG.ClickInterval)
        end
    end
end

local function StartFarm()
    if FarmRunning then return end
    FarmRunning = true
    -- проверка money при старте
    local m = GetMoney()
    if m then print(("[AFK] Баланс на старте: %d"):format(m))
    else warn("[AFK] leaderstats.money не найден — проверь имя статы") end
    FarmThread = task.spawn(FarmLoop)
    print("[AFK] Фарм запущен")
end

local function StopFarm()
    FarmRunning = false
    if FarmThread then pcall(task.cancel, FarmThread); FarmThread = nil end
    print("[AFK] Фарм остановлен")
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
    gui.Parent = PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 130)
    frame.Position = UDim2.new(0, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -16, 0, 26)
    title.Position = UDim2.new(0, 8, 0, 6)
    title.BackgroundTransparency = 1
    title.Text = "PTD AFK"
    title.TextColor3 = Color3.fromRGB(0, 220, 110)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, -32, 0, 40)
    btn.Position = UDim2.new(0, 16, 0, 40)
    btn.BorderSizePixel = 0
    btn.Text = "▶  ВКЛ"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(1, -32, 0, 20)
    status.Position = UDim2.new(0, 16, 0, 88)
    status.BackgroundTransparency = 1
    status.Text = "ВЫКЛ"
    status.TextColor3 = Color3.fromRGB(200, 60, 60)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextXAlignment = Enum.TextXAlignment.Left

    local function Refresh()
        if FarmRunning then
            btn.Text = "■  ВЫКЛ"
            btn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
            status.Text = "РАБОТАЕТ"
            status.TextColor3 = Color3.fromRGB(0, 220, 110)
        else
            btn.Text = "▶  ВКЛ"
            btn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
            status.Text = "ВЫКЛ"
            status.TextColor3 = Color3.fromRGB(200, 60, 60)
        end
    end

    btn.MouseButton1Click:Connect(function()
        if FarmRunning then StopFarm() else StartFarm() end
        Refresh()
    end)

    Refresh()
end

BuildGui()
print("[AFK] Меню готово. ВКЛ / ВЫКЛ. Money stat: " .. CONFIG.MoneyStatName)