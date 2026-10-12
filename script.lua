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

local function screenDist(cam, part, center)
    local pos, on = cam:WorldToViewportPoint(part.Position)
    if not on then return nil end
    return (Vector2.new(pos.X, pos.Y) - center).Magnitude
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

    local part, d
    if limb then
        part, d = limb, screenDist(cam, limb, center)
    else
        local dh = head and screenDist(cam, head, center)
        local dt = torso and screenDist(cam, torso, center)
        if dh and dt then
            if dt < dh * Settings.HeadBias then
                part, d = torso, dt
            else
                part, d = head, dh
            end
        elseif dh then
            part, d = head, dh
        elseif dt then
            part, d = torso, dt
        end
    end

    if part and d and d < fov and visible(cam, part, char) then
        return part, d
    end
    return nil
end

local function getTarget(cam)
    local center = cam.ViewportSize / 2
    local myPos = getMyPos(cam)
    local best, bestDist = nil, Settings.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        local part, d = evaluate(cam, p, center, myPos, bestDist)
        if part then
            best, bestDist = part, d
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
        aimPoint = target.Position
    else
        local glide = 1 - math.exp(-Settings.GlideSpeed * dt)
        aimPoint = aimPoint:Lerp(target.Position, glide)
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
