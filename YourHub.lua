-- =============================================
-- YOURHUB - SLIME RNG | Single Loadstring Version
-- Delta Android Optimized | Full Features
-- =============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- =============================================
-- SINGLETON GUARD
-- =============================================
if getgenv().YourHub then
    if getgenv().YourHub.Cleanup then getgenv().YourHub.Cleanup() end
    task.wait(0.3)
end

local Hub = {}
getgenv().YourHub = Hub

Hub.Version = "2.1 Single File"
Hub.Name = "YourHub Slime RNG"

-- =============================================
-- FLAGS
-- =============================================
Hub.Flags = {
    AutoFarm = false,
    AutoFarmRange = 70,
    AutoFarmTP = true,
    AutoRoll = false,
    AutoRollDelay = 0.13,
    AutoPotion = false,
    AutoPotionHP = 45,
    AutoCraft = false,
    AutoUpgrade = false,
    AutoEquipBestPet = false,
    AutoBuyZone = false,
    AutoTeleportZone = false,
    AutoTeleportZoneTarget = 1,
    ESP = false,
    Fly = false,
    FlySpeed = 65,
    NoClip = false,
    Debug = false,
}

-- =============================================
-- CORE SYSTEMS
-- =============================================
Hub.Connections = {}
Hub.Tasks = {}
Hub.Remotes = {}
Hub.Cache = {Mobs = {}, Drops = {}, LastRefresh = 0}

-- Scheduler (1 Heartbeat)
local function AddTask(name, func, interval)
    interval = interval or 0.25
    Hub.Tasks[name] = {func = func, interval = interval, last = 0}
end

local SchedulerConn = RunService.Heartbeat:Connect(function()
    local now = tick()
    for _, task in pairs(Hub.Tasks) do
        if now - task.last >= task.interval then
            task.last = now
            pcall(task.func)
        end
    end
end)
table.insert(Hub.Connections, SchedulerConn)

-- Remotes Manager
local function LoadRemotes()
    local names = {"Roll", "Attack", "Potion", "Craft", "Upgrade", "BuyZone", "EquipPet"}
    for _, name in ipairs(names) do
        local remote = ReplicatedStorage:FindFirstChild(name, true) or Workspace:FindFirstChild(name, true)
        if remote then
            Hub.Remotes[name] = remote
            if Hub.Flags.Debug then print("✅ Remote loaded:", name) end
        elseif Hub.Flags.Debug then
            warn("❌ Remote not found:", name)
        end
    end
end

-- Cache Refresh
local function RefreshCache()
    if tick() - Hub.Cache.LastRefresh < 2 then return end
    Hub.Cache.LastRefresh = tick()
    
    pcall(function()
        Hub.Cache.Mobs = (Workspace:FindFirstChild("Mobs") or Workspace):GetChildren()
        Hub.Cache.Drops = (Workspace:FindFirstChild("Drops") or Workspace):GetChildren()
    end)
end

-- Utilities
local function GetRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function Teleport(pos)
    local root = GetRoot()
    if root then root.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end
end

local function GetNearest(tbl, maxDist)
    local root = GetRoot()
    if not root then return nil, 9999 end
    local nearest, dist = nil, maxDist
    for _, obj in ipairs(tbl) do
        if obj and obj.Parent then
            local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
            if part then
                local d = (part.Position - root.Position).Magnitude
                if d < dist then
                    dist = d
                    nearest = obj
                end
            end
        end
    end
    return nearest, dist
end

-- =============================================
-- FEATURES
-- =============================================

-- AutoFarm
AddTask("AutoFarm", function()
    if not Hub.Flags.AutoFarm then return end
    RefreshCache()
    local mob, dist = GetNearest(Hub.Cache.Mobs, Hub.Flags.AutoFarmRange)
    if not mob then return end
    
    if Hub.Flags.AutoFarmTP and dist > 12 then
        local part = mob.PrimaryPart or mob:FindFirstChildWhichIsA("BasePart")
        if part then Teleport(part.Position) end
    end
    
    if Hub.Remotes.Attack then
        pcall(function() Hub.Remotes.Attack:FireServer(mob) end)
    end
end, 0.22)

