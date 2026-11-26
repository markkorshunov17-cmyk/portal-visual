-- language: Lua
-- target: Roblox client (Portal Tower Defense)
-- AFK farm v13 — full build: costs, upgrade prices, cash-aware, GUI

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
    Difficulty      = "Nightmare",
    MoneyNames      = { "cash", "Cash", "money", "Money", "coins", "Coins" },
    PlaceRetryEvery = 0.5,
    UpgradeDelay    = 0.12,
    UpgradeFailsMax = 15,
    ClickInterval   = 4,
    StartTexts      = { "start", "начать", "wave", "волна" },
    ExcludeTexts    = { "again", "replay", "заново", "ещё раз", "exit", "выход",
                        "leave", "покинуть", "level", "lvl", "уровень" },
    BootWait         = 120,
    RemotesWait      = 30,
    RemoteNames      = { "PlaceTower", "UpgradeTower", "DifficultyVote" },
    MatchStartDelay  = 3,
    TowerWaitTimeout = 10,
    TowerWaitPoll    = 0.5,
    ClickMissLimit   = 15,
    CashPoll         = 0.5,
    UpgradeCashWait  = 60,   -- максимум секунд ждать деньги на апгрейд
}

-- ============================================================
-- ЦЕНЫ ПОСТРОЙКИ (точные, от тебя)
-- ============================================================
local COST = {
    ["Jerry"]         = 250,
    ["Buff Turkey"]   = 800,
    ["President"]     = 1600,
    ["Space Cruiser"] = 2200,
}

-- ============================================================
-- ЦЕНЫ АПГРЕЙДА (стоимость каждого шага; nil = неизвестно)
-- Jerry: 1→2 = 450, 2→3 = 1100, 3→4 = 2400, 4→5 = 4800
-- ============================================================
local UPGRADE_COST = {
    ["Jerry"] = { 450, 1100, 2400, 4800 },
    -- ["Buff Turkey"]   = { ... },   -- скинь через SimpleSpy — добавлю
    -- ["President"]     = { ... },
    -- ["Space Cruiser"] = { ... },
}

-- Возвращает стоимость следующего уровня или nil
local function NextUpgradeCost(towerName, currentLevel)
    local list = UPGRADE_COST[towerName]
    if not list then return nil end
    return list[currentLevel]  -- currentLevel: 1 = только поставлен
end

-- ============================================================
-- РАСПИСАНИЕ
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
-- STATE
-- ============================================================
local State = {
    running = false, phase = "idle", detail = "",
    timerEnd = nil, timerName = "", error = "",
}

local function SetPhase(phase, detail, timerEnd, timerName)
    State.phase = phase; State.detail = detail or ""
    State.timerEnd = timerEnd; State.timerName = timerName or ""
end

local MatchStart = 0
local function Elapsed() return os.clock() - MatchStart end

-- ============================================================
-- SCHEDULE VALIDATION
-- ============================================================
local function ValidateSchedule()
    for i, e in ipairs(SCHEDULE) do
        if type(e.name) ~= "string" or e.name == "" then
            return false, ("SCHEDULE[%d].name пустое"):format(i)
        end
        if typeof(e.pos) ~= "Vector3" then
            return false, ("SCHEDULE[%d].pos не Vector3"):format(i)
        end
        if type(e.t) ~= "number" or e.t < 0 then
            return false, ("SCHEDULE[%d].t не число"):format(i)
        end
        if not COST[e.name] then
            return false, ("SCHEDULE[%d]: нет цены для %s"):format(i, e.name)
        end
    end
    return true, nil
end

-- ============================================================
-- REMOTES
-- ============================================================
local RemoteFolder, RemoteCache = nil, {}

local function Remote(name)
    if RemoteCache[name] and RemoteCache[name].Parent then return RemoteCache[name] end
    RemoteCache[name] = nil
    if not RemoteFolder or not RemoteFolder.Parent then
        RemoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
    end
    if not RemoteFolder then return nil end
    local r = RemoteFolder:FindFirstChild(name)
    if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
        RemoteCache[name] = r; return r
    end
    return nil
end

