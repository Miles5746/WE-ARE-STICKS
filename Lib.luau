local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Animator = Humanoid:WaitForChild("Animator")

local AnimationLib = {}

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
    local self = {}
    self.Config = config or {}
    self.Tracks = {}
    self.Overrides = {}
    self.Connections = {}
    self.CurrentTrack = nil

    -- Copy all library methods directly to this instance
    for key, val in pairs(AnimationLib) do
        if type(val) == "function" and key ~= "new" then
            self[key] = val
        end
    end

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

    local track = Animator:LoadAnimation(anim)
    self.Tracks[name] = track
    return track
end

function AnimationLib:PlayTrack(name, fadeTime, weight, speed)
    local track = self.Tracks[name]
    if track and typeof(track) == "Instance" and track:IsA("AnimationTrack") then
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
    oldLoadAnimation = hookfunction(Instance.new("Animator").LoadAnimation, function(selfObj, ...)
        local animArg = select(1, ...)
        local animId = nil

        if typeof(animArg) == "Instance" and animArg:IsA("Animation") then
            animId = animArg.AnimationId
        elseif type(animArg) == "string" then
            animId = animArg
        end

        if animId then
            local override = AnimationLib._activeInstance and AnimationLib._activeInstance.Overrides[animId]
            if override and override.Track and typeof(override.Track) == "Instance" and override.Track:IsA("AnimationTrack") then
                task.spawn(function()
                    if not override.Track.IsPlaying then
                        override.Track:Play(0.1, 1, 1)
                    end
                end)
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

function AnimationLib:Destroy()
    for _, conn in ipairs(self.Connections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
    table.clear(self.Connections)

    for _, track in pairs(self.Tracks) do
        if typeof(track) == "Instance" and track:IsA("AnimationTrack") then
            track:Stop()
            track:Destroy()
        end
    end
    table.clear(self.Tracks)
    table.clear(self.Overrides)
end

return AnimationLib
