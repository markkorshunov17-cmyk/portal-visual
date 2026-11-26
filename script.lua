-- language: Lua
-- target: Roblox client (Portal Tower Defense) — compact AFK farm

local Players = game:GetService("Players")
local RS      = game:GetService("ReplicatedStorage")
local VU      = game:GetService("VirtualUser")
local LP      = Players.LocalPlayer
local PG      = LP:WaitForChild("PlayerGui", 30)
if not PG then return warn("[AFK] PlayerGui not found") end

-- ============================================================
-- CONFIG
-- ============================================================
local DIFF     = "Nightmare"
local REMOTES  = { "PlaceTower", "UpgradeTower", "DifficultyVote" }
local COST     = { Jerry=250, ["Buff Turkey"]=800, President=1600, ["Space Cruiser"]=2200 }
local UPG      = { Jerry={450,1100,2400,4800} }   -- 1→2, 2→3, 3→4, 4→5
local START_TX = { "start","начать","wave","волна" }
local EXCL_TX  = { "again","replay","level","lvl","уровень","exit","выход","leave","покинуть","заново" }

local SCHED = {
  {t=0,   n="Jerry",        p=Vector3.new(115.779,7.955,-46.525)},
  {t=0,   n="Jerry",        p=Vector3.new(113.514,7.934,-49.839)},
  {t=15,  n="Buff Turkey",  p=Vector3.new(105.415,7.935,-50.341)},
  {t=45,  n="President",    p=Vector3.new(109.553,7.923,-46.535)},
  {t=75,  n="President",    p=Vector3.new(109.620,7.935,-50.340)},
  {t=105, n="Space Cruiser",p=Vector3.new(131.782,8.261,-51.382)},
}

-- ============================================================
-- STATE
-- ============================================================
local running, matchStart, farmThread, cachedBtn, cashStat
local startFarm, stopFarm   -- forward decl
local st = {phase="idle", detail="", tEnd=0, tName="", err=""}
local function elapsed() return os.clock() - matchStart end

-- ============================================================
-- CASH / REMOTES
-- ============================================================
local function findCash()
  local ls = LP:FindFirstChild("leaderstats")
  if not ls then return nil end
  for _, n in ipairs({"cash","Cash","money","Money","coins","Coins"}) do
    local s = ls:FindFirstChild(n)
    if s and (s:IsA("IntValue") or s:IsA("NumberValue")) then return s end
  end
end
local function cash()
  if not cashStat or not cashStat.Parent then cashStat = findCash() end
  return cashStat and cashStat.Value or nil
end
local function remote(name)
  local f = RS:FindFirstChild("Remotes")
  if not f then return nil end
  local r = f:FindFirstChild(name)
  if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
end

