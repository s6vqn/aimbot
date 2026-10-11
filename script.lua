local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    Smoothness = 0.35,
    FOV = 150,
    MinDistance = 20,
    AimPart = "Head",
    TeamCheck = false,
}

print("[Aimbot] Loaded. T = toggle, hold right click = aim")

UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.T then
        Settings.Enabled = not Settings.Enabled
        print("[Aimbot] Enabled:", Settings.Enabled)
    end
end)

local function isAlive(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.Health <= 0 then return false end
    if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
    return true
end

local function visible(cam, part, char)
    local ignore = {LocalPlayer.Character}
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    for _ = 1, 15 do
        params.FilterDescendantsInstances = ignore
        local hit = workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, params)
        if not hit then return true end

        local inst = hit.Instance
        if inst:IsDescendantOf(char) then return true end

        local model = inst:FindFirstAncestorOfClass("Model")
        local hum = model and model:FindFirstChildOfClass("Humanoid")
        local isDeadBody = hum and (hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead)

        if isDeadBody then
            table.insert(ignore, model)
        elseif inst.Transparency >= 0.9 or not inst.CanCollide then
            table.insert(ignore, inst)
        else
            return false
        end
    end
    return false
end

local function getTarget(cam)
    local center = cam.ViewportSize / 2
    local best, bestDist = nil, Settings.FOV
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humano