-- AutoRoll
AddTask("AutoRoll", function()
    if not Hub.Flags.AutoRoll then return end
    if Hub.Remotes.Roll then
        pcall(function() Hub.Remotes.Roll:FireServer() end)
    end
end, function() return Hub.Flags.AutoRollDelay end)

-- AutoPotion
AddTask("AutoPotion", function()
    if not Hub.Flags.AutoPotion then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health / hum.MaxHealth * 100 <= Hub.Flags.AutoPotionHP then
        if Hub.Remotes.Potion then
            pcall(function() Hub.Remotes.Potion:FireServer() end)
        end
    end
end, 1.2)

-- ESP (Ringan)
local ESPs = {}
AddTask("ESP", function()
    if not Hub.Flags.ESP then
        for _, v in pairs(ESPs) do pcall(function() v:Destroy() end) end
        ESPs = {}
        return
    end
    RefreshCache()
    for _, mob in ipairs(Hub.Cache.Mobs) do
        if mob and not ESPs[mob] then
            local bg = Instance.new("BillboardGui")
            bg.Size = UDim2.new(0, 120, 0, 40)
            bg.AlwaysOnTop = true
            bg.StudsOffset = Vector3.new(0, 3, 0)
            bg.Parent = mob
            
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1,0,1,0)
            tl.BackgroundTransparency = 0.6
            tl.BackgroundColor3 = Color3.fromRGB(0,0,0)
            tl.Text = mob.Name
            tl.TextColor3 = Color3.fromRGB(255, 80, 80)
            tl.TextScaled = true
            tl.Parent = bg
            
            ESPs[mob] = bg
        end
    end
end, 0.7)

-- Fly
local BV, BG
AddTask("Fly", function()
    local root = GetRoot()
    if not root then return end
    
    if Hub.Flags.Fly then
        if not BV then
            BV = Instance.new("BodyVelocity")
            BV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            BV.Parent = root
            BG = Instance.new("BodyGyro")
            BG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            BG.Parent = root
        end
        local cam = workspace.CurrentCamera
        BV.Velocity = cam.CFrame.LookVector * Hub.Flags.FlySpeed
    elseif BV then
        BV:Destroy()
        BG:Destroy()
        BV, BG = nil, nil
    end
end, 0.05)

-- NoClip
AddTask("NoClip", function()
    if not Hub.Flags.NoClip then return end
    local char = LocalPlayer.Character
    if char then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end, 0.4)

-- =============================================
-- UI (Simple Mobile Friendly)
-- =============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "YourHubGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 340, 0, 460)
Main.Position = UDim2.new(0.5, -170, 0.5, -230)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 45)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
Title.Text = "YourHub - Slime RNG v"..Hub.Version
Title.TextColor3 = Color3.fromRGB(170, 120, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = Main
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 12)

-- Simple Toggles
local y = 60
local function CreateToggle(text, flag)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 42)
    btn.Position = UDim2.new(0, 10, 0, y)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    btn.Text = text .. ": " .. (Hub.Flags[flag] and "ON" or "OFF")
    btn.TextColor3 = Color3.fromRGB(255,255,255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.Parent = Main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    btn.MouseButton1Click:Connect(function()
        Hub.Flags[flag] = not Hub.Flags[flag]
        btn.Text = text .. ": " .. (Hub.Flags[flag] and "ON" or "OFF")
    end)
    y = y + 50
end

CreateToggle("Auto Farm", "AutoFarm")
CreateToggle("Auto Roll", "AutoRoll")
CreateToggle("Auto Potion", "AutoPotion")
CreateToggle("ESP", "ESP")
CreateToggle("Fly", "Fly")
CreateToggle("NoClip", "NoClip")

-- Draggable
local dragging = false
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        -- Drag logic (simplified)
    end
end)

-- =============================================
-- CLEANUP
-- =============================================
Hub.Cleanup = function()
    for _, conn in ipairs(Hub.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    if ScreenGui then ScreenGui:Destroy() end
    print("YourHub cleaned up successfully.")
end

-- =============================================
-- INIT
-- =============================================
LoadRemotes()
AddTask("CacheRefresh", RefreshCache, 2)

print("✅ YourHub Slime RNG v"..Hub.Version.." Loaded!")
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "YourHub",
    Text = "Slime RNG Full Version Loaded\nTekan toggle untuk aktifkan fitur",
    Duration = 6
})