-- ============================================================
-- GUI
-- ============================================================
local gui, btn, timerLbl, detailLbl, cashLbl, phaseLbl, errLbl
local function buildGui()
  local old = PG:FindFirstChild("PTD_AFK")
  if old then old:Destroy() end
  gui = Instance.new("ScreenGui")
  gui.Name = "PTD_AFK"; gui.ResetOnSpawn = false; gui.Parent = PG

  local f = Instance.new("Frame")
  f.Size = UDim2.new(0,280,0,200); f.Position = UDim2.new(0,20,0,20)
  f.BackgroundColor3 = Color3.fromRGB(14,14,18); f.BorderSizePixel = 0
  f.Active = true; f.Draggable = true; f.Parent = gui
  Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)

  local title = Instance.new("TextLabel")
  title.Size = UDim2.new(1,-16,0,24); title.Position = UDim2.new(0,8,0,4)
  title.BackgroundTransparency = 1; title.Text = "PTD AFK"
  title.TextColor3 = Color3.fromRGB(0,220,110); title.Font = Enum.Font.GothamBold
  title.TextSize = 14; title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = f

  btn = Instance.new("TextButton")
  btn.Size = UDim2.new(1,-32,0,32); btn.Position = UDim2.new(0,16,0,32)
  btn.BorderSizePixel = 0; btn.Text = "START"; btn.TextColor3 = Color3.new(1,1,1)
  btn.Font = Enum.Font.GothamBold; btn.TextSize = 13; btn.AutoButtonColor = false; btn.Parent = f
  Instance.new("UICorner", btn).CornerRadius = UDim.new(0,5)

  timerLbl = Instance.new("TextLabel")
  timerLbl.Size = UDim2.new(1,-32,0,28); timerLbl.Position = UDim2.new(0,16,0,70)
  timerLbl.BackgroundTransparency = 1; timerLbl.Text = "--"
  timerLbl.TextColor3 = Color3.fromRGB(255,200,80); timerLbl.Font = Enum.Font.GothamBold
  timerLbl.TextSize = 18; timerLbl.TextXAlignment = Enum.TextXAlignment.Left; timerLbl.Parent = f

  detailLbl = Instance.new("TextLabel")
  detailLbl.Size = UDim2.new(1,-32,0,16); detailLbl.Position = UDim2.new(0,16,0,100)
  detailLbl.BackgroundTransparency = 1; detailLbl.Text = "idle"
  detailLbl.TextColor3 = Color3.fromRGB(180,180,180); detailLbl.Font = Enum.Font.Gotham
  detailLbl.TextSize = 11; detailLbl.TextXAlignment = Enum.TextXAlignment.Left; detailLbl.Parent = f

  cashLbl = Instance.new("TextLabel")
  cashLbl.Size = UDim2.new(1,-32,0,16); cashLbl.Position = UDim2.new(0,16,0,118)
  cashLbl.BackgroundTransparency = 1; cashLbl.Text = "cash: --"
  cashLbl.TextColor3 = Color3.fromRGB(110,190,255); cashLbl.Font = Enum.Font.Gotham
  cashLbl.TextSize = 11; cashLbl.TextXAlignment = Enum.TextXAlignment.Left; cashLbl.Parent = f

  phaseLbl = Instance.new("TextLabel")
  phaseLbl.Size = UDim2.new(1,-32,0,14); phaseLbl.Position = UDim2.new(0,16,0,136)
  phaseLbl.BackgroundTransparency = 1; phaseLbl.Text = ""
  phaseLbl.TextColor3 = Color3.fromRGB(100,100,100); phaseLbl.Font = Enum.Font.Gotham
  phaseLbl.TextSize = 10; phaseLbl.TextXAlignment = Enum.TextXAlignment.Left; phaseLbl.Parent = f

  errLbl = Instance.new("TextLabel")
  errLbl.Size = UDim2.new(1,-32,0,40); errLbl.Position = UDim2.new(0,16,0,152)
  errLbl.BackgroundTransparency = 1; errLbl.Text = ""
  errLbl.TextColor3 = Color3.fromRGB(220,80,80); errLbl.Font = Enum.Font.Gotham
  errLbl.TextSize = 10; errLbl.TextWrapped = true; errLbl.TextXAlignment = Enum.TextXAlignment.Left
  errLbl.Parent = f

  btn.MouseButton1Click:Connect(function()
    if running then stopFarm() else startFarm() end
  end)

  task.spawn(function()
    while gui.Parent do
      local now = os.clock()
      if st.tEnd > 0 then
        local left = st.tEnd - now
        timerLbl.Text = (left > 0) and string.format("%.1fs → %s", left, st.tName) or ("0s → "..st.tName)
      else
        timerLbl.Text = "--"
      end
      detailLbl.Text = st.detail ~= "" and st.detail or "idle"
      phaseLbl.Text = st.phase ~= "idle" and ("["..st.phase.."]") or ""
      cashLbl.Text  = "cash: " .. tostring(cash() or "--")
      errLbl.Text   = st.err
      if running then
        btn.Text = "STOP"; btn.BackgroundColor3 = Color3.fromRGB(160,45,45)
      else
        btn.Text = "START"; btn.BackgroundColor3 = Color3.fromRGB(0,140,70)
      end
      task.wait(0.15)
    end
  end)
end

-- ============================================================
-- PLACE / UPGRADE / CLICK
-- ============================================================
local function waitCash(need, label)
  while running do
    local c = cash()
    if c and c >= need then return true end
    st.detail = ("wait %d (have %s) %s"):format(need, tostring(c or "?"), label or "")
    task.wait(0.5)
  end
  return false
end

local function placeOne(entry)
  local wait = entry.t - elapsed()
  if wait > 0 then
    st.tEnd = os.clock() + wait; st.tName = entry.n
    task.wait(wait)
  end
  if not running then return false end
  local cost = COST[entry.n] or 0
  if not waitCash(cost, entry.n) then return false end
  local r = remote("PlaceTower")
  if not r then st.err = "no PlaceTower"; return false end
  while running do
    local c = cash()
    if c and c < cost then
      if not waitCash(cost, entry.n) then return false end
    end
    local ok, ret = pcall(r.InvokeServer, r, entry.n, entry.p, 0)
    print(("[DBG] place %s cost=%d ok=%s ret=%s cash=%s"):format(
      entry.n, cost, tostring(ok), tostring(ret), tostring(cash())))
    if ok and ret ~= false then return true end
    task.wait(0.5)
  end
end

local function placeAll()
  local ok = 0
  for _, entry in ipairs(SCHED) do
    if not running then return ok end
    if placeOne(entry) then ok = ok + 1 end
  end
  return ok
end

