local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Settings = {
    Aimbot = false,
    Smoothness = 0.5,
    FOVSize = 10,
    AimPart = "Head",
    TeamCheck = true,
    KillCheck = true,
}

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.T then
        Settings.Aimbot = not Settings.Aimbot
        print("Aimbot:", Settings.Aimbot)
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
        local isPlayerPart = model and model:FindFirstChildOfClass("Humanoid")
        if hit.Transparency >= 0.9 or isPlayerPart then
            table.insert(ignore, hit)
        else
            return false
        end
    end
    return false
end

RunService:BindToRenderStep("AimbotLoop", Enum.RenderPriority.Camera.Value + 1, function()
    if not Settings.Aimbot then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    Camera = workspace.CurrentCamera
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local target, closest = nil, Settings.FOVSize

    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if p ~= LocalPlayer and char then
            local part = GetAimPart(char)
            local hum = char:FindFirstChildOfClass("Humanoid")
            if part then
                if Settings.KillCheck and (not hum or hum.Health <= 0) then continue end
                if Settings.TeamCheck and SameTeam(p) then continue end

                local pos, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if d < closest and IsVisible(part, char) then
                        closest = d
                        target = part
                    end
                end
            end
        end
    end

    if target then
        local lookAt = CFrame.lookAt(Camera.CFrame.Position, target.Position)
        Camera.CFrame = Camera.CFrame:Lerp(lookAt, Settings.Smoothness)
    end
end)
