local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    PullSpeed = 40,          -- sobrang lakas ng hila (dating 5)
    MovingMultiplier = 0.35, -- gaano pa rin kalaya ang mouse mo habang gumagalaw
    GlideSpeed = 30,         -- bilis ng paglipat sa ibang target
    FOV = 40,
    MinDistance = 5,
    ToggleBlockDistance = 1,
    TeamCheck = true,
    HeadBias = 0.6,          -- mas mababa = mas pabor sa head
    Prediction = true,
    PredictionTime = 0.08,   -- dagdag na segundo bukod sa ping
}

local TorsoNames = {"UpperTorso", "Torso", "HumanoidRootPart"}

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

local function predicted(part, root)
    if not Settings.Prediction then
        return part.Position
    end
    local t = Settings.PredictionTime
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and ping then t = t + ping end
    return part.Position + root.AssemblyLinearVelocity * t
end

local function screenDist(cam, pos, center)
    local v, on = cam:WorldToViewportPoint(pos)
    if not on then return nil end
    return (Vector2.new(v.X, v.Y) - center).Magnitude
end

local function evaluate(cam, p, center, myPos, fov)
    local char = p.Character
    if not char or p == LocalPlayer or isTeammate(p) then return nil end

    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not (hum and hum.Health > 0 and root) then return nil end
    if (root.Position - myPos).Magnitude <= Settings.MinDistance then return nil end

    local head = char:FindFirstChild("Head")
    local torso = getTorso(char)

    local hp = head and predicted(head, root)
    local tp = torso and predicted(torso, root)
    local dh = hp and screenDist(cam, hp, center)
    local dt = tp and screenDist(cam, tp, center)

    local pos, d
    if dh and dt then
        if dt < dh * Settings.HeadBias then
            pos, d = tp, dt
        else
            pos, d = hp, dh
        end
    elseif dh then
        pos, d = hp, dh
    elseif dt then
        pos, d = tp, dt
    end

    if pos and d and d < fov then
        return pos, d
    end
    return nil
end

local function getTarget(cam)
    local center = cam.ViewportSize / 2
    local myPos = getMyPos(cam)
    local best, bestDist = nil, Settings.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        local pos, d = evaluate(cam, p, center, myPos, bestDist)
        if pos then
            best, bestDist = pos, d
        end
    end
    return best
end

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Last.Value + 1, function(dt)
    if not Settings.Enabled then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local cam = workspace.CurrentCamera
    local target = getTarget(cam)
    if not target then
        aimPoint = nil
        return
    end

    if not aimPoint then
        aimPoint = target
    else
        aimPoint = aimPoint:Lerp(target, 1 - math.exp(-Settings.GlideSpeed * dt))
    end

    local speed = Settings.PullSpeed
    if UIS:GetMouseDelta().Magnitude > 1 then
        speed = speed * Settings.MovingMultiplier
    end

    local alpha = 1 - math.exp(-speed * dt)
    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, aimPoint), alpha)
end)
