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
    local entry = limbRoll[char]
    if not entry or tick() - entry.time >= Settings.RerollTime then
        local limb = nil
        if math.random() < Settings.LimbChance then
            local available = {}
            for _, n in ipairs(LimbNames) do
                local l = char:FindFirstChild(n)
                if l then table.insert(available, l) end
            end
            if #available > 0 then
                limb = available[math.random(1, #available)]
            end
        end
        entry = {limb = limb, time = tick()}
        limbRoll[char] = entry
    end
    if entry.limb and entry.limb.Parent then
        return entry.limb
    end
    return nil
end

-- prediction: galaw + ping + talon (gravity kapag nasa ere)
local function predicted(part, root, hum)
    if not Settings.Prediction then
        return part.Position
    end

    local t = Settings.PredictionTime
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and ping then t = t + ping end

    local vel = root.AssemblyLinearVelocity
    local airborne = Settings.JumpPrediction and hum.FloorMaterial == Enum.Material.Air

    if airborne then
        local g = workspace.Gravity
        return part.Position + vel * t + Vector3.new(0, -0.5 * g * t * t, 0)
    end
    return part.Position + Vector3.new(vel.X, 0, vel.Z) * t
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
    local limb = getLimb(char)

    local pos, d
    if limb then
        pos = predicted(limb, root, hum)
        d = screenDist(cam, pos, center)
    else
        local hp = head and predicted(head, root, hum)
        local tp = torso and predicted(torso, root, hum)
        local dh = hp and screenDist(cam, hp, center)
        local dt = tp and screenDist(cam, tp, center)
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
    return best, bestDist
end

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Last.Value + 1, function(dt)
    if not Settings.Enabled then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local cam = workspace.CurrentCamera
    local target, dist = getTarget(cam)
    if not target then
        aimPoint = nil
        return
    end

    -- dumudulas ang aim point papunta sa target, hindi tumatalon kapag nagpalit
    if not aimPoint then
        aimPoint = target
    else
        local glide = 1 - math.exp(-Settings.GlideSpeed * dt)
        aimPoint = aimPoint:Lerp(target, glide)
    end

    -- mas malapit sa crosshair = mas malakas ang hila
    local falloff = math.max(Settings.MinFalloff, 1 - (dist / Settings.FOV))
    local speed = Settings.PullSpeed * falloff
    if UIS:GetMouseDelta().Magnitude > 1 then
        speed = speed * Settings.MovingMultiplier
    end

    local alpha = 1 - math.exp(-speed * dt)
    local goal = CFrame.lookAt(cam.CFrame.Position, aimPoint)
    cam.CFrame = cam.CFrame:Lerp(goal, alpha)
end)
