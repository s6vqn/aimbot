local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    PullSpeed = 4,
    MovingMultiplier = 0.12,
    GlideSpeed = 8,
    FOV = 40,
    MinFalloff = 0.3,
    MinDistance = 5,
    MaxDistance = 200,
    LockFOVMultiplier = 2.5,
    SwitchMargin = 0.9,       -- mas mataas = mas madaling lumipat sa ibang player
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
    "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

print("[Aimbot] Loaded. T = toggle, hold right click = aim")

local aimPoint = nil
local lastPlayer = nil
local lockedPlayer = nil
local switching = false
local mouseMoving = false
local torsoUntil = 0
local baseIgnore = {}
local lastLog = 0

local function resetAim()
    aimPoint = nil
    lastPlayer = nil
    lockedPlayer = nil
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

Players.PlayerRemoving:Connect(function(p)
    if p == lockedPlayer then lockedPlayer = nil end
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

local function isAirborne(hum, root)
    local s = hum:GetState()
    if s == Enum.HumanoidStateType.Jumping or s == Enum.HumanoidStateType.Freefall then
        return true
    end
    if hum.FloorMaterial == Enum.Material.Air then
        return true
    end
    return math.abs(root.AssemblyLinearVelocity.Y) > 8
end

local function predicted(part, root, hum)
    if not Settings.Prediction then
        return part.Position
    end

    local t = Settings.PredictionTime
    local ok, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
    if ok and ping then t = t + ping end

    local vel = root.AssemblyLinearVelocity

    if Settings.JumpPrediction and isAirborne(hum, root) then
        local g = workspace.Gravity
        return part.Position + vel * t + Vector3.new(0, -0.5 * g * t * t, 0)
    end
    return part.Position + Vector3.new(vel.X, 0, vel.Z) * t
end

local function buildIgnore()
    baseIgnore = {}
    if LocalPlayer.Character then table.insert(baseIgnore, LocalPlayer.Character) end
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl ~= LocalPlayer and pl.Character then
            table.insert(baseIgnore, pl.Character)
        end
    end
end

local function visible(cam, targetPos)
    if not Settings.WallCheck then return true end

    local origin = cam.CFrame.Position
    local ignore = table.clone(baseIgnore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    for _ = 1, 20 do
        params.FilterDescendantsInstances = ignore
        local hit = workspace:Raycast(origin, targetPos - origin, params)
        if not hit then return true end

        local inst = hit.Instance
        if inst.Transparency >= 0.9 or (Settings.IgnoreNonCollide and not inst.CanCollide) then
            table.insert(ignore, inst)
        else
            if Settings.Debug and tick() - lastLog > 1 then
                lastLog = tick()
                print("[Aimbot] Wall blocked by:", inst:GetFullName())
            end
            return false
        end
    end
    return false
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
    if not (hum and root) or isDead(hum) then return nil end

    local studs = (root.Position - myPos).Magnitude
    if studs <= Settings.MinDistance or studs > Settings.MaxDistance then return nil end

    local head = char:FindFirstChild("Head")
    local torso = getTorso(char)
    local limb = getLimb(char)

    local pos, d, part
    if limb then
        part = limb
        pos = predicted(limb, root, hum)
        d = screenDist(cam, pos, center)
    else
        local hp = head and predicted(head, root, hum)
        local tp = torso and predicted(torso, root, hum)
        local dh = hp and screenDist(cam, hp, center)
        local dt = tp and screenDist(cam, tp, center)

        if dh and dt and mouseMoving and dt < dh * Settings.HeadBias then
            torsoUntil = tick() + Settings.TorsoHold
        end
        local useTorso = tick() < torsoUntil

        if dh and dt then
            if useTorso then
                pos, d, part = tp, dt, torso
            else
                pos, d, part = hp, dh, head
            end
        elseif dh then
            pos, d, part = hp, dh, head
        elseif dt then
            pos, d, part = tp, dt, torso
        end
    end

    if pos and d and d < fov and visible(cam, part.Position) then
        return pos, d
    end
    return nil
end

local function getTarget(cam)
    buildIgnore()
    local center = cam.ViewportSize / 2
    local myPos = getMyPos(cam)

    local best, bestDist, bestPlayer = nil, Settings.FOV, nil
    for _, p in ipairs(Players:GetPlayers()) do
        local pos, d = evaluate(cam, p, center, myPos, bestDist)
        if pos then
            best, bestDist, bestPlayer = pos, d, p
        end
    end

    if lockedPlayer then
        local lpos, ld = evaluate(cam, lockedPlayer, center, myPos, Settings.FOV * Settings.LockFOVMultiplier)
        if lpos then
            local dragged = mouseMoving and bestPlayer and bestPlayer ~= lockedPlayer
                and bestDist < ld * Settings.SwitchMargin
            if not dragged then
                return lpos, ld, lockedPlayer
            end
        end
    end

    lockedPlayer = bestPlayer
    return best, bestDist, bestPlayer
end

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Last.Value + 1, function(dt)
    if not Settings.Enabled then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    mouseMoving = UIS:GetMouseDelta().Magnitude > 1

    local cam = workspace.CurrentCamera
    local target, dist, targetPlayer = getTarget(cam)
    if not target then
        resetAim()
        return
    end

    if not aimPoint then
        aimPoint = target
    else
        if lastPlayer and targetPlayer ~= lastPlayer then
            switching = true
        end
        if switching then
            aimPoint = aimPoint:Lerp(target, 1 - math.exp(-Settings.GlideSpeed * dt))
            if (aimPoint - target).Magnitude < 1.5 then
                switching = false
            end
        else
            aimPoint = target
        end
    end
    lastPlayer = targetPlayer

    -- falloff batay sa normal na FOV, hindi sa lock FOV
    local falloff = math.clamp(1 - (dist / Settings.FOV), Settings.MinFalloff, 1)
    local speed = Settings.PullSpeed * falloff
    if mouseMoving then
        speed = speed * Settings.MovingMultiplier
    end

    local alpha = 1 - math.exp(-speed * dt)
    cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, aimPoint), alpha)
end)
