YourHub Slime RNG Script
lua
Salin
-- YourHub Slime RNG v1.0 | by AI/User 
-- Load: loadstring(game:HttpGet("https://raw.githubusercontent.com/YOURNAME/YourHub/main/YourHub.lua"))()
--[[
    Catatan:
    - Versi Delta Android (optimasi mobile)
    - Kolom kode dipecah sesuai fungsi (Core, Features, UI, dll)
    - Untuk pembaruan, lihat bagian "Cara Update Remotes"
]]

-- Proteksi re-run
if getgenv().YourHub then
    print("[YourHub] Reinisialisasi...")
    -- Bersihkan koneksi lama
    if getgenv().YourHub.Cleanup then
        getgenv().YourHub.Cleanup()
    end
end
-- Singleton guard
getgenv().YourHub = {}
local Hub = getgenv().YourHub

-- Check PlaceId
local PLACE_ID = 92416421522960
if game.PlaceId ~= PLACE_ID then
    warn("[YourHub] Skrip ini hanya untuk Slime RNG.")
    return
end

--[[
SISTEM INTI
1) Flags & Config
2) Sistem Cache
3) Manager Remote
4) Penjadwal & Koneksi
5) Utilitas & Logging
]]

-- 1) Flags (tombol ON/OFF dan pengaturan)
Hub.Flags = {
    Debug = false,
    AutoFarm = false,
    AutoFarm_Teleport = false,
    AutoPotion = false,
    AutoPotion_Threshold = 0.5,
    AutoRoll = false,
    AutoRoll_Delay = 1.0,
    AutoCraft = false,
    AutoCraft_Slime = nil, -- diisi nama slime target
    AutoUpgrade = false,
    AutoUpgrade_Stat = nil,
    AutoEquipBestPet = false,
    AutoBuyZone = false,
    AutoBuyZone_Level = nil,
    AutoTeleportZone = false,
    AutoTeleportZone_Level = nil,
    ESP = false,
    Fly = false,
    Fly_Speed = 50,
    NoClip = false,
    TeleportToDrop = false,
}

-- Tabel inti
local Cache = {}
local Remotes = {}
local Connections = {}
local Scheduler = {}
local Utils = {}

-- Fungsi utilitas: pcall untuk Remote
function Utils:Fire(remote, ...)
    if not remote then return end
    local ok, res = pcall(function() return remote:FireServer(...) end)
    if not ok and Hub.Flags.Debug then
        warn("[YourHub] Remote.Fire gagal:", res)
    end
    return res
end

function Utils:Invoke(remote, ...)
    if not remote then return end
    local ok, res = pcall(function() return remote:InvokeServer(...) end)
    if not ok and Hub.Flags.Debug then
        warn("[YourHub] Remote.Invoke gagal:", res)
    end
    return res
end

-- Logger / Notifikasi sederhana
function Utils:Notify(text)
    -- Saat flag berubah, cetak notifikasi sederhana
    print("[YourHub] ".. text)
    -- TODO: Tambah notifikasi GUI minimal (jika perlu)
end

-- Cleanup: matikan semua koneksi dan tugas
function Hub.Cleanup()
    for _, conn in pairs(Connections) do
        if conn then
            conn:Disconnect()
        end
    end
    Connections = {}
    -- Reset scheduler tasks
    Scheduler.Tasks = {}
end

-- 2) Sistem Cache
function Cache:Init()
    self.Mobs = {}
    self.Drops = {}
    self.LastUpdate = 0
    print("[Cache] Inisialisasi selesai.")
end

function Cache:Update()
    -- Update daftar mobs dan drops dalam radius tertentu
    local radius = 100
    local player = game.Players.LocalPlayer
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local root = char.HumanoidRootPart
    self.Mobs = {}
    self.Drops = {}
    for _, mob in pairs(workspace:FindFirstChild("Mobs") or {}) do
        if mob:FindFirstChild("HumanoidRootPart") then
            local dist = (mob.HumanoidRootPart.Position - root.Position).magnitude
            if dist < radius then
                table.insert(self.Mobs, mob)
            end
        end
    end
    for _, drop in pairs(workspace:FindFirstChild("Drops") or {}) do
        if drop:FindFirstChild("BasePart") then
            local dist = (drop.BasePart.Position - root.Position).magnitude
            if dist < radius then
                table.insert(self.Drops, drop)
            end
        end
    end
    self.LastUpdate = os.clock()
end

-- 3) Manager Remote
function Remotes:Init()
    local RS = game:GetService("ReplicatedStorage")
    local candidates = {"Attack", "Roll", "BuyZone", "UseItem", "Teleport", "Upgrade", "Craft", "Potion"}
    for _, name in ipairs(candidates) do
        local rem = RS:FindFirstChild(name) or RS:FindFirstChild(name.."_Remote")
        if rem and (rem:IsA("RemoteEvent") or rem:IsA("RemoteFunction")) then
            self[name] = rem
        end
    end
    print("[Remotes] Inisialisasi selesai.")
