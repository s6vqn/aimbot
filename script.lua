local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    PullSpeed = 6,
    MovingMultiplier = 0.1,
    GlideSpeed = 6,
    FOV = 40,
    MinFalloff = 0.2,
    MinDistance = 5,
    ToggleBlockDistance = 1,
    TeamCheck = true,
    WallCheck = true,
    IgnoreNonCollide = false,
    Debug = false,
    HeadBias = 0.6,
    TorsoHold = 0.6,
    LimbChance = 0.20,
    RerollTime = 1.5,
    Prediction = true,
    PredictionTime = 0.08,
    JumpPrediction = true,
}

local TorsoNames = {"UpperTorso", "Torso", "HumanoidRootPart"}
local LimbNames = {
    "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", -- R15
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",                 -- R6
}

print("[Aimbot] Loaded. T = toggle, hold right click = aim")

local aimPoint = nil
local lastPlayer = nil
local switching = false
local mouseMoving = false
local torsoUntil = 0
local baseIgnore = {}
local lastLog = 0

local function resetAim()
    aimPoint = nil
    lastPlayer = nil
    switching = false
    torsoUntil = 0
end

local function getMyPos(cam)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or cam.CFrame.Position
end

local function isTeammate(p)
    return Settings.TeamCheck and p.Team ~= nil and p.Team == LocalPlayer.Team
end

local function isDead(hum)
    return hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead
end

local function someoneTooClose()
    local myPos = getMyPos(workspace.CurrentCamera)
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char and not isTeammate(p) then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and not isDead(hum) and root
                and (root.Position - myPos).Magnitude <= Settings.ToggleBlockDistance then
                return true
            end
        end
    end
    return false
end

UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.T then
        if someoneTooClose() then
            print("[Aimbot] Toggle blocked: player too close")
            return
        end
        Settings.Enabled = not Settings.Enabled
        resetAim()
        print("[Aimbot] Enabled:", Settings.Enabled)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        resetAim()
    end
end)

local function getTorso(char)
    for _, n in ipairs(TorsoNames) do
        local part = char:FindFirstChild(n)
        if part then return part end
    end
end

local limbRoll = {}

local function getLimb(char)
    local entry = limbRoll[char]
    if not entry or tick() - entry.time >= Settings.RerollTime then
        local
