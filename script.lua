-- language: Lua
-- target: Roblox client (Portal Tower Defense) — compact AFK farm v4
-- randomized delays to reduce pattern detection, no autostart

local P  = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local VU = game:GetService("VirtualUser")
local LP = P.LocalPlayer
local PG = LP:WaitForChild("PlayerGui", 30)
if not PG then return warn("[AFK] no PlayerGui") end

local DIFF    = "Nightmare"
local REMOTES = { "PlaceTower", "UpgradeTower", "DifficultyVote" }
local COST    = { Jerry=250, ["Buff Turkey"]=800, President=1600, ["Space Cruiser"]=2200 }
local UPG     = { Jerry={450,1100,2400,4800} }
local TARGET_LV = 5
local ST_TX   = { "start","начать","wave","волна" }
local EX_TX   = { "again","replay","level","lvl","уровень","exit","выход","leave","покинуть","заново" }

local SCHED = {
  {t=0,   n="Jerry",        p=Vector3.new(115.779,7.955,-46.525)},
  {t=0,   n="Jerry",        p=Vector3.new(113.514,7.934,-49.839)},
  {t=15,  n="Buff Turkey",  p=Vector3.new(105.415,7.935,-50.341)},
  {t=45,  n="President",    p=Vector3.new(109.553,7.923,-46.535)},
  {t=75,  n="President",    p=Vector3.new(109.620,7.935,-50.340)},
  {t=105, n="Space Cruiser",p=Vector3.new(131.782,8.261,-51.382)},
}

local running, matchStart, farmThread, cachedBtn, cashStat
local startFarm, stopFarm
local st = {phase="idle", detail="", tEnd=0, tName="", err=""}

local function el() return os.clock() - matchStart end
local function rnd(a, b) return a + math.random() * (b - a) end

local function findCash()
  local ls = LP:FindFirstChild("leaderstats"); if not ls then return nil end
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
  local f = RS:FindFirstChild("Remotes"); if not f then return nil end
  local r = f:FindFirstChild(name)
  if r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return r end
end

local gui, btn, tLbl, dLbl, cLbl, pLbl, eLbl
local function buildGui()
  local old = PG:FindFirstChild("PTD_AFK"); if old then old:Destroy() end
  gui = Instance.new("ScreenGui"); gui.Name="PTD_AFK"; gui.ResetOnSpawn=false; gui.Parent=PG
  local f = Instance.new("Frame"); f.Size=UDim2.new(0,260,0,190); f.Position=UDim2.new(0,20,0,20)
  f.BackgroundColor3=Color3.fromRGB(14,14,18); f.BorderSizePixel=0; f.Active=true; f.Draggable=true; f.Parent=gui
  Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
  local tl = Instance.new("TextLabel"); tl.Size=UDim2.new(1,-16,0,22); tl.Position=UDim2.new(0,8,0,4)
  tl.BackgroundTransparency=1; tl.Text="PTD AFK v4"; tl.TextColor3=Color3.fromRGB(0,220,110)
  tl.Font=Enum.Font.GothamBold; tl.TextSize=13; tl.TextXAlignment=Enum.TextXAlignment.Left; tl.Parent=f
  btn = Instance.new("TextButton"); btn.Size=UDim2.new(1,-32,0,30); btn.Position=UDim2.new(0,16,0,30)
  btn.BorderSizePixel=0; btn.Text="START"; btn.TextColor3=Color3.new(1,1,1); btn.Font=Enum.Font.GothamBold
  btn.TextSize=12; btn.AutoButtonColor=false; btn.Parent=f; Instance.new("UICorner",btn).CornerRadius=UDim.new(0,5)
  tLbl = Instance.new("TextLabel"); tLbl.Size=UDim2.new(1,-32,0,26); tLbl.Position=UDim2.new(0,16,0,66)
  tLbl.BackgroundTransparency=1; tLbl.Text="--"; tLbl.TextColor3=Color3.fromRGB(255,200,80)
  tLbl.Font=Enum.Font.GothamBold; tLbl.TextSize=16; tLbl.TextXAlignment=Enum.TextXAlignment.Left; tLbl.Parent=f
  dLbl = Instance.new("TextLabel"); dLbl.Size=UDim2.new(1,-32,0,14); dLbl.Position=UDim2.new(0,16,0,94)
  dLbl.BackgroundTransparency=1; dLbl.Text="idle"; dLbl.TextColor3=Color3.fromRGB(180,180,180)
  dLbl.Font=Enum.Font.Gotham; dLbl.TextSize=10; dLbl.TextXAlignment=Enum.TextXAlignment.Left; dLbl.Parent=f
  cLbl = Instance.new("TextLabel"); cLbl.Size=UDim2.new(1,-32,0,14); cLbl.Position=UDim2.new(0,16,0,110)
  cLbl.BackgroundTransparency=1; cLbl.Text="cash: --"; cLbl.TextColor3=Color3.fromRGB(110,190,255)
  cLbl.Font=Enum.Font.Gotham; cLbl.TextSize=10; cLbl.TextXAlignment=Enum.TextXAlignment.Left; cLbl.Parent=f
  pLbl = Instance.new("TextLabel"); pLbl.Size=UDim2.new(1,-32,0,12); pLbl.Position=UDim2.new(0,16,0,126)
  pLbl.BackgroundTransparency=1; pLbl.Text=""; pLbl.TextColor3=Color3.fromRGB(100,100,100)
  pLbl.Font=Enum.Font.Gotham; pLbl.TextSize=9; pLbl.TextXAlignment=Enum.TextXAlignment.Left; pLbl.Parent=f
  eLbl = Instance.new("TextLabel"); eLbl.Size=UDim2.new(1,-32,0,36); eLbl.Position=UDim2.new(0,16,0,142)
  eLbl.BackgroundTransparency=1; eLbl.Text=""; eLbl.TextColor3=Color3.fromRGB(220,80,80)
  eLbl.Font=Enum.Font.Gotham; eLbl.TextSize=9; eLbl.TextWrapped=true
  eLbl.TextXAlignment=Enum.TextXAlignment.Left; eLbl.Parent=f
  btn.MouseButton1Click:Connect(function()
    if running then stopFarm() else startFarm() end
  end)
  task.spawn(function()
    while gui.Parent do
      if st.tEnd > 0 then
        local left = st.tEnd - os.clock()
        tLbl.Text = (left > 0) and string.format("%.1fs → %s", left, st.tName) or ("0s → "..st.tName)
      else tLbl.Text = "--" end
      dLbl.Text = st.detail ~= "" and st.detail or "idle"
      pLbl.Text = st.phase ~= "idle" and ("["..st.phase.."]") or ""
      cLbl.Text = "cash: "..tostring(cash() or "--")
      eLbl.Text = st.err
      btn.Text = running and "STOP" or "START"
      btn.BackgroundColor3 = running and Color3.fromRGB(160,45,45) or Color3.fromRGB(0,140,70)
      task.wait(0.15)
    end
  end)