local function WaitForRemotes(timeoutSec)
    local start = os.clock()
    while os.clock() - start < timeoutSec and State.running do
        if ReplicatedStorage:FindFirstChild("Remotes") then
            local missing = {}
            for _, name in ipairs(CONFIG.RemoteNames) do
                if not Remote(name) then table.insert(missing, name) end
            end
            if #missing == 0 then return true, nil end
            SetPhase("idle", "жду ремоуты: " .. table.concat(missing, ", "))
        else
            SetPhase("idle", "жду папку Remotes...")
        end
        task.wait(1)
    end
    return false, "ремоуты не появились за " .. timeoutSec .. " сек"
end

-- ============================================================
-- CASH
-- ============================================================
local CashStat = nil
local function FindCash()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if not ls then return nil end
    for _, n in ipairs(CONFIG.MoneyNames) do
        local s = ls:FindFirstChild(n)
        if s and (s:IsA("IntValue") or s:IsA("NumberValue")) then return s end
    end
    return nil
end
local function Cash()
    if not CashStat or not CashStat.Parent then CashStat = FindCash() end
    return CashStat and CashStat.Value or nil
end

-- Ждём cash >= need, обновляя detail. true = дождались.
local function WaitForCash(need, label)
    while State.running do
        local c = Cash()
        if c and c >= need then return true end
        SetPhase("place", ("жду %d (есть %s) для %s"):format(need, tostring(c or "?"), label or ""))
        task.wait(CONFIG.CashPoll)
    end
    return false
end

-- ============================================================
-- VOTE
-- ============================================================
local function Vote()
    local r = Remote("DifficultyVote")
    if not r then return false end
    pcall(function() r:FireServer(CONFIG.Difficulty) end)
    return true
end

-- ============================================================
-- PLACE
-- ============================================================
local function PlaceOne(entry)
    local waitLeft = entry.t - Elapsed()
    if waitLeft > 0 then task.wait(waitLeft) end
    if not State.running then return false end

    local cost = COST[entry.name] or 0

    -- ждём нужную сумму перед вызовом
    if not WaitForCash(cost, entry.name) then return false end
    if not State.running then return false end

    local attempt = 0
    while State.running do
        local r = Remote("PlaceTower")
        if not r then task.wait(2)
        else
            local c = Cash()
            if c and c < cost then
                if not WaitForCash(cost, entry.name) then return false end
            end
            attempt = attempt + 1
            local ok, ret = pcall(function() return r:InvokeServer(entry.name, entry.pos, 0) end)
            print(("[DEBUG] PlaceTower(%s) #%d cost=%d ok=%s ret=%s cash=%s"):format(
                entry.name, attempt, cost, tostring(ok), tostring(ret), tostring(Cash())))
            if ok and ret ~= false then return true end
            task.wait(CONFIG.PlaceRetryEvery)
        end
    end
    return false
end

local function PlaceAllParallel()
    local results = {}
    local pending = #SCHEDULE

    for _, entry in ipairs(SCHEDULE) do
        task.spawn(function()
            local ok, success = pcall(PlaceOne, entry)
            results[entry] = (ok and success) and true or false
            pending = pending - 1
        end)
    end

    while pending > 0 and State.running do
        local minWait, minName = math.huge, ""
        for _, entry in ipairs(SCHEDULE) do
            if results[entry] == nil then
                local left = entry.t - Elapsed()
                if left < minWait then minWait = left; minName = entry.name end
            end
        end
        if minWait == math.huge then break end
        if minWait > 0 then
            SetPhase("place", "жду " .. minName, os.clock() + minWait, minName)
            task.wait(math.min(minWait, 0.5))
        else
            SetPhase("place", "ставлю...")
            task.wait(0.5)
        end
    end

    local okCount, failCount, unfinished = 0, 0, 0
    for _, entry in ipairs(SCHEDULE) do
        local v = results[entry]
        if v == true then okCount = okCount + 1
        elseif v == false then failCount = failCount + 1
        else unfinished = unfinished + 1 end
    end
    local interrupted = (not State.running) and " (прервано)" or ""
    SetPhase("place", ("ok=%d fail=%d unfinished=%d%s"):format(okCount, failCount, unfinished, interrupted))
    print(("[AFK] расстановка: ok=%d fail=%d unfinished=%d%s"):format(okCount, failCount, unfinished, interrupted))
    return okCount
end

