-- language: Lua
-- target: Roblox client (Portal Tower Defense)
-- AFK farm — vote + place (Jerry first) + upgrade-to-max + auto-click start wave
-- manual rejoin: He restarts the script in each new match

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

local PLACEMENTS = {
    { name = "Jerry",        pos = Vector3.new(115.77935791015625, 7.954591751098633, -46.52529525756836), rot = 0 },
    { name = "Jerry",        pos = Vector3.new(113.5140380859375,  7.933708190917969, -49.838958740234375), rot = 0 },
    { name = "President",    pos = Vector3.new(109.55278778076172, 7.922641754150391, -46.534759521484375), rot = 0 },
    { name = "President",    pos = Vector3.new(109.61953735351562, 7.935300827026367, -50.340065002441406), rot = 0 },
    { name = "Buff Turkey",  pos = Vector3.new(105.41456604003906, 7.935329437255859, -50.34072494506836), rot = 0 },
    { name = "Space Cruiser", pos = Vector3.new(131.7823028564453, 8.261308670043945, -51.3819694519043), rot = 0 },
}

-- ============================================================
-- VOTE
-- ============================================================
local function VoteDifficulty(diff)
    local ok, err = pcall(function()
        return DifficultyVote:FireServer(diff)
    end)
    if not ok then warn("[AFK] DifficultyVote: " .. tostring(err)) end
end

-- ============================================================
-- PLACE
-- ============================================================
local function PlaceAll()
    local placed = 0
    for _, e in ipairs(PLACEMENTS) do
        local ok, err = pcall(function()
            return PlaceTower:InvokeServer(e.name, e.pos, e.rot or 0)
        end)
        if ok then placed = placed + 1
        else warn(("[AFK] PlaceTower %s: %s"):format(e.name, tostring(err))) end
        task.wait(CONFIG.PlaceDelay)
    end
    print(("[AFK] Расставлено: %d/%d"):format(placed, #PLACEMENTS))
end

-- ============================================================
-- UPGRADE
-- ============================================================
local function FindTowersBySuffix(suffix)
    local out = {}
    for _, obj in ipairs(TowersFolder:GetChildren()) do
        if obj.Name:sub(-#suffix) == suffix then
            table.insert(out, obj)
        end
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
    local names = { "Jerry", "President", "Buff Turkey", "Space Cruiser" }
    for _, suffix in ipairs(names) do
        for _, t in ipairs(FindTowersBySuffix(suffix)) do
            local ok, reason = UpgradeOne(t)
            if not ok then
                print(("[AFK] %s стоп: %s"):format(t.Name, reason))
            else
                print(("[AFK] %s прокачан"):format(t.Name))
            end
        end
    end
end

-- ============================================================
-- AUTO-CLICK START WAVE
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
                elseif obj:IsA("ImageButton") then
                    local nm = obj.Name:lower()
                    for _, key in ipairs(CONFIG.StartTexts) do
                        if nm:find(key) then return obj end
                    end
                end
            end
        end
    end
    return nil
end

local function ClickButton(btn)
    local ok, err = pcall(function()
        if btn.Activate then
            btn:Activate()
        else
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            VirtualUser:CaptureController()
            VirtualUser:Button1Down(pos)
            VirtualUser:Button1Up(pos)
        end
    end)
    if not ok then warn("[AFK] ClickButton: " .. tostring(err)) end
end

local AutoClickRunning = true

local function StartAutoClick()
    task.spawn(function()
        while AutoClickRunning do
            local btn = FindStartButton()
            if btn and btn.Visible then
                ClickButton(btn)
                print("[AFK] Клик по кнопке старта: " .. btn.Name)
            end
            task.wait(CONFIG.ClickInterval)
        end
    end)
end

-- ============================================================
-- BOOT
-- ============================================================
VoteDifficulty(CONFIG.Difficulty)
task.wait(1)
PlaceAll()
task.wait(1)
UpgradeAll()
StartAutoClick()
print("[AFK] Полный цикл запущен. Перезапусти скрипт в новой катке после победы.")