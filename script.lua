-- language: Lua
-- target: Roblox client (Portal Tower Defense)
-- AFK farm — ordered placement, balance probe, GUI toggle

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
    PlaceDelay      = 0.3,
    UpgradeDelay    = 0.15,
    UpgradeMaxTries = 50,
    ClickInterval   = 5,
    StartTexts      = { "start", "начать", "wave", "волна", "next", "далее", "play", "играть" },
}

-- ПОРЯДОК: Jerry → Buff Turkey → President x2 → Space Cruiser
local PLACEMENTS = {
    { name = "Jerry",        pos = Vector3.new(115.77935791015625, 7.954591751098633, -46.52529525756836), rot = 0 },
    { name = "Jerry",        pos = Vector3.new(113.5140380859375,  7.933708190917969, -49.838958740234375), rot = 0 },
    { name = "Buff Turkey",  pos = Vector3.new(105.41456604003906, 7.935329437255859, -50.34072494506836), rot = 0 },
    { name = "President",    pos = Vector3.new(109.55278778076172, 7.922641754150391, -46.534759521484375), rot = 0 },
    { name = "President",    pos = Vector3.new(109.61953735351562, 7.935300827026367, -50.340065002441406), rot = 0 },
    { name = "Space Cruiser", pos = Vector3.new(131.7823028564453, 8.261308670043945, -51.3819694519043), rot = 0 },
}

-- ============================================================
-- BALANCE PROBE (универсальный поиск денег)
-- ============================================================
local CachedBalance = nil

local function FindBalance()
    -- 1) leaderstats
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        for _, v in ipairs(ls:GetChildren()) do
            if v:IsA("IntValue") or v:IsA("NumberValue") then
                local n = v.Name:lower()
                if n:find("coin") or n:find("cash") or n:find("money") or n:find("gold") then
                    return v
                end
            end
        end
    end
    -- 2) атрибуты игрока
    for _, attr in ipairs(LocalPlayer:GetAttributes()) do
        local n = attr:lower()
        if n:find("coin") or n:find("cash") or n:find("money") or n:find("gold") then
            return { Attribute = attr }
        end
    end
    -- 3) папка PlayerData / Stats
    for _, container in ipairs({ LocalPlayer, PlayerGui }) do
        for _, obj in ipairs(container:GetDescendants()) do
            if (obj:IsA("IntValue") or obj:IsA("NumberValue")) then
                local n = obj.Name:lower()
                if n:find("coin") or n:find("cash") or n:find("money") or n:find("gold") then
                    return obj
                end
            end
        end
    end
    return nil
end

local function GetBalance()
    if not CachedBalance then return nil end
    local ok, val = pcall(function()
        if type(CachedBalance) == "table" and CachedBalance.Attribute then
            return LocalPlayer:GetAttribute(CachedBalance.Attribute)
        else
            return CachedBalance.Value
        end
    end)
    if ok then return val end
    return nil
end

local function StartBalanceWatch()
    CachedBalance = FindBalance()
    if not CachedBalance then
        warn("[AFK] Баланс не найден — проверка счёта отключена")
        return
    end
    print("[AFK] Баланс найден: " .. tostring(GetBalance()))
    -- слушаем изменения, если это объект
    if type(CachedBalance) ~= "table" then
        pcall(function()
            CachedBalance:GetPropertyChangedSignal("Value"):Connect(function()
                print(("[AFK] Баланс: %s"):format(tostring(CachedBalance.Value)))
            end)
        end)
    end
end

-- ============================================================
-- VOTE + PLACE + UPGRADE (без изменений)
-- ============================================================
local function VoteDifficulty(diff)
    pcall(function() return DifficultyVote:FireServer(diff) end)
end

local function PlaceAll()
    local placed = 0
    for _, e in ipairs(PLACEMENTS) do
        local ok = pcall(function()
            return PlaceTower:InvokeServer(e.name, e.pos, e.rot or 0)
        end)
        if ok then placed = placed + 1 end
        task.wait(CONFIG.PlaceDelay)
    end
    print(("[AFK] Расставлено: %d/%d"):format(placed, #PLACEMENTS))
end

local function FindTowersBySuffix(suffix)
    local out = {}
    for _, obj in ipairs(TowersFolder:GetChildren()) do
        if obj.Name:sub(-#suffix) == suffix then table.insert(out, obj) end
    end
    return out
end

local function UpgradeOne(tower)
    local tries = 0
    while tries < CONFIG.UpgradeMaxTries do
        local ok, ret = pcall(function()
            return UpgradeTower:InvokeServer(tower)
        end)
        if not ok then return false, tostring(ret) end
        if ret == false then return false, "server rejected" end
        tries = tries + 1
        task.wait(CONFIG.UpgradeDelay)
    end
    return true
end

local function UpgradeAll()
    for _, suffix in ipairs({ "Jerry", "Buff Turkey", "President", "Space Cruiser" }) do
        for _, t in ipairs(FindTowersBySuffix(suffix)) do
            local ok, reason = UpgradeOne(t)
            print(("[AFK] %s: %s"):format(t.Name, ok and "ok" or reason))
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
-- FARM LOOP (управляемый кнопкой GUI)
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
        -- авто-клик старта волны
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
    StartBalanceWatch()
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
print("[AFK] Меню готово. Нажми ВКЛ для запуска.")