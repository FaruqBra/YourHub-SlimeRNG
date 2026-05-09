--// YourHub Lite - Slime RNG (Delta Fix Version)
--// Load: loadstring(game:HttpGet("URL"))()

-- =====================
-- RE-EXECUTE SAFE
-- =====================
if getgenv().YourHub then
    if getgenv().YourHub.Stop then
        getgenv().YourHub.Stop()
    end
end

getgenv().YourHub = {}
local Hub = getgenv().YourHub

-- =====================
-- BASIC CHECK
-- =====================
if game.PlaceId ~= 92416421522960 then
    warn("Wrong game")
    return
end

-- =====================
-- SERVICES
-- =====================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

-- =====================
-- FLAGS (CONTROL)
-- =====================
Hub.Flags = {
    AutoFarm = false,
    AutoRoll = false,
    AutoPotion = false,
    ESP = false,
    Fly = false,
    NoClip = false,

    RollDelay = 1,
    FlySpeed = 60,
    PotionHP = 0.5,

    Debug = true
}

-- =====================
-- CONNECTION CLEANER
-- =====================
local Conns = {}

function Hub.Stop()
    for _,c in pairs(Conns) do
        pcall(function() c:Disconnect() end)
    end
    Conns = {}
end

-- =====================
-- SIMPLE REMOTE FINDER
-- =====================
local Remotes = {}

local function FindRemote(keyword)
    for _,v in pairs(RS:GetDescendants()) do
        if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
            if string.find(v.Name:lower(), keyword) then
                return v
            end
        end
    end
end

Remotes.Attack = FindRemote("attack") or FindRemote("damage")
Remotes.Roll   = FindRemote("roll") or FindRemote("spin")
Remotes.Potion = FindRemote("potion") or FindRemote("heal")

if Hub.Flags.Debug then
    print("Attack:", Remotes.Attack)
    print("Roll:", Remotes.Roll)
    print("Potion:", Remotes.Potion)
end

-- =====================
-- SAFE FIRE
-- =====================
local function Fire(remote, ...)
    if not remote then return end
    pcall(function()
        remote:FireServer(...)
    end)
end

-- =====================
-- FIND NEAREST MOB
-- =====================
local function GetNearestMob()
    local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end

    local root = char.HumanoidRootPart
    local closest, dist = nil, math.huge

    for _,v in pairs(workspace:GetDescendants()) do
        if v:FindFirstChild("Humanoid") and v ~= char then
            local hrp = v:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - root.Position).Magnitude
                if d < dist then
                    dist = d
                    closest = v
                end
            end
        end
    end

    return closest
end

-- =====================
-- MAIN LOOP (RINGAN)
-- =====================
Conns.Main = RunService.Heartbeat:Connect(function()
    local char = LP.Character
    if not char then return end

    local hum = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")

    -- AUTO FARM
    if Hub.Flags.AutoFarm then
        local mob = GetNearestMob()
        if mob and mob:FindFirstChild("HumanoidRootPart") then
            root.CFrame = mob.HumanoidRootPart.CFrame * CFrame.new(0,0,3)
            Fire(Remotes.Attack, mob)
        end
    end

    -- AUTO ROLL
    if Hub.Flags.AutoRoll then
        if not Hub._lastRoll or tick() - Hub._lastRoll > Hub.Flags.RollDelay then
            Hub._lastRoll = tick()
            Fire(Remotes.Roll)
        end
    end

    -- AUTO POTION
    if Hub.Flags.AutoPotion and hum then
        if hum.Health / hum.MaxHealth < Hub.Flags.PotionHP then
            Fire(Remotes.Potion)
        end
    end

    -- NOCLIP
    if Hub.Flags.NoClip then
        for _,v in pairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    end

    -- FLY
    if Hub.Flags.Fly and root then
        if not root:FindFirstChild("FlyVel") then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "FlyVel"
            bv.MaxForce = Vector3.new(1e5,1e5,1e5)
            bv.Parent = root
        end
        root.FlyVel.Velocity = root.CFrame.LookVector * Hub.Flags.FlySpeed
    else
        if root and root:FindFirstChild("FlyVel") then
            root.FlyVel:Destroy()
        end
    end
end)

-- =====================
-- SIMPLE ESP (RINGAN)
-- =====================
local function CreateESP(obj)
    if obj:FindFirstChild("ESP") then return end

    local bill = Instance.new("BillboardGui")
    bill.Name = "ESP"
    bill.Size = UDim2.new(0,100,0,30)
    bill.AlwaysOnTop = true

    local txt = Instance.new("TextLabel", bill)
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.Text = obj.Name
    txt.TextScaled = true
    txt.TextColor3 = Color3.fromRGB(255,255,0)

    bill.Parent = obj:FindFirstChild("HumanoidRootPart") or obj
end

task.spawn(function()
    while true do
        task.wait(1)

        if Hub.Flags.ESP then
            for _,v in pairs(workspace:GetDescendants()) do
                if v:FindFirstChild("Humanoid") then
                    CreateESP(v)
                end
            end
        else
            for _,v in pairs(workspace:GetDescendants()) do
                if v:FindFirstChild("ESP") then
                    v.ESP:Destroy()
                end
            end
        end
    end
end)

-- =====================
-- SIMPLE GUI (MOBILE)
-- =====================
local gui = Instance.new("ScreenGui", game.CoreGui)
local frame = Instance.new("Frame", gui)

frame.Size = UDim2.new(0,250,0,300)
frame.Position = UDim2.new(0,20,0,100)
frame.BackgroundColor3 = Color3.fromRGB(25,25,35)
frame.Active = true
frame.Draggable = true

local function Button(name, y, callback)
    local b = Instance.new("TextButton", frame)
    b.Size = UDim2.new(1,-10,0,30)
    b.Position = UDim2.new(0,5,0,y)
    b.Text = name .. ": OFF"
    b.BackgroundColor3 = Color3.fromRGB(40,40,60)

    b.MouseButton1Click:Connect(function()
        callback(b)
    end)
end

Button("AutoFarm", 10, function(b)
    Hub.Flags.AutoFarm = not Hub.Flags.AutoFarm
    b.Text = "AutoFarm: " .. (Hub.Flags.AutoFarm and "ON" or "OFF")
end)

Button("AutoRoll", 50, function(b)
    Hub.Flags.AutoRoll = not Hub.Flags.AutoRoll
    b.Text = "AutoRoll: " .. (Hub.Flags.AutoRoll and "ON" or "OFF")
end)

Button("AutoPotion", 90, function(b)
    Hub.Flags.AutoPotion = not Hub.Flags.AutoPotion
    b.Text = "AutoPotion: " .. (Hub.Flags.AutoPotion and "ON" or "OFF")
end)

Button("ESP", 130, function(b)
    Hub.Flags.ESP = not Hub.Flags.ESP
    b.Text = "ESP: " .. (Hub.Flags.ESP and "ON" or "OFF")
end)

Button("Fly", 170, function(b)
    Hub.Flags.Fly = not Hub.Flags.Fly
    b.Text = "Fly: " .. (Hub.Flags.Fly and "ON" or "OFF")
end)

Button("NoClip", 210, function(b)
    Hub.Flags.NoClip = not Hub.Flags.NoClip
    b.Text = "NoClip: " .. (Hub.Flags.NoClip and "ON" or "OFF")
end)

print("YourHub Loaded (Fixed Version)")
-- DEBUG REMOTES
task.delay(2, function()
    print("=== REMOTE LIST ===")
    for _,v in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if v:IsA("RemoteEvent") then
            print(v.Name, "|", v:GetFullName())
        end
    end
end)
