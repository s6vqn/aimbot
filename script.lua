local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Settings = {
    Aimbot = false,
    Smoothness = 0.5,
    FOVSize = 150,
    AimPart = "Head",
    TeamCheck = false,
    KillCheck = true,
    Debug = true,
}

print("[Aimbot] Script loaded. Press T to toggle, hold right click to aim.")

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.T then
        Settings.Aimbot = not Settings.Aimbot
        print("[Aimbot] Enabled:", Settings.Aimbot)
    end
end)

local function GetAimPart(char)
    return char:FindFirstChild(Settings.AimPart)
        or char:FindFirstChild("HumanoidRootPart")
        or char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
end

local function SameTeam(p)
    return p.Team ~= nil and p.Team == LocalPlayer.Team
end

local function IsVisible(part, character)
    local origin = Camera.CFrame.Position
    local ignore = {LocalPlayer.Character}
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    for _ = 1, 10 do
        params.FilterDescendantsInstances = ignore
        local result = workspace:Raycast(origin, part.Position - origin, params)
        if not result then return true end

        local hit = result.Instance
        if hit:IsDescendantOf(character) then return true end

        local model = hit:FindFirstAncestorOfClass("Model")
        if hit.Transparency >= 0.9 or hit.CanCollide == false or (model and model:FindFirstChildOfClass("Humanoid")) then
            table.insert(ignore, hit)
        else
            return false
        end
    end
    return false
end

local lastLog = 0
local function Log(...)
    if Settings.Debug and tick() - lastLog > 1 then
        lastLog = tick()
        print("[Aimbot]", ...)
    end
end

local function Aim()
    if not Settings.Aimbot then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    Camera = workspace.CurrentCamera
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local target, closest = nil, Settings.FOVSize
    local seen, onScreen, inFov, visible = 0, 0, 0, 0

    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char then
            local part = GetAimPart(char)
            local hum = char:FindFirstChildOfClass("Humanoid")
            if part then
                seen += 1
                if Settings.KillCheck and hum and hum.Health <= 0 then continue end
                if Settings.TeamCheck and SameTeam(p) then continue end

                local pos, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    onScreen += 1
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < closest then
                        inFov += 1
                        if IsVisible(part, char) then
                            visible += 1
                            closest = d
                            target = part
                        end
                    end
                end
            end
        end
    end

    Log("players:", seen, "onscreen:", onScreen, "inFOV:", inFov, "visible:", visible, "target:", target and target.Parent.Name or "none")

    if target then
        local lookAt = CFrame.lookAt(Camera.CFrame.Position, target.Position)
        Camera.CFrame = Camera.CFrame:Lerp(lookAt, Settings.Smoothness)
    end
end

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Last.Value + 1, Aim)