-- ============================================================
-- UPGRADE
-- ============================================================
local function EscapePattern(s)
    return (s:gsub("(%p)", "%%%1"))
end

local function TowersBySuffix(suffix)
    local folder = workspace:FindFirstChild("Towers")
    if not folder then return {} end
    local out = {}
    local esc = EscapePattern(suffix)
    for _, obj in ipairs(folder:GetChildren()) do
        local n = obj.Name
        if n == suffix
           or n:sub(-#suffix) == suffix
           or n:find("[_%-]" .. esc .. "$") then
            table.insert(out, obj)
        end
    end
    return out
end

local function WaitForAnyTower()
    local groups = { "Jerry", "Buff Turkey", "President", "Space Cruiser" }
    local start = os.clock()
    while os.clock() - start < CONFIG.TowerWaitTimeout and State.running do
        if not workspace:FindFirstChild("Towers") then
            State.error = "папка workspace.Towers не найдена"
            task.wait(CONFIG.TowerWaitPoll)
        else
            for _, suffix in ipairs(groups) do
                if #TowersBySuffix(suffix) > 0 then return true end
            end
            SetPhase("upgrade", "жду появления башен...")
            task.wait(CONFIG.TowerWaitPoll)
        end
    end
    return false
end

-- Определяем базовое имя юнита из имени объекта
local function BaseUnitName(towerName)
    for _, suffix in ipairs({ "Space Cruiser", "Buff Turkey", "President", "Jerry" }) do
        if towerName:sub(-#suffix) == suffix then return suffix end
    end
    return towerName
end

local function UpgradeOne(tower)
    local r = Remote("UpgradeTower")
    if not r then return 0 end
    local levels, fails = 0, 0
    local baseName = BaseUnitName(tower.Name)

    while levels < 60 and fails < CONFIG.UpgradeFailsMax and State.running do
        if not tower or not tower.Parent then break end

        local currentLevel = levels + 1
        local need = NextUpgradeCost(baseName, currentLevel)

        if need then
            local c = Cash()
            if c and c < need then
                SetPhase("upgrade", ("%s ур.%d: жду %d (есть %s)"):format(
                    tower.Name, currentLevel + 1, need, tostring(c)))
                local start = os.clock()
                local okWait = false
                while State.running do
                    local c2 = Cash()
                    if c2 and c2 >= need then okWait = true; break end
                    if os.clock() - start > CONFIG.UpgradeCashWait then break end
                    task.wait(CONFIG.CashPoll)
                end
                if not okWait then
                    print(("[AFK] %s: не дождался %d за %d сек"):format(
                        tower.Name, need, CONFIG.UpgradeCashWait))
                    return levels
                end
            end
        else
            SetPhase("upgrade", ("%s ур.%d (цена неизвестна, пробую)"):format(
                tower.Name, currentLevel + 1))
        end

        local ok, ret = pcall(function() return r:InvokeServer(tower) end)
        if not ok then break end
        if ret == false or ret == nil then
            fails = fails + 1; task.wait(2)
        else
            levels = levels + 1; fails = 0
            print(("[AFK] %s → ур.%d (cash=%s)"):format(tower.Name, levels + 1, tostring(Cash())))
        end
        task.wait(CONFIG.UpgradeDelay)
    end
    return levels
end

local function UpgradeAll()
    if not WaitForAnyTower() then
        if State.error == "" then
            State.error = "башни не появились в Towers за " .. CONFIG.TowerWaitTimeout .. " сек"
        end
        return
    end
    local total = 0
    local report = {}
    for _, suffix in ipairs({ "Jerry", "Buff Turkey", "President", "Space Cruiser" }) do
        local list = TowersBySuffix(suffix)
        table.insert(report, ("%s x%d"):format(suffix, #list))
        for _, t in ipairs(list) do
            if not State.running then return end
            SetPhase("upgrade", ("апгрейд %s"):format(t.Name))
            local ok, lv = pcall(UpgradeOne, t)
            if ok and type(lv) == "number" then total = total + lv
            else print(("[AFK] апгрейд %s упал: %s"):format(t.Name, tostring(lv))) end
        end
    end
    SetPhase("upgrade", ("найдено: %s | +%d"):format(table.concat(report, ", "), total))
end

-- ============================================================
-- AUTO-CLICK
-- ============================================================
local CachedButton = nil

local function FindStartButton()
    if CachedButton and CachedButton.Parent and CachedButton.Visible then
        return CachedButton
    end
    CachedButton = nil
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, obj in ipairs(gui:GetDescendants()) do
                if obj:IsA("TextButton") and obj.Visible then
                    local txt = obj.Text:lower()
                    local excluded = false
                    for _, ex in ipairs(CONFIG.ExcludeTexts) do
                        if txt:find(ex) then excluded = true; break end
                    end
                    if not excluded then
                        for _, key in ipairs(CONFIG.StartTexts) do
                            if txt:find(key) then CachedButton = obj; return obj end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function Click(btn)
    if not btn or not btn.Parent or not btn.Visible then return end
    pcall(function()
        if btn.Activate then btn:Activate()
        else
            local p = btn.AbsolutePosition + btn.AbsoluteSize / 2
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(p); VirtualUser:Button1Up(p)
        end
    end)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local FarmThread = nil

local function Loop()
    State.error = ""

    local schedOk, schedErr = ValidateSchedule()
    if not schedOk then
        State.error = "SCHEDULE: " .. schedErr
        State.running = false
        return
    end

    local ok, err = WaitForRemotes(CONFIG.RemotesWait)
    if not ok then
        State.error = err
        State.running = false
        return
    end

    task.wait(CONFIG.MatchStartDelay)
    if not State.running then return end

    SetPhase("vote", "голосование")
    Vote()
    task.wait(2)
    if not State.running then return end

    PlaceAllParallel()
    if not State.running then return end

    UpgradeAll()
    if not State.running then return end

    local misses = 0
    while State.running do
        SetPhase("click", "клик старта")
        local btn = FindStartButton()
        if btn then
            Click(btn)
            misses = 0
        else
            misses = misses + 1
            SetPhase("click", ("клик старта (промахов %d/%d)"):format(misses, CONFIG.ClickMissLimit))
            if misses >= CONFIG.ClickMissLimit then
                State.running = false
                State.error = "матч закончился: кнопка старта не найдена " .. misses .. " раз"
                print("[AFK] " .. State.error)
                break
            end
        end
        task.wait(CONFIG.ClickInterval)
    end

    FarmThread = nil
end

local function Start()
    if State.running then return end
    State.running = true; State.error = ""
    MatchStart = os.clock()
    CashStat = FindCash()
    print("[AFK] cash: " .. tostring(CashStat and CashStat.Value))
    FarmThread = task.spawn(Loop)
end

local function Stop()
    State.running = false
    if FarmThread then pcall(task.cancel, FarmThread); FarmThread = nil end
    CachedButton = nil
    State.timerEnd = nil; State.timerName = ""
    SetPhase("idle", "ВЫКЛ")
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
    frame.Size = UDim2.new(0, 300, 0, 220); frame.Position = UDim2.new(0, 20, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 18); frame.BorderSizePixel = 0
    frame.Active = true; frame.Draggable = true; frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(0, 200, 100); stroke.Thickness = 1; stroke.Transparency = 0.4

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -16, 0, 26); title.Position = UDim2.new(0, 10, 0, 6)
    title.BackgroundTransparency = 1; title.Text = "PTD AFK FARM v13"
    title.TextColor3 = Color3.fromRGB(0, 220, 110); title.Font = Enum.Font.GothamBold
    title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(1, -32, 0, 36); btn.Position = UDim2.new(0, 16, 0, 36)
    btn.BorderSizePixel = 0; btn.Text = "▶  ЗАПУСТИТЬ"; btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 14; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local timer = Instance.new("TextLabel", frame)
    timer.Size = UDim2.new(1, -32, 0, 32); timer.Position = UDim2.new(0, 16, 0, 78)
    timer.BackgroundTransparency = 1; timer.Text = "--"
    timer.TextColor3 = Color3.fromRGB(255, 200, 80); timer.Font = Enum.Font.GothamBold
    timer.TextSize = 20; timer.TextXAlignment = Enum.TextXAlignment.Left

    local detail = Instance.new("TextLabel", frame)
    detail.Size = UDim2.new(1, -32, 0, 18); detail.Position = UDim2.new(0, 16, 0, 112)
    detail.Backgr