local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    Smoothness = 0.35,
    FOV = 150,
    AimPart = "Head",
    TeamCheck = true, -- naka-on na
}

print("[Aimbot] Loaded. T = toggle, hold right click = aim")

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.T then
        Settings.Enabled = not Settings.Enabled
        print("[Aimbot] Enabled:", Settings.Enabled)
    end
end)

-- Match check: galing sa server attribute
local function isInMatch(player)
    return player:GetAttribute("InMatch") == true
end

local function isAlive(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil
        and hum.Health > 0
        and hum:GetState() ~= Enum.HumanoidStateType.Dead
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

local function isValidTarget(p)
    if p == LocalPlayer then return false end
    if not isInMatch(p) then return false end -- spectator, lobby, labas ng match
    if Settings.TeamCheck and p.Team ~= nil and p.Team == LocalPlayer.Team then
        return false
    end
    return isAlive(p.Character)
end

local function getTarget(cam)
    local center = cam.ViewportSize / 2
    local best, bestDist = nil, Settings.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        if isValidTarget(p) then
            local char = p.Character
            local part = char:FindFirstChild(Settings.AimPart) or char:FindFirstChild("HumanoidRootPart")
            if part then
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

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Camera.Value + 1, function()
    if not Settings.Enabled then return end
    if not isInMatch(LocalPlayer) then return end -- hindi gagana kung ikaw mismo ay spectator/lobby
    if not isAlive(LocalPlayer.Character) then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local cam = workspace.CurrentCamera
    local target = getTarget(cam)
    if target then
        local goal = CFrame.lookAt(cam.CFrame.Position, target.Position)
        cam.CFrame = cam.CFrame:Lerp(goal, Settings.Smoothness)
    end
end)
