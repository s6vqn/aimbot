local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    Smoothness = 0.35,
    FOV = 150,
    MinDistance = 10.5,
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
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local myPos = myRoot and myRoot.Position or cam.CFrame.Position

    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local part = char:FindFirstChild(Settings.AimPart) or char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and part
                and not (Settings.TeamCheck and p.Team ~= nil and p.Team == LocalPlayer.Team)
                and (part.Position - myPos).Magnitude > Settings.MinDistance then
                local pos, on = cam:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < bestDist and visible(cam, part, char) then
                        best, bestDist = part, d
                    end
                end
            end
        end
    end
    return best
end

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Last.Value + 1, function()
    if not Settings.Enabled then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local cam = workspace.CurrentCamera
    local target = getTarget(cam)
    if