end

-- 4) Scheduler & Koneksi
Scheduler.Tasks = {}
function Scheduler:AddTask(name, func, interval)
    self.Tasks[name] = {Func = func, Interval = interval, LastRun = 0}
end
function Scheduler:Tick(dt)
    for name, task in pairs(self.Tasks) do
        task.LastRun = task.LastRun + dt
        if task.LastRun >= task.Interval then
            task.LastRun = 0
            local ok, err = pcall(task.Func)
            if not ok and Hub.Flags.Debug then
                warn("[Scheduler] task '"..name.."' gagal: "..tostring(err))
            end
        end
    end
end

-- Koneksi utama ke RunService Heartbeat
Connections.Heartbeat = game:GetService("RunService").Heartbeat:Connect(function(dt)
    Scheduler:Tick(dt)
    if os.clock() - (Cache.LastUpdate or 0) > 1 then
        Cache:Update()
    end
end)

-- 5) Utilitas tambahan (helper)
function Utils:ShortestName(obj)
    if not obj then return "nil" end
    return obj.Name
end

-- Inisialisasi core systems
Cache:Init()
Remotes:Init()

--[[
FITUR-FITUR
Setiap fitur diikat ke Scheduler dan Flags
]]

-- AutoFarm: serang mob terdekat & teleport (opsional)
local function AutoFarm_Tick()
    if not Hub.Flags.AutoFarm then return end
    local mobs = Cache.Mobs
    if #mobs == 0 then return end
    table.sort(mobs, function(a,b)
        local pa = a.HumanoidRootPart.Position
        local pb = b.HumanoidRootPart.Position
        local root = game.Players.LocalPlayer.Character.HumanoidRootPart.Position
        return (pa - root).magnitude < (pb - root).magnitude
    end)
    local target = mobs[1]
    if target and target:FindFirstChild("HumanoidRootPart") then
        if Hub.Flags.AutoFarm_Teleport then
            game.Players.LocalPlayer.Character:MoveTo(target.HumanoidRootPart.Position)
        end
        Utils:Fire(Remotes.Attack, target)
    end
end
Scheduler:AddTask("AutoFarm", AutoFarm_Tick, 0.5)

-- AutoRoll: gulung dengan delay
local function AutoRoll_Tick()
    if not Hub.Flags.AutoRoll then return end
    if os.clock() - (Hub.LastRoll or 0) < Hub.Flags.AutoRoll_Delay then return end
    Hub.LastRoll = os.clock()
    Utils:Fire(Remotes.Roll)
end
Scheduler:AddTask("AutoRoll", AutoRoll_Tick, 0.1)

-- AutoPotion: gunakan potion saat HP rendah
local function AutoPotion_Tick()
    if not Hub.Flags.AutoPotion then return end
    local plr = game.Players.LocalPlayer
    local char = plr.Character
    if not char or not char:FindFirstChild("Humanoid") then return end
    local hpRatio = char.Humanoid.Health / char.Humanoid.MaxHealth
    if hpRatio < Hub.Flags.AutoPotion_Threshold then
        Utils:Fire(Remotes.Potion)
    end
end
Scheduler:AddTask("AutoPotion", AutoPotion_Tick, 0.5)

-- Tambah fitur lain seperti AutoCraft, AutoUpgrade, AutoEquipBestPet, AutoBuyZone, AutoTeleportZone, Teleport ke Drop
-- Contoh implementasi sederhana:
local function AutoCraft_Tick()
    if not Hub.Flags.AutoCraft or not Hub.Flags.AutoCraft_Slime then return end
    Utils:Fire(Remotes.Craft, Hub.Flags.AutoCraft_Slime)
end
Scheduler:AddTask("AutoCraft", AutoCraft_Tick, 1.0)

-- NoClip: matikan tabrakan part karakter
local function NoClip_Tick()
    if Hub.Flags.NoClip then
        local char = game.Players.LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end
Scheduler:AddTask("NoClip", NoClip_Tick, 0.2)

-- Fly: tambahkan BodyVelocity pada HumanoidRootPart
local bodyVel = nil
local function Fly_Tick()
    local plr = game.Players.LocalPlayer
    local char = plr.Character
    if Hub.Flags.Fly and char and char:FindFirstChild("HumanoidRootPart") then
        if not bodyVel then
            bodyVel = Instance.new("BodyVelocity")
            bodyVel.MaxForce = Vector3.new(0,0,0)
            bodyVel.Parent = char.HumanoidRootPart
        end
        bodyVel.MaxForce = Vector3.new(1e5,1e5,1e5)
        bodyVel.Velocity = char.HumanoidRootPart.CFrame.LookVector * Hub.Flags.Fly_Speed
    else
        if bodyVel then
            bodyVel:Destroy()
            bodyVel = nil
        end
    end
end
Scheduler:AddTask("Fly", Fly_Tick, 0.1)

-- ESP: buat BillboardGui sederhana untuk mobs & drops
local function ESP_CreateLabel(obj, text)
    if not obj or not obj:IsA("Model") then return end
    if obj:FindFirstChild("YourHubESP") then return end
    local bill = Instance.new("BillboardGui")
    bill.Name = "YourHubESP"
    bill.Adornee = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("BasePart")
    bill.Size = UDim2.new(0,100,0,30)
    bill.StudsOffset = Vector3.new(0,3,0)
    bill.AlwaysOnTop = true
    local label = Instance.new("TextLabel", bill)
    label.Size = UDim2.new(1,0,1,0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,0)
    label.Text = text or "ESP"
    label.TextScaled = true
    bill.Parent = obj
end

local function ESP_Tick()
    if Hub.Flags.ESP then
        for _, mob in pairs(Cache.Mobs) do
            if mob and mob:FindFirstChild("HumanoidRootPart") then
                if not mob:FindFirstChild("YourHubESP") then
                    ESP_CreateLabel(mob, mob.Name)
                end
            end
        end
        for _, drop in pairs(Cache.Drops) do
            if drop and drop:FindFirstChild("BasePart") then
                if not drop:FindFirstChild("YourHubESP") then
                    ESP_CreateLabel(drop, drop.Name)
                end
            end
        end
    else
        -- Jika ESP dimatikan, hapus semua label
        for _, mob in pairs(Cache.Mobs) do
            if mob:FindFirstChild("YourHubESP") then mob.YourHubESP:Destroy() end
        end
        for _, drop in pairs(Cache.Drops) do
            if drop:FindFirstChild("YourHubESP") then drop.YourHubESP:Destroy() end
        end
    end
end
Scheduler:AddTask("ESP", ESP_Tick, 0.5)

--[[
USER INTERFACE (mobile friendly, tema gelap ungu)
]]
local ui = Instance.new("ScreenGui")
ui.Name = "YourHubUI"
ui.Parent = game:GetService("CoreGui")

local frame = Instance.new("Frame", ui)
frame.Name = "MainFrame"
frame.AnchorPoint = Vector2.new(0.5,0.5)
frame.Position = UDim2.new(0.5, 0.5)
frame.Size = UDim2.new(0, 300, 0, 400)
frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
frame.Active = true
local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", frame)
title.Text = "YourHub - Slime RNG"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextColor3 = Color3.fromRGB(200, 200, 255)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 30)

-- Kontainer Tab (Farm, Items, Pets, World, Visual, Movement)
local tabNames = {"Farm", "Items", "Pets", "World", "Visual", "Movement"}
local buttons = {}
for i,name in ipairs(tabNames) do
    local btn = Instance.new("TextButton", frame)
    btn.Text = name
    btn.Position = UDim2.new((i-1)/#tabNames, 0, 0, 30)
    btn.Size = UDim2.new(1/#tabNames, 0, 0, 25)
    btn.TextColor3 = Color3.new(1,1,1)
    btn.BackgroundColor3 = Color3.fromRGB(50,50,60)
    buttons[i] = btn
    -- Ketika tombol diklik: tampilkan tab (implementasikan toggle tampilan)
    btn.MouseButton1Click:Connect(function()
        -- TODO: tampilkan panel tab sesuai pilihan
    end)
end

-- Contoh toggle di tab "Farm"
local autoFarmToggle = Instance.new("TextButton", frame)
autoFarmToggle.Text = "AutoFarm: OFF"
autoFarmToggle.Size = UDim2.new(0, 280, 0, 30)
autoFarmToggle.Position = UDim2.new(0, 10, 0, 60)
autoFarmToggle.BackgroundColor3 = Color3.fromRGB(60,60,80)
autoFarmToggle.TextColor3 = Color3.new(1,1,1)
autoFarmToggle.MouseButton1Click:Connect(function()
    Hub.Flags.AutoFarm = not Hub.Flags.AutoFarm
    autoFarmToggle.Text = "AutoFarm: " .. (Hub.Flags.AutoFarm and "ON" or "OFF")
    Utils:Notify("AutoFarm " .. (Hub.Flags.AutoFarm and "Enabled" or "Disabled"))
end)

-- (Tambahkan Slider, Dropdown, Button, dsb. di setiap tab sesuai fitur)

--[[
Cara Update Remotes:
Jika remote di Slime RNG berubah nama, buka bagian "Remotes:Init" di script dan tambahkan nama baru di daftar candidates.
Cek di ReplicatedStorage untuk nama remote terbaru.

Troubleshooting Delta Android:
- Jika GUI tidak muncul, tunggu beberapa detik setelah game load (atau gunakan delay).
- Jika tombol UI tidak responsif, cek ukuran dan Active property frame.
- Pastikan RemoteEvent/RemoteFunction benar (aktifkan Debug jika perlu).
]]

--- Instruksi Commit GitHub ---

Salin blok kode di atas ke YourHub.lua di repository Anda.
Lakukan commit dengan pesan: "Updated YourHub for Slime RNG v1.0".
Uji di Delta: loadstring(URL) untuk memuat dan menjalankan.
