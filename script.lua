local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Settings = {
    Enabled = false,
    Smoothness = 0.08,
    FOV = 20,
    MinDistance = 5,
    ToggleBlockDistance = 1,
    TeamCheck = true,
    RerollTime = 2,
    LimbChance = 0.10,
    HeadChance = 0.45,
}

local TorsoNames = {"UpperTorso", "Torso", "LowerTorso"}
local LimbNames = {
    "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
}

print("[Aimbot] Loaded. T = toggle, hold right click = aim")

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
        print("[Aimbot] Enabled:", Settings.Enabled)
    end
end)

local function firstPart(char, names)
    for _, n in ipairs(names) do
        local part = char:FindFirstChild(n)
        if part then return part end
    end
end

local chosen = {}

local function pickPart(char)
    local entry = chosen[char]
    if entry and tick() - entry.time < Settings.RerollTime and entry.part.Parent then
        return entry.part
    end

    local r = math.random()
    local part
    if r < Settings.LimbChance then
        local available = {}
        for _, n in ipairs(LimbNames) do
            local l = char:FindFirstChild(n)
            if l then table.insert(available, l) end
        end
        part = available[math.random(1, math.max(#available, 1))]
    elseif r < Settings.LimbChance + Settings.HeadChance then
        part = char:FindFirstChild("Head")
    else
        part = firstPart(char, TorsoNames)
    end

    part = part or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    if part then
        chosen[char] = {part = part, time = tick()}
    end
    return part
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
    local myPos = getMyPos(cam)

    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char and not isTeammate(p) then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and root
                and (root.Position - myPos).Magnitude > Settings.MinDistance then
                local part = pickPart(char)
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
    end
    return best
end

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Last.Value + 1, function()
    if not Settings.Enabled then return end
    if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local cam = workspace.CurrentCamera
    local target = getTarget(cam)
    if target then
        local goal = CFrame.lookAt(cam.CFrame.Position, target.Position)
        cam.CFrame = cam.CFrame:Lerp(goal, Settings.Smoothness)
    end
end)
