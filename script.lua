-- language: Lua
-- target: Roblox client (Portal Tower Defense)
-- AFK farm with retry logic — placement, upgrade, start-button

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
    PlaceRetries    = 5,      -- сколько раз пробовать поставить одну башню
    UpgradeDelay    = 0.15,
    UpgradeMaxTries = 50,     -- максимум вызовов апгрейда на башню
    UpgradeRetries  = 3,      -- сколько раз перезапускать апгрейд, если сервер отклонил
    ClickInterval   = 5,
    ClickRetries    = 10,     -- сколько циклов искать кнопку старта, прежде чем сдаться
    StartTexts      = { "start", "начать", "wave", "волна", "next", "далее", "play", "играть" },
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
-- RETRY HELPERS
-- ============================================================
-- Общий ретрай: fn() -> true/false, err. Повторяет до tries раз с паузой.
local function Retry(fn, tries, delay, label)
    for i = 1, tries do
        local ok, result, err = pcall(fn)
        if ok and result then
            return true
        end
        local reason = (not ok) and tostring(result) or tostring(err or "rejected")
        warn(("[AFK] %s попытка %d/%d: %s"):format(label or "retry", i, tries, reason))
        if i < tries then task.wait(delay) end
    end
    return false
end

-- ============================================================
-- VOTE
-- ============================================================
local function VoteDifficulty(diff)
    Retry(function()
        DifficultyVote:FireServer(diff)
        return true
    end, 3, 0.5, "vote")
end

-- ============================================================
-- PLACE с ретраями
-- ============================================================
local function PlaceOne(entry)
    return Retry(function()
        -- RemoteFunction возвращает что-то; считаем успехом, если не упало
        PlaceTower:InvokeServer(entry.name, entry.pos, entry.rot or 0)
        return true
    end, CONFIG.PlaceRetries, CONFIG.PlaceDelay, "place " .. entry.name)
end

local function PlaceAll()
    local placed = 0
    for _, e in ipairs(PLACEMENTS) do
        if PlaceOne(e) then
            placed = placed + 1
        else
            warn(("[AFK] Не удалось поставить %s после %d попыток"):format(e.name, CONFIG.PlaceRetries))
        end
        task.wait(CONFIG.PlaceDelay)
    end
    print(("[AFK] Расставлено: %d/%d"):format(placed, #PLACEMENTS))
end

-- ============================================================
-- UPGRADE с ретраями
-- ============================================================
local function FindTowersBySuffix(suffix)
    local out = {}
    for _, obj in ipairs(TowersFolder:GetChildren()) do
        if obj.Name:sub(-#suffix) == suffix then table.insert(out, obj) end
    end
    return out
end

-- Один проход апгрейда: долбит до максимума или до отказа
local function UpgradePass(tower)
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

-- Апгрейд с ретраями: если проход упал — пробуем ещё раз
local function UpgradeOne(tower)
    for i = 1, CONFIG.UpgradeRetries do
        local ok, reason = UpgradePass(tower)
        if ok then return true end
        warn(("[AFK] upgrade %s попытка %d/%d: %s"):format(tower.Name, i, CONFIG.UpgradeRetries, reason))
        task.wait(0.5)
    end
    return false
end

local function UpgradeAll()
    for _, suffix in ipairs({ "Jerry", "Buff Turkey", "President", "Space Cruiser" }) do
        for _, t in ipairs(FindTowersBySuffix(suffix)) do
            local ok = UpgradeOne(t)
            print(("[AFK] %s: %s"):format(t.Name, ok and "ok" or "не прокачан"))
        end
    end
end

-- ============================================================
-- AUTO-CLICK с ретраями
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

        -- авто-клик с ретраем поиска кнопки
        local misses = 0
        while FarmRunning do
            local btn = FindStartButton()
            if btn and btn.Visible then
                ClickButton(btn)
                misses = 0
            else
                misses = misses + 1
                if misses == CONFIG.ClickRetries then
                    warn(("[AFK] Кнопка старта не найдена после %d попыток — проверь UI через Dex"):format(misses))
                end
            end
            task.wait(CONFIG.ClickInterval)
        end
    end
end

local function StartFarm()
    if FarmRunning then return end
    FarmRunning = true
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
print("[AFK] Меню готово. ВКЛ / ВЫКЛ.")