local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Players    = game:GetService("Players")
local workspace  = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local VirtualUser= game:GetService("VirtualUser")

local player = Players.LocalPlayer
local char   = player.Character or player.CharacterAdded:Wait()
local root   = char:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(c)
    char = c
    root = c:WaitForChild("HumanoidRootPart")
end)

local FRUIT_CYCLE_DELAY    = 5
local PHONE_OFFER_RESPONSE = "Accept"
local POWER_NAMES = { "UpgradeStack", "BuyNext", "Manage", "WalkSpeed", "ClickFruitValue" }

local INCOME_STREAMS = {
    "LemonDash", "LemonDepot", "LemonLabs",
    "LemonTrading", "LemonRepublic", "LemonRobotics",
    "LemonStand", "LemonX",
}

local ENABLED = {
    AutoBuyUpgrades   = false,
    AutoCollectFruit  = false,
    AutoCollectDrops  = false,
    AutoClick         = false,
    AutoPhoneOffer    = false,
    AutoUpgradeStands = false,
    AutoRebirth       = false,
    AutoAscend        = false,
    AutoEvolve        = false,
    AutoPowerUpgrade  = false,
    AutoOfflineCash   = false,
    AutoTimeCash      = false,
    AutoEarnerBoost   = false,
    AutoMinigameRace  = false,
    AutoMinigameTrade = false,
    AutoCashVine      = false,
    AntiAFK           = false,
    BoostFPS          = false,
}

local STATS = {
    upgradesBought = 0,
    fruitCollected = 0,
    dropsCollected = 0,
    clicks         = 0,
    phoneOffers    = 0,
    standsUpgraded = 0,
    rebirths       = 0,
    ascends        = 0,
    evolves        = 0,
    powerUpgrades  = 0,
    racesWon       = 0,
    tradesWon      = 0,
    vineCollected  = 0,
}

local function getMyTycoon()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name:match("^Tycoon%d+$") then
            local owner = obj:FindFirstChild("Owner", true)
            if owner and owner:IsA("ObjectValue") and owner.Value == player then
                return obj
            end
        end
    end
    return nil
end

local myTycoon = nil
task.spawn(function()
    for _ = 1, 20 do
        myTycoon = getMyTycoon()
        if myTycoon then break end
        task.wait(0.5)
    end
end)

local function tycoon()
    if not myTycoon then myTycoon = getMyTycoon() end
    return myTycoon
end

local function rem(name)
    local t = tycoon()
    if not t then return nil end
    local remotes = t:FindFirstChild("Remotes")
    if not remotes then return nil end
    return remotes:FindFirstChild(name)
end

local function getCash()
    local ls = player:FindFirstChild("leaderstats")
    if not ls then return 0 end
    for _, v in ipairs(ls:GetChildren()) do
        if v:IsA("NumberValue") or v:IsA("IntValue") then
            local n = v.Name:lower()
            if n:find("cash") or n:find("money") or n:find("lemon") or n:find("coin") then
                return v.Value
            end
        end
    end
    local best = 0
    for _, v in ipairs(ls:GetChildren()) do
        if (v:IsA("NumberValue") or v:IsA("IntValue")) and v.Value > best then best = v.Value end
    end
    return best
end

local buyLock = {}

local function runAutoUpgrades()
    while not myTycoon do task.wait(0.5) end
    RunService.Heartbeat:Connect(function()
        if not ENABLED.AutoBuyUpgrades then return end
        local t = tycoon()
        if not t then return end
        local purchases = t:FindFirstChild("Purchases")
        if not purchases then return end
        for _, obj in ipairs(purchases:GetDescendants()) do
            if not ENABLED.AutoBuyUpgrades then break end
            if not (obj:IsA("RemoteFunction") and obj.Name == "Purchase") then continue end
            local btn = obj.Parent
            if not btn then continue end
            if buyLock[obj] then continue end
            if btn:GetAttribute("Purchased") == true  then continue end
            if btn:GetAttribute("Enabled")   == false then continue end
            if btn:GetAttribute("Shown")     == false then continue end
            buyLock[obj] = true
            task.spawn(function()
                pcall(function() obj:InvokeServer(false) end)
                STATS.upgradesBought += 1
                task.wait(1)
                buyLock[obj] = nil
            end)
        end
    end)
end

