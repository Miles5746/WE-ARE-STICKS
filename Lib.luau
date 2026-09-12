local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Animator = Humanoid:WaitForChild("Animator")

local AnimationLib = {}
AnimationLib.__index = AnimationLib

-- Resolves asset ID to actual Animation instance ID
local function anim2track(asset_id)
    local objs = game:GetObjects(asset_id)
    for i = 1, #objs do
        if objs[i]:IsA("Animation") then
            return objs[i].AnimationId
        end
    end
    return asset_id
end

function AnimationLib.new(config)
    local self = setmetatable({}, AnimationLib)
    self.Config = config or {}
    self.Tracks = {}
    self.Overrides = {}
    self.Connections = {}
    self.CurrentTrack = nil

    self.Modules = {
        Fly = {
            Enabled = false,
            Start = function()
                self:_startFly()
            end,
            Stop = function()
                self:_stopFly()
            end
        },
        WalkFling = {
            Enabled = false,
            Start = function()
                local character = LocalPlayer.Character
                local root = character and character:FindFirstChild("HumanoidRootPart")
                local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")

                if humanoid then
                    humanoid.Died:Connect(function()
                        self:ToggleModule("WalkFling")
                    end)
                end

                self:_startWalkFling(character, root)
            end,
            Stop = function()
                self:_stopWalkFling()
            end
        }
    }

    self:_setupCharacter()
    self:_setupKeybinds()
    self:_setupOverrides()

    return self
end

function AnimationLib:_setupCharacter()
    local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        Animator = Humanoid:WaitForChild("Animator")
        self.Tracks = {}
    end)
    table.insert(self.Connections, charConn)
end

function AnimationLib:LoadTrack(name, assetId)
    local resolvedId = anim2track(assetId)
    local anim = Instance.new("Animation")
    anim.AnimationId = resolvedId

    local track = Animator:LoadAnimation(anim.AnimationId)
    self.Tracks[name] = track
    return track
end

function AnimationLib:PlayTrack(name, fadeTime, weight, speed)
    local track = self.Tracks[name]
    if track and track.IsA and track:IsA("Animation") then
        track:Play(fadeTime or 0.1, weight or 1, speed or 1)
        self.CurrentTrack = track
        return track
    end
    return nil
end

function AnimationLib:StopTrack(name, fadeTime)
    if name and self.Tracks[name] then
        self.Tracks[name]:Stop(fadeTime or 0.1)
    elseif self.CurrentTrack then
        self.CurrentTrack:Stop(fadeTime or 0.1)
    end
end

function AnimationLib:AddOverride(targetAssetId, replacementAssetId, name)
    local resolvedTarget = anim2track(targetAssetId)
    local trackName = name or ("Override_" .. tostring(math.random(1000, 9999)))
    local track = self:LoadTrack(trackName, replacementAssetId)

    self.Overrides[resolvedTarget] = {
        Track = track,
        Name = trackName
    }
end

function AnimationLib:_setupOverrides()
    local oldLoadAnimation
    oldLoadAnimation = hookmetamethod(Animator, "__namecall", function(selfObj, ...)
        local method = getnamecallmethod()
        if selfObj == Animator and method == "LoadAnimation" then
            local animInstance = select(1, ...)
            if animInstance and animInstance:IsA("Animation") then
                local animId = animInstance.AnimationId
                local override = AnimationLib._activeInstance and AnimationLib._activeInstance.Overrides[animId]

                if override then
                    task.spawn(function()
                        if not override.Track.IsPlaying then
                            override.Track:Play(0.1, 1, 1)
                        end
                    end)
                end
            end
        end
        return oldLoadAnimation(selfObj, ...)
    end)
end

function AnimationLib:_setupKeybinds()
    AnimationLib._activeInstance = self

    local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        local actions = self.Config.Actions
        if not actions then return end

        for _, action in ipairs(actions) do
            if input.KeyCode == action.Key then
                if action.AnimationId then
                    local trackName = action.Name or action.Key.Name
                    if not self.Tracks[trackName] then
                        self:LoadTrack(trackName, action.AnimationId)
                    end
                    self:PlayTrack(trackName, action.FadeTime, action.Weight, action.Speed)
                end

                if action.Callback then
                    action.Callback(self)
                end
            end
        end
    end)

    table.insert(self.Connections, inputConn)
end

function AnimationLib:_startWalkFling(character, root)
    local walkflinging = true
    local movel = 0.1

    while walkflinging do
        RunService.Heartbeat:Wait()

        if character and character.Parent and root and root.Parent then
            local vel = root.Velocity
            root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)

            RunService.RenderStepped:Wait()
            if character and character.Parent and root and root.Parent then
                root.Velocity = vel
            end

            RunService.Stepped:Wait()
            if character and character.Parent and root and root.Parent then
                root.Velocity = vel + Vector3.new(0, movel, 0)
                movel = movel * -1
            end
        end
    end
end

function AnimationLib:_stopWalkFling()
    local noclipConn = nil
    local walkflinging = false
    noclipConn = RunService.Stepped:Connect(function()
        if not walkflinging then
            noclipConn:Disconnect()
        end
        LocalPlayer.Character:FindFirstChild("HumanoidRootPart").Velocity = Vector3.new()
    end)
end

function AnimationLib:_startFly()
    local flyingConn = nil
    local flyingEnabled = true
    local flySpeed = 50

    flyingConn = RunService.Stepped:Connect(function()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if character and character.Parent and root and root.Parent then
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                root.Velocity = root.Velocity + Vector3.new(0, flySpeed, 0)
            elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                root.Velocity = root.Velocity + Vector3.new(0, -flySpeed, 0)
            end
        end
    end)

    table.insert(self.Connections, flyingConn)
end

function AnimationLib:_stopFly()
    for _, conn in ipairs(self.Connections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
end

function AnimationLib:ToggleModule(name)
    local mod = self.Modules[name]
    if mod then
        mod.Enabled = not mod.Enabled
        if mod.Enabled then
            mod.Start()
        else
            mod.Stop()
        end
    end
end

function AnimationLib:Destroy()
    for _, conn in ipairs(self.Connections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(self.Connections)

    for _, track in pairs(self.Tracks) do
        if track and track.IsA and track:IsA("Animation") then
            track:Stop()
            track:Destroy()
        end
    end
    table.clear(self.Tracks)
    table.clear(self.Overrides)
end

return AnimationLib