end

local function waitCash(need, label)
  while running do
    local c = cash()
    if c and c >= need then return true end
    st.detail = ("wait %d (have %s) %s"):format(need, tostring(c or "?"), label or "")
    task.wait(rnd(0.5, 0.9))
  end
end

local function placeOne(e)
  local w = e.t - el()
  if w > 0 then st.tEnd = os.clock()+w; st.tName = e.n; task.wait(w) end
  if not running then return false end
  local cost = COST[e.n] or 0
  if not waitCash(cost, e.n) then return false end
  local r = remote("PlaceTower"); if not r then st.err="no PlaceTower"; return false end
  while running do
    local c = cash()
    if c and c < cost and not waitCash(cost, e.n) then return false end
    local ok, ret = pcall(r.InvokeServer, r, e.n, e.p, 0)
    print(("[DBG] %s cost=%d ok=%s ret=%s cash=%s"):format(e.n,cost,tostring(ok),tostring(ret),tostring(cash())))
    if ok and ret ~= false then return true end
    -- отказ: пауза, чтобы не выглядеть как спам
    task.wait(rnd(1.5, 2.5))
  end
end

local function placeAll()
  local ok = 0
  for _, e in ipairs(SCHED) do
    if not running then return ok end
    if placeOne(e) then ok = ok + 1 end
  end
  return ok
end