local STAND_NAMES = {
    "LemonDash", "Lemon Depot", "Lemon Labs",
    "Lemon Stand", "Lemon Trading", "Lemon Republic",
    "Lemon Robotics", "LemonX",
}

local cachedStandRFs = {}

local function buildStandRFCache()
    cachedStandRFs = {}
    local t = tycoon()
    if not t then return end
    local purchases = t:FindFirstChild("Purchases")
    if not purchases then return end
    for _, standName in ipairs(STAND_NAMES) do
        local standFolder = purchases:FindFirstChild(standName)
        if not standFolder then continue end
        local standModel = standFolder:FindFirstChild(standName)
        if not standModel then continue end
        for _, obj in ipairs(standModel:GetDescendants()) do
            if obj:IsA("RemoteFunction") and obj.Name == "Upgrade" then
                cachedStandRFs[standName] = obj
                break
            end
        end
    end
end

local function runAutoUpgradeStands()
    while not myTycoon do task.wait(0.5) end
    buildStandRFCache()
    RunService.Heartbeat:Connect(function()
        if not ENABLED.AutoUpgradeStands then return end
        if not next(cachedStandRFs) then buildStandRFCache() return end
        for _, upgradeRF in pairs(cachedStandRFs) do
            task.spawn(function()
                local ok = pcall(function() upgradeRF:InvokeServer(5) end)
                if ok then STATS.standsUpgraded += 1 end
            end)
        end
    end)
end

local function runAutoFruit()
    while true do
        task.wait(FRUIT_CYCLE_DELAY)
        if not ENABLED.AutoCollectFruit then continue end
        local detectors = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "LemonTree" then
                for _, fruit in ipairs(obj:GetDescendants()) do
                    if fruit.Name == "Fruit" then
                        local clickPart = fruit:FindFirstChild("ClickPart")
                        if clickPart then
                            local cd = clickPart:FindFirstChildOfClass("ClickDetector")
                            if cd then table.insert(detectors, { cd = cd, part = clickPart }) end
                        end
                    end
                end
            end
        end
        if #detectors == 0 then continue end
        local saved = root.CFrame
        for _, entry in ipairs(detectors) do
            if not ENABLED.AutoCollectFruit then break end
            if not entry.part or not entry.part.Parent then continue end
            pcall(function() root.CFrame = CFrame.new(entry.part.Position + Vector3.new(0, 3, 0)) end)
            task.wait(0.1)
            local ok = pcall(fireclickdetector, entry.cd)
            if ok then STATS.fruitCollected += 1 end
            task.wait(0.15)
        end
        pcall(function() root.CFrame = saved end)
    end
end

task.spawn(function()
    local core = RS:WaitForChild("Core", 10)
    if not core then return end
    local signal  = core:FindFirstChild("RemoteSignal")
    local request = core:FindFirstChild("RemoteRequest")
    if not signal or not request then return end
    local newDrop    = signal:FindFirstChild("CashDropService.New")
    local redeemDrop = request:FindFirstChild("CashDropService.Redeem")
    if not newDrop or not redeemDrop then return end
    newDrop.OnClientEvent:Connect(function(id)
        if not ENABLED.AutoCollectDrops then return end
        if id == nil then return end
        task.spawn(function()
            local ok = pcall(function() return redeemDrop:InvokeServer(id) end)
            if ok then STATS.dropsCollected += 1 end
        end)
    end)
end)

local function runAutoCashDrops()
    while true do
        task.wait(4)
        if not ENABLED.AutoCollectDrops then continue end
        local dropsFolder = workspace:FindFirstChild("CashDrops")
        if not dropsFolder then continue end
        local parts = {}
        for _, obj in ipairs(dropsFolder:GetDescendants()) do
            if obj:IsA("BasePart") then table.insert(parts, obj) end
        end
        if #parts == 0 then continue end
        local saved = root.CFrame
        for _, part in ipairs(parts) do
            if not ENABLED.AutoCollectDrops then break end
            if not part or not part.Parent then continue end
            pcall(function() root.CFrame = CFrame.new(part.Position + Vector3.new(0, 1, 0)) end)
            STATS.dropsCollected += 1
            task.wait(0.1)
        end
        pcall(function() root.CFrame = saved end)
    end
end

local cachedWakeRF = nil

