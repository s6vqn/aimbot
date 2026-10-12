local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    PullSpeed = 5,
    MovingMultiplier = 0.15,
    GlideSpeed = 6,        -- mas mababa = mas mabagal ang dulas papunta sa bagong target
    FOV = 40,
    MinFalloff = 0.25,     -- lakas ng hila sa gilid ng FOV (0 hanggang 1)
    MinDistance = 5,
    ToggleBlockDistance = 1,
    TeamCheck = true,
    HeadBias = 0.6,
    LimbChance = 0.20,
    RerollTime = 1.5,
    Prediction = true,
    PredictionTime = 0.08, -- dagdag na segundo bukod sa ping
    JumpPrediction = true,
}

local TorsoNames = {"UpperTorso", "Torso", "HumanoidRootPart"}
local LimbNames = {
    "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", -- R15
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",                 -- R6
}

print("[Aimbot] Loaded. T = toggle, hold right click = aim")

local aimPoint = nil

local function getMyPos(cam)
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or cam.CFrame.Position
end

local function isTeammate(p)
    return Settings.TeamCheck and p.Team ~= nil and p.Team == LocalPlayer.Team
end

local function someoneTooClose()
    local myPos = getMyPos(workspace.CurrentCamera)
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char and not isTeammate(p) then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and root
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
        aimPoint = nil
        print("[Aimbot] Enabled:", Settings.Enabled)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aimPoint = nil
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
    local entry =