local function esc(s) return (s:gsub("(%p)","%%%1")) end
local function towersBySuffix(sfx)
  local f = workspace:FindFirstChild("Towers")
  if not f then return {} end
  local out, e = {}, esc(sfx)
  for _, o in ipairs(f:GetChildren()) do
    local n = o.Name
    if n == sfx or n:sub(-#sfx) == sfx or n:find("[_%-]"..e.."$") then
      table.insert(out, o)
    end
  end
  return out
end
local function baseName(n)
  for _, s in ipairs({"Space Cruiser","Buff Turkey","President","Jerry"}) do
    if n:sub(-#s) == s then return s end
  end
  return n
end

local function upgradeOne(tower)
  local r = remote("UpgradeTower")
  if not r then return 0 end
  local lv, fails, base = 0, 0, baseName(tower.Name)
  local costs = UPG[base]
  while lv < 60 and fails < 10 and running do
    if not tower.Parent then break end
    local need = costs and costs[lv]
    if need then
      local c = cash()
      if c and c < need then
        st.detail = ("%s L%d wait %d"):format(tower.Name, lv+2, need)
        local t0, waited = os.clock(), false
        while running and os.clock() - t0 < 60 do
          if cash() and cash() >= need then waited = true; break end
          task.wait(0.5)
        end
        if not waited then print("[AFK] "..tower.Name.." gave up on "..need); return lv end
      end
    end
    local ok, ret = pcall(r.InvokeServer, r, tower)
    if not ok then break end
    if ret == false or ret == nil then fails = fails + 1; task.wait(1.5)
    else lv = lv + 1; fails = 0; print(("[AFK] %s -> L%d"):format(tower.Name, lv+1)) end
    task.wait(0.15)
  end
  return lv
end

local function upgradeAll()
  local total = 0
  for _, s in ipairs({"Jerry","Buff Turkey","President","Space Cruiser"}) do
    for _, t in ipairs(towersBySuffix(s)) do
      if not running then return total end
      total = total + upgradeOne(t)
    end
  end
  return total
end

local function findStartBtn()
  if cachedBtn and cachedBtn.Parent and cachedBtn.Visible then return cachedBtn end
  cachedBtn = nil
  for _, g in ipairs(PG:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name ~= "PTD_AFK" then
      for _, obj in ipairs(g:GetDescendants()) do
        if obj:IsA("TextButton") and obj.Visible then
          local txt = obj.Text:lower()
          local bad = false
          for _, ex in ipairs(EXCL_TX) do if txt:find(ex) then bad = true; break end end
          if not bad then
            for _, k in ipairs(START_TX) do
              if txt:find(k) then cachedBtn = obj; return obj end
            end
          end
        end
      end
    end
  end
end
local function clickBtn(b)
  if not b or not b.Parent then return end
  pcall(function()
    if b.Activate then b:Activate() end
    local p = b.AbsolutePosition + b.AbsoluteSize/2
    VU:CaptureController(); VU:Button1Down(p); VU:Button1Up(p)
  end)
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local function loop()
  st.err = ""
  -- wait remotes
  local t0 = os.clock()
  while running and os.clock() - t0 < 30 do
    local miss = {}
    for _, n in ipairs(REMOTES) do
      if not remote(n) then table.insert(miss, n) end
    end
    if #miss == 0 then break end
    st.detail = "wait remotes: "..table.concat(miss, ",")
    task.wait(1)
  end
  if not running then return end
  task.wait(2)
  if not running then return end

  st.phase = "vote"
  local dv = remote("DifficultyVote")
  if dv then pcall(function() dv:FireServer(DIFF) end) end
  task.wait(1.5)
  if not running then return end

  st.phase = "place"
  local placed = placeAll()
  print("[AFK] placed "..placed.."/"..#SCHED)
  if not running then return end

  st.phase = "upgrade"
  local ups = upgradeAll()
  print("[AFK] upgraded +"..ups)
  if not running then return end

  st.phase = "click"
  local misses = 0
  while running do
    local b = findStartBtn()
    if b then clickBtn(b); misses = 0
    else
      misses = misses + 1
      st.detail = ("no start btn (%d/15)"):format(misses)
      if misses >= 15 then st.err = "match ended"; running = false; break end
    end
    task.wait(4)
  end
end

startFarm = function()
  if running then return end
  running = true; st.err = ""; st.phase = "vote"
  matchStart = os.clock()
  cashStat = findCash()
  print("[AFK] start, cash="..tostring(cashStat and cashStat.Value))
  farmThread = task.spawn(loop)
end

stopFarm = function()
  running = false
  if farmThread then pcall(task.cancel, farmThread); farmThread = nil end
  cachedBtn = nil
  st.phase, st.detail, st.tEnd, st.tName = "idle", "stopped", 0, ""
end

-- ============================================================
-- BOOT
-- ============================================================
local ok, err = pcall(buildGui)
if ok then print("[AFK] ready. Жми START.") else warn("[AFK] GUI fail: "..tostring(err)) end