local function buildWakeRFCache()
    cachedWakeRF = nil
    local r = rem("WakeIncomeStream")
    if r and r:IsA("RemoteFunction") then cachedWakeRF = r end
end

local function runAutoClick()
    while not myTycoon do task.wait(0.5) end
    buildWakeRFCache()
    RunService.Heartbeat:Connect(function()
        if not ENABLED.AutoClick then return end
        if not cachedWakeRF then buildWakeRFCache() return end
        for _, streamName in ipairs(INCOME_STREAMS) do
            local s = streamName
            task.spawn(function()
                pcall(function() cachedWakeRF:InvokeServer(s) end)
                STATS.clicks += 1
            end)
        end
    end)
end

local phoneEvent   = nil
local phoneConn    = nil
local activeOffer  = false
local offerHandled = false

local function respondToOffer()
    if not phoneEvent then return end
    offerHandled = true
    pcall(function() phoneEvent:FireServer(PHONE_OFFER_RESPONSE) end)
    STATS.phoneOffers += 1
end

local function setupPhoneOffer()
    local t = tycoon()
    if not t then return end
    local remotes = t:FindFirstChild("Remotes")
    if not remotes then return end
    local ev = remotes:FindFirstChild("PhoneOffer")
    if not ev then return end
    phoneEvent = ev
    if phoneConn then phoneConn:Disconnect() end
    phoneConn = phoneEvent.OnClientEvent:Connect(function(val)
        if type(val) == "number" then
            activeOffer  = true
            offerHandled = false
            if ENABLED.AutoPhoneOffer then respondToOffer() end
        else
            activeOffer  = false
            offerHandled = false
        end
    end)
end

task.spawn(function()
    while not myTycoon do task.wait(1) end
    setupPhoneOffer()
    while true do
        task.wait(0.5)
        if ENABLED.AutoPhoneOffer and activeOffer and not offerHandled then
            respondToOffer()
        end
    end
end)

local rebirthCooldown = false

local function runAutoRebirth()
    while not myTycoon do task.wait(0.5) end
    RunService.Heartbeat:Connect(function()
        if not ENABLED.AutoRebirth then return end
        if rebirthCooldown then return end
        local r = rem("Rebirth")
        if not r then return end
        task.spawn(function()
            rebirthCooldown = true
            local ok = pcall(function() r:InvokeServer() end)
            if ok then
                STATS.rebirths += 1
                task.wait(5)
                myTycoon = nil
                buyLock  = {}
                for _ = 1, 20 do
                    myTycoon = getMyTycoon()
                    if myTycoon then break end
                    task.wait(0.5)
                end
                buildStandRFCache()
                buildWakeRFCache()
                setupPhoneOffer()
            end
            rebirthCooldown = false
        end)
    end)
end

local function runAutoAscend()
    while true do
        task.wait(8)
        if not ENABLED.AutoAscend then continue end
        local r = rem("Ascend")
        if not r then continue end
        local ok = pcall(function() r:InvokeServer() end)
        if ok then STATS.ascends += 1 end
    end
end

local function runAutoEvolve()
    while true do
        task.wait(8)
        if not ENABLED.AutoEvolve then continue end
        local r = rem("Evolve")
        if not r then continue end
        local ok = pcall(function() r:InvokeServer() end)
        if ok then STATS.evolves += 1 end
    end
end

local function runAutoPowerUpgrade()
    while true do
        task.wait(0.5)
        if not ENABLED.AutoPowerUpgrade then continue end
        local r = rem("UpgradePowerLevel")
        if not r then continue end
        for _, powerName in ipairs(POWER_NAMES) do
            task.spawn(function()
                local ok = pcall(function() r:InvokeServer(powerName) end)
                if ok then STATS.powerUpgrades += 1 end
            end)
        end
    end
end

local function runAutoOfflineCash()
    while true do
        task.wait(20)
        if not ENABLED.AutoOfflineCash then continue end
        local r = rem("DoubleOfflineCash")
        if not r then continue end
        pcall(function() r:InvokeServer() end)
    end
end

local function runAutoTimeCash()
    while true do
        task.wait(10)
        if not ENABLED.AutoTimeCash then continue end
        local r = rem("UseTimeCash")
        if not r then continue end
        pcall(function() r:InvokeServer() end)
    end
end

local function runAutoEarnerBoost()
    while true do
        task.wait(10)
        if not ENABLED.AutoEarnerBoost then continue end
        local r = rem("UseEarnerBoost")
        if not r then continue end
        pcall(function() r:InvokeServer() end)
    end
end

local raceCD = false

local function runAutoMinigameRace()
    while true do
        task.wait(5)
        if not ENABLED.AutoMinigameRace then continue end
        if raceCD then continue end
        local core    = RS:FindFirstChild("Core")
        if not core then continue end
        local request = core:FindFirstChild("RemoteRequest")
        if not request then continue end
        local startRF = request:FindFirstChild("MinigameRaceService.Start")
        local endRF   = request:FindFirstChild("MinigameRaceService.End")
        if not startRF or not endRF then continue end
        raceCD = true
        task.spawn(function()
            local ok, res = pcall(function() return startRF:InvokeServer() end)
            if ok and res then
                task.wait(0.25)
                pcall(function() endRF:InvokeServer(1) end)
                STATS.racesWon += 1
            end
            task.wait(3)
            raceCD = false
        end)
    end
end

local tradeCD = false

local function runAutoMinigameTrade()
    while true do
        task.wait(5)
        if not ENABLED.AutoMinigameTrade then continue end
        if tradeCD then continue end
        local core    = RS:FindFirstChild("Core")
        if not core then continue end
        local request = core:FindFirstChild("RemoteRequest")
        if not request then continue end
        local startRF = request:FindFirstChild("MinigameTradeService.Start")
        local endRF   = request:FindFirstChild("MinigameTradeService.End")
        if not startRF or not endRF then continue end
        tradeCD = true
        task.spawn(function()
            local ok, res = pcall(function() return startRF:InvokeServer() end)
            if ok and res then
                task.wait(0.25)
                pcall(function() endRF:InvokeServer(1) end)
                STATS.tradesWon += 1
            end
            task.wait(3)
            tradeCD = false
        end)
    end
end

local function runAutoCashVine()
    while true do
        task.wait(30)
        if not ENABLED.AutoCashVine then continue end
        local map = workspace:FindFirstChild("Map")
        if not map then continue end
        local sewer = map:FindFirstChild("Sewer")
        if not sewer then continue end
        local cvFolder = sewer:FindFirstChild("CashVine")
        if not cvFolder then continue end
        local cvModel = cvFolder:FindFirstChild("CashVine")
        if not cvModel then continue end
        local useRF = cvModel:FindFirstChild("Use")
        if not useRF or not useRF:IsA("RemoteFunction") then continue end
        local targetPart = cvModel:FindFirstChildOfClass("BasePart") or cvFolder:FindFirstChildOfClass("BasePart")
        local saved = root.CFrame
        if targetPart then
            pcall(function() root.CFrame = CFrame.new(targetPart.Position + Vector3.new(0, 3, 0)) end)
            task.wait(0.2)
        end
        local ok = pcall(function() useRF:InvokeServer() end)
        if ok then STATS.vineCollected += 1 end
        task.wait(0.2)
        pcall(function() root.CFrame = saved end)
    end
end

player.Idled:Connect(function()
    if not ENABLED.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

task.spawn(function()
    while true do
        task.wait(900)
        if not ENABLED.AntiAFK then continue end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end)

local removedObjects = {}
local fpsBoostActive = false

local function enableFPSBoost()
    if fpsBoostActive then return end
    fpsBoostActive = true
    local removeClasses = {
        "Texture", "Decal", "ParticleEmitter", "Trail",
        "Smoke", "Fire", "Sparkles", "SpecialMesh",
        "SelectionBox", "SurfaceAppearance",
    }
    for _, obj in ipairs(workspace:GetDescendants()) do
        for _, cls in ipairs(removeClasses) do
            if obj:IsA(cls) then
                table.insert(removedObjects, { obj = obj, parent = obj.Parent })
                obj.Parent = nil
                break
            end
        end
    end
    local lighting = game:GetService("Lighting")
    for _, obj in ipairs(lighting:GetChildren()) do
        if obj:IsA("Sky") or obj:IsA("Atmosphere") or obj:IsA("BloomEffect")
        or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect")
        or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
            table.insert(removedObjects, { obj = obj, parent = obj.Parent })
            obj.Parent = nil
        end
    end
    lighting.GlobalShadows = false
    lighting.FogEnd        = 100000
    lighting.Brightness    = 2
end

local function disableFPSBoost()
    if not fpsBoostActive then return end
    fpsBoostActive = false
    for _, entry in ipairs(removedObjects) do
        pcall(function() entry.obj.Parent = entry.parent end)
    end
    removedObjects = {}
    local lighting = game:GetService("Lighting")
    lighting.GlobalShadows = true
    lighting.FogEnd        = 100000
    lighting.Brightness    = 1
end

player.CharacterAdded:Connect(function()
    task.wait(2)
    buildStandRFCache()
    buildWakeRFCache()
    setupPhoneOffer()
    buyLock = {}
end)

-- ============================
-- UI (WindUI)
-- ============================

local Window = WindUI:CreateWindow({
    Title = "Patch Hub",
    Icon = "leaf",
    Author = "Sell Lemons",
    Folder = "PatchHub",
    Size = UDim2.fromOffset(420, 480), -- compacto pero deja lugar a la sidebar
    Transparent = true,
    Theme = "Dark",
    Resizable = false,
    SideBarWidth = 130, -- sidebar angosta, NO en 0 (eso rompe la navegación)
})

local FarmTab  = Window:Tab({ Title = "Farm", Icon = "sprout" })
local BonusTab = Window:Tab({ Title = "Bonus", Icon = "gift" })
local StatsTab = Window:Tab({ Title = "Stats", Icon = "bar-chart-2" })
local SettTab  = Window:Tab({ Title = "Settings", Icon = "settings" })

-- Farm tab
FarmTab:Toggle({ Title = "Auto Buy Upgrades",   Value = false, Callback = function(v) ENABLED.AutoBuyUpgrades   = v end })
FarmTab:Toggle({ Title = "Auto Click Income",   Value = false, Callback = function(v) ENABLED.AutoClick         = v end })
FarmTab:Toggle({ Title = "Auto Upgrade Stands", Value = false, Callback = function(v) ENABLED.AutoUpgradeStands = v end })
FarmTab:Toggle({ Title = "Auto Collect Fruit",  Value = false, Callback = function(v) ENABLED.AutoCollectFruit  = v end })
FarmTab:Toggle({ Title = "Auto Collect Drops",  Value = false, Callback = function(v) ENABLED.AutoCollectDrops  = v end })
FarmTab:Toggle({ Title = "Auto Cash Vine",      Value = false, Callback = function(v) ENABLED.AutoCashVine      = v end })
FarmTab:Toggle({
    Title = "Auto Phone Offer",
    Value = false,
    Callback = function(v)
        ENABLED.AutoPhoneOffer = v
        if v and activeOffer then offerHandled = false respondToOffer() end
    end,
})
FarmTab:Toggle({ Title = "Auto Rebirth",       Value = false, Callback = function(v) ENABLED.AutoRebirth      = v end })
FarmTab:Toggle({ Title = "Auto Ascend",        Value = false, Callback = function(v) ENABLED.AutoAscend       = v end })
FarmTab:Toggle({ Title = "Auto Evolve",        Value = false, Callback = function(v) ENABLED.AutoEvolve       = v end })
FarmTab:Toggle({ Title = "Auto Power Upgrade", Value = false, Callback = function(v) ENABLED.AutoPowerUpgrade = v end })

-- Bonus tab
BonusTab:Toggle({ Title = "Auto Double Offline Cash", Value = false, Callback = function(v) ENABLED.AutoOfflineCash = v end })
BonusTab:Toggle({ Title = "Auto Use Time Cash",       Value = false, Callback = function(v) ENABLED.AutoTimeCash    = v end })
BonusTab:Toggle({ Title = "Auto Use Earner Boost",    Value = false, Callback = function(v) ENABLED.AutoEarnerBoost = v end })
BonusTab:Toggle({ Title = "Auto Minigame Race",       Value = false, Callback = function(v) ENABLED.AutoMinigameRace  = v end })
BonusTab:Toggle({ Title = "Auto Minigame Trade",      Value = false, Callback = function(v) ENABLED.AutoMinigameTrade = v end })

-- Stats tab
local sUpg    = StatsTab:Paragraph({ Title = "Upgrades Bought", Desc = "0" })
local sClick  = StatsTab:Paragraph({ Title = "Income Clicks",   Desc = "0" })
local sStands = StatsTab:Paragraph({ Title = "Stands Upgraded", Desc = "0" })
local sFruit  = StatsTab:Paragraph({ Title = "Fruit Collected", Desc = "0" })
local sDrop   = StatsTab:Paragraph({ Title = "Drops Collected", Desc = "0" })
local sPhone  = StatsTab:Paragraph({ Title = "Phone Offers",    Desc = "0" })
local sVine   = StatsTab:Paragraph({ Title = "Vine Collected",  Desc = "0" })
local sCash     = StatsTab:Paragraph({ Title = "Cash",           Desc = "0" })
local sRebirths = StatsTab:Paragraph({ Title = "Rebirths",       Desc = "0" })
local sAscends  = StatsTab:Paragraph({ Title = "Ascends",        Desc = "0" })
local sEvolves  = StatsTab:Paragraph({ Title = "Evolves",        Desc = "0" })
local sPower    = StatsTab:Paragraph({ Title = "Power Upgrades", Desc = "0" })
local sRaces    = StatsTab:Paragraph({ Title = "Races Won",      Desc = "0" })
local sTrades   = StatsTab:Paragraph({ Title = "Trades Won",     Desc = "0" })

task.spawn(function()
    while true do
        task.wait(1)
        pcall(function() sUpg:SetDesc(tostring(STATS.upgradesBought)) end)
        pcall(function() sClick:SetDesc(tostring(STATS.clicks)) end)
        pcall(function() sStands:SetDesc(tostring(STATS.standsUpgraded)) end)
        pcall(function() sFruit:SetDesc(tostring(STATS.fruitCollected)) end)
        pcall(function() sDrop:SetDesc(tostring(STATS.dropsCollected)) end)
        pcall(function() sPhone:SetDesc(tostring(STATS.phoneOffers)) end)
        pcall(function() sVine:SetDesc(tostring(STATS.vineCollected)) end)
        pcall(function() sCash:SetDesc(tostring(math.floor(getCash()))) end)
        pcall(function() sRebirths:SetDesc(tostring(STATS.rebirths)) end)
        pcall(function() sAscends:SetDesc(tostring(STATS.ascends)) end)
        pcall(function() sEvolves:SetDesc(tostring(STATS.evolves)) end)
        pcall(function() sPower:SetDesc(tostring(STATS.powerUpgrades)) end)
        pcall(function() sRaces:SetDesc(tostring(STATS.racesWon)) end)
        pcall(function() sTrades:SetDesc(tostring(STATS.tradesWon)) end)
    end
end)

-- Settings tab
SettTab:Slider({
    Title = "Fruit Sweep Delay",
    Step = 1,
    Value = { Min = 2, Max = 30, Default = 5 },
    Callback = function(v) FRUIT_CYCLE_DELAY = v end,
})

SettTab:Dropdown({
    Title = "Phone Offer Response",
    Values = { "Accept", "Raise", "Reject" },
    Value = "Accept",
    Multi = false,
    Callback = function(option)
        PHONE_OFFER_RESPONSE = option
    end,
})

SettTab:Toggle({ Title = "Anti-AFK", Value = false, Callback = function(v) ENABLED.AntiAFK = v end })
SettTab:Toggle({
    Title = "Boost FPS",
    Value = false,
    Callback = function(v)
        ENABLED.BoostFPS = v
        if v then enableFPSBoost() else disableFPSBoost() end
    end,
})

WindUI:Notify({
    Title = "Patch Hub",
    Content = "Loaded! Made by the goat patch himself.",
    Duration = 5,
    Icon = "leaf",
})

task.spawn(runAutoUpgrades)
task.spawn(runAutoUpgradeStands)
task.spawn(runAutoFruit)
task.spawn(runAutoClick)
task.spawn(runAutoCashDrops)
task.spawn(runAutoRebirth)
task.spawn(runAutoAscend)
task.spawn(runAutoEvolve)
task.spawn(runAutoPowerUpgrade)
task.spawn(runAutoOfflineCash)
task.spawn(runAutoTimeCash)
task.spawn(runAutoEarnerBoost)
task.spawn(runAutoMinigameRace)
task.spawn(runAutoMinigameTrade)
task.spawn(runAutoCashVine)

print("Patch Hub loaded.")
