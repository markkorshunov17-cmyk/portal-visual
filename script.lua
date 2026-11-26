-- language: Lua
-- target: Roblox client (Portal Tower Defense)
-- AFK farm — timed placement schedule, then upgrade, GUI toggle

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
    MoneyStatNames  = { "cash", "Cash", "money", "Money" },
    UpgradeDelay    = 0.15,
    UpgradeMaxTries = 60,
    ClickInterval   = 5,
    StartTexts      = { "start", "начать", "wave", "волна", "next", "далее", "play", "играть" },
    PlaceRetryEvery = 1,      -- если отказ — пробовать каждую секунду
    PlaceMaxWait    = 60,     -- максимум секунд ждать на одну точку
}

-- ============================================================
-- РАСПИСАНИЕ: { время_от_старта_сек, имя, позиция }
-- ============================================================
local SCHEDULE = {
    { t = 0,   name = "Jerry",        pos = Vector3.new(115.77935791015625, 7.954591751098633, -46.52529525756836) },
    { t = 0,   name = "Jerry",        pos = Vector3.new(113.5140380859375,  7.933708190917969, -49.838958740234375) },
    { t = 15,  name = "Buff Turkey",  pos = Vector3.new(105.41456604003906, 7.935329437255859, -50.34072494506836) },
    { t = 45,  name = "President",    pos = Vector3.new(109.55278778076172, 7.922641754150391, -46.534759521484375) },
    { t = 75,  name = "President",    pos = Vector3.new(109.61953735351562, 7.935300827026367, -50.340065002441406) },
    { t = 105, name = "Space Cruiser", pos = Vector3.new(131.7823028564453, 8.261308670043945, -51.3819694519043) },
}

-- ============================================================
-- CASH
-- ============================================================
local MoneyStat = nil
local function FindMoneyStat()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end
    for _, name in ipairs(CONFIG.MoneyStatNames) do
        local s = ls:FindFirstChild(name)
        if s and (s:IsA("IntValue") or s:IsA("NumberValue")) then return s end
    end
    return nil
end

local function GetMoney()
    if not MoneyStat or not MoneyStat.Parent then MoneyStat = FindMoneyStat() end
    return MoneyStat and MoneyStat.Value or nil
end

-- ============================================================
-- VOTE
-- ============================================================
local function VoteDifficulty(diff)
    pcall(function() DifficultyVote:FireServer(diff) end)
end

-- ============================================================
-- PLACE ПО РАСПИСАНИЮ
-- ============================================================
local function PlaceTimed(entry)
    local start = os.clock()
    local deadline = entry.t + CONFIG.PlaceMaxWait
    local attempt = 0
    while os.clock() < deadline do
        -- ждём, пока не наступит время
        local now = os.clock() - start
        if now < entry.t then
            task.wait(entry.t - now)
        end
        attempt = attempt + 1
        local ok, ret = pcall(function()
            return PlaceTower:InvokeServer(entry.name, entry.pos, 0)
        end)
        if ok and ret ~= false and ret ~= nil then
            print(("[AFK] t+%ds %s поставлен (попытка %d, cash=%s)"):format(entry.t, entry.name, attempt, tostring(GetMoney())))
            return true
        end
        print(("[AFK] t+%ds %s отказ (cash=%s), пробую снова..."):format(entry.t, entry.name, tostring(GetMoney())))
        task.wait(CONFIG.PlaceRetryEvery)
    end
    warn(("[AFK] %s не поставлен за %d сек"):format(entry.name, CONFIG.PlaceMaxWait))
    return false
end

local function PlaceAllTimed()
    local placed = 0
    for _, entry in ipairs(SCHEDULE) do
        if PlaceTimed(entry) then placed = placed + 1 end
    end
    print(("[AFK] Расставлено: %d/%d"):format(placed, #SCHEDULE))
end

-- ============================================================
-- UPGRADE (после расстановки)
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
    while levels < CONFIG.UpgradeMaxTries and fails < 15 do
        local ok, ret = pcall(function()
            return UpgradeTower:InvokeServer(tower)
        end)
        if not ok then
            warn(("[AFK] %s upgrade error: %s"):format(tower.Name, tostring(ret)))
            break
        end
        if ret == false or ret == nil then
            fails = fails + 1
            task.wait(2)   -- ждём, пока cash капнет
        else
            levels = levels + 1
            fails = 0
            print(("[AFK] %s -> ур.%d (cash=%s)"):format(tower.Name, levels + 1, tostring(GetMoney())))
        end
        task.wait(CONFIG.UpgradeDelay)
    end
    return levels
end

local function UpgradeAll()
    for _, suffix in ipairs({ "Jerry", "Buff Turkey", "President", "Space Cruiser" }) do
        for _, t in ipairs(FindTowersBySuffix(suffix)) do
            local lv = UpgradeOne(t)
            print(("[AFK] %s итог: +%d"):format(t.Name, lv))
        end
    end
end

-- ============================================================
-- AUTO-CLICK
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

        PlaceAllTimed()
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
    MoneyStat = FindMoneyStat()
    if MoneyStat then print(("[AFK] cash найден: %d"):format(MoneyStat.Value))
    else warn("[AFK] cash не найден") end
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
    gui.Name = "PTD_AFK_Menu"; gui.ResetOnSpawn = false; gui.Parent = PlayerGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 130); frame.Position = UDim2.new(0, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22); frame.BorderSizePixel = 0
    frame.Active = true; frame.Draggable = true; frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -16, 0, 26); title.Position = UDim2.new(0, 8, 0, 6)
    title.BackgroundTransparency = 1; title.Text = "PTD AFK"
    title.TextColor3 = Color3.fromRGB(0, 220, 110); title.Font = Enum.Font.GothamBold
    title.TextSize = 15; title.TextXAlignment = Enum.TextXAlignment.Left
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, -32, 0, 40); btn.Position = UDim2.new(0, 16, 0, 40)
    btn.BorderSizePixel = 0; btn.Text = "▶  ВКЛ"; btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 14; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local status = Instance.new("TextLabel", frame)
    status.Size = UDim2.new(1, -32, 0, 20); status.Position = UDim2.new(0, 16, 0, 88)
    status.BackgroundTransparency = 1; status.Text = "ВЫКЛ"
    status.TextColor3 = Color3.fromRGB(200, 60, 60); status.Font = Enum.Font.Gotham
    status.TextSize = 12; status.TextXAlignment = Enum.TextXAlignment.Left
    local function Refresh()
        if FarmRunning then
            btn.Text = "■  ВЫКЛ"; btn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
            status.Text = "РАБОТАЕТ"; status.TextColor3 = Color3.fromRGB(0, 220, 110)
        else
            btn.Text = "▶  ВКЛ"; btn.BackgroundColor3 = Color3.fromRGB(0, 140, 70)
            status.Text = "ВЫКЛ"; status.TextColor3 = Color3.fromRGB(200, 60, 60)
        end
    end
    btn.MouseButton1Click:Connect(function()
        if FarmRunning then StopFarm() else StartFarm() end
        Refresh()
    end)
    Refresh()
end

-- ============================================================
-- BOOT — автостарт
-- ============================================================
BuildGui()
local ok = pcall(function() workspace:WaitForChild("Towers", 30) end)
if ok then
    task.wait(2)
    StartFarm()
else
    warn("[AFK] Towers не появились — запусти скрипт внутри катки")
end