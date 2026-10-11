local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    Smoothness = 0.2,
    FOV = 5,
    MinDistance = 5,
    AimPart = "Head",
    MoveThreshold = 2,
    ResumeDelay = 0.15,
}

print("[Aimbot] Loaded. T = toggle, hold right click = aim")

local resumeAt = 0

UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.T then
        Settings.Enabled = not Settings.Enabled
        print("[Aimbot] Enabled:", Settings.Enabled)
    end
end)

local function isTeammate(p)
    if LocalPlayer.Team ~= nil and p.Team == LocalPlayer.Team then
        return true
    end
    if LocalPlayer.Team ~= nil and p.Team ~= nil and p.TeamColor == LocalPlayer.TeamColor then
        return true
    end
    local myTeamAttr = LocalPlayer:GetAttribute("Team")
    if myTeamAttr ~= nil and p:GetAttribute("Team") == myTeamAttr then
        return true
    end
    return false
end

local function visible(cam, part, char)
    local ignore = {LocalPlayer.Character}
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    for _ = 1, 8 do
        params.FilterDescendantsInstances = ignore
        local hit = workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, params)
        if not hit then return true end
        if hit.Instance:IsDescendantOf(char) then return true end
        if hit.Instance.Transparency >= 0.9 or not hit.Instance.CanCollide then
            table.insert(ignore, hit.Instance)
        else
            return false
        end
    end
    return false
end

local function getTarget(cam)
    local center = cam.ViewportSize / 2
    local best, bestDist = nil, Settings.FOV
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char and not isTeammate(p) then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local part = char:FindFirstChild(Settings.AimPart) or char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and part then
                local studs = (part.Position - (myRoot and myRoot.Position or cam.CFrame.Position)).Magnitude