local function esc(s) return (s:gsub("(%p)","%%%1")) end
local function towers(sfx)
  local f = workspace:FindFirstChild("Towers"); if not f then return {} end
  local out, e = {}, esc(sfx)
  for _, o in ipairs(f:GetChildren()) do
    local n = o.Name
    if n == sfx or n:sub(-#sfx) == sfx or n:find("[_%-]"..e.."$") then table.insert(out, o) end
  end
  return out
end
local function baseName(n)
  for _, s in ipairs({"Space Cruiser","Buff Turkey","President","Jerry"}) do
    if n:sub(-#s) == s then return s end
  end
  return n
end

-- ============================================================
-- UPGRADE: общий пул, чёрный список на отказ, до TARGET_LV
-- ============================================================
local function upgradeLoop()
  local r = remote("UpgradeTower"); if not r then return end
  local targets = {}
  for _, s in ipairs({"Jerry","Buff Turkey","President","Space Cruiser"}) do
    for _, t in ipairs(towers(s)) do
      targets[#targets+1] = {tower=t, base=s, lv=1, blockUntil=0}
    end
  end
  local total = 0

  while running do
    local now = os.clock()
    local best, bestNeed = nil, math.huge

    for _, ent in ipairs(targets) do
      if ent.lv < TARGET_LV and ent.tower.Parent and now >= ent.blockUntil then
        local costs = UPG[ent.base]
        local need = costs and costs[ent.lv] or 0
        local c = cash() or 0
        if need == 0 or c >= need then
          if need < bestNeed then best = ent; bestNeed = need end
        end
      end
    end

    if not best then
      local anyLeft = false
      for _, ent in ipairs(targets) do
        if ent.lv < TARGET_LV and ent.tower.Parent then anyLeft = true; break end
      end
      if not anyLeft then break end
      local c = cash() or 0
      local minNeed = math.huge
      for _, ent in ipairs(targets) do
        if ent.lv < TARGET_LV and ent.tower.Parent and now >= ent.blockUntil then
          local costs = UPG[ent.base]
          local need = costs and costs[ent.lv] or 0
          if need < minNeed then minNeed = need end
        end
      end
      st.detail = ("wait for %d (have %d)"):format(minNeed, c)
      task.wait(rnd(0.8, 1.4))
    else
      st.detail = ("upgrade %s to L%d"):format(best.tower.Name, best.lv+1)
      local ok, ret = pcall(r.InvokeServer, r, best.tower)
      if ok and ret ~= false and ret ~= nil then
        best.lv = best.lv + 1
        total = total + 1
        print(("[AFK] %s -> L%d"):format(best.tower.Name, best.lv))
      else
        best.blockUntil = now + 5
        print(("[AFK] %s refused at L%d, skip 5s"):format(best.tower.Name, best.lv+1))
        task.wait(rnd(0.5, 1.0))
      end

      -- человеческая пауза после серии апгрейдов
      if total > 0 and total % 6 == 0 then
        task.wait(rnd(2.0, 4.0))
      else
        task.wait(rnd(0.15, 0.30))
      end
    end
  end

  print(("[AFK] upgrades total +%d"):format(total))
end

local function findBtn()
  if cachedBtn and cachedBtn.Parent and cachedBtn.Visible then return cachedBtn end
  cachedBtn = nil
  for _, g in ipairs(PG:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name ~= "PTD_AFK" then
      for _, o in ipairs(g:GetDescendants()) do
        if o:IsA("TextButton") and o.Visible then
          local txt = o.Text:lower(); local bad = false
          for _, ex in ipairs(EX_TX) do if txt:find(ex) then bad=true; break end end
          if not bad then
            for _, k in ipairs(ST_TX) do
              if txt:find(k) then cachedBtn = o; return o end
            end
          end
        end
      end
    end
  end
end
local function clickB(b)
  if not b or not b.Parent then return end
  pcall(function()
    if b.Activate then b:Activate() end
    local p = b.AbsolutePosition + b.AbsoluteSize/2
    VU:CaptureController(); VU:Button1Down(p); VU:Button1Up(p)
  end)
end

local function loop()
  st.err = ""
  local t0 = os.clock()
  while running and os.clock()-t0 < 30 do
    local miss = {}
    for _, n in ipairs(REMOTES) do if not remote(n) then table.insert(miss,n) end end
    if #miss == 0 then break end
    st.detail = "wait remotes: "..table.concat(miss,","); task.wait(1)
  end
  if not running then return end
  task.wait(rnd(2, 3))
  if not running then return end

  st.phase = "vote"
  local dv = remote("DifficultyVote")
  if dv then pcall(function() dv:FireServer(DIFF) end) end
  task.wait(rnd(1.5, 2.5))
  if not running then return end

  st.phase = "place"
  local placed = placeAll(); print("[AFK] placed "..placed.."/"..#SCHED)
  if not running then return end

  st.phase = "upgrade"
  upgradeLoop()
  if not running then return end

  -- после апгрейда: 5 попыток найти кнопку старта, потом стоп
  st.phase = "click"
  local misses = 0
  while running do
    local b = findBtn()
    if b then clickB(b); misses = 0
    else
      misses = misses + 1
      st.detail = ("no start btn (%d/5)"):format(misses)
      if misses >= 5 then
        st.err = "match ended — жми START в новой катке"
        running = false
        break
      end
    end
    task.wait(rnd(3, 4.5))
  end
end

startFarm = function()
  if running then return end
  running = true; st.err = ""; st.phase = "vote"
  matchStart = os.clock(); cashStat = findCash()
  print("[AFK] start, cash="..tostring(cashStat and cashStat.Value))
  farmThread = task.spawn(loop)
end

stopFarm = function()
  running = false
  if farmThread then pcall(task.cancel, farmThread); farmThread = nil end
  cachedBtn = nil
  st.phase, st.detail, st.tEnd, st.tName = "idle", "stopped", 0, ""
end

-- ТОЛЬКО МЕНЮ, НИКАКОГО АВТОСТАРТА
local ok, err = pcall(buildGui)
if ok then print("[AFK] ready. Жми START вручную.") else warn("[AFK] GUI fail: "..tostring(err)) end