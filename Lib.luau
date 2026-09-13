local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local AnimationLib = {}
AnimationLib.__index = AnimationLib

-- Resolves asset ID to actual Animation instance ID (safe: GetObjects can throw)
local function anim2track(asset_id)
    local ok, objs = pcall(function()
        return game:GetObjects(asset_id)
    end)

    if ok and objs then
        for i = 1, #objs do
            if objs[i]:IsA("Animation") then
                return objs[i].AnimationId
            end
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

    -- Per-instance character state (was previously shared module upvalues)
    self.Character = nil
    self.Humanoid = nil
    self.Animator = nil

    self:_bindCharacter(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())
    self:_setupCharacter()
    self:_setupKeybinds()

    return self
end

-- Wires up Character/Humanoid/Animator + the override-listening connection
-- for whichever character is currently active.
function AnimationLib:_bindCharacter(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid")
    self.Animator = self.Humanoid:WaitForChild("Animator")

    local overrideConn = self.Animator.AnimationPlayed:Connect(function(track)
        self:_handleOverride(track)
    end)
    table.insert(self.Connections, overrideConn)
end

-- Actually applies the Overrides table: if the animation that just started
-- playing matches a registered override target, stop it and play the
-- replacement instead.
function AnimationLib:_handleOverride(track)
    local animId = track.Animation and track.Animation.AnimationId
    if not animId then return end

    local override = self.Overrides[animId]
    if override and override.Track then
        track:Stop(0)
        override.Track:Play(0, track.WeightTarget, track.Speed)
        self.CurrentTrack = override.Track
    end
end

function AnimationLib:_setupCharacter()
    local charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        self.Tracks = {}
        self:_bindCharacter(newChar)
    end)
    table.insert(self.Connections, charConn)
end

function AnimationLib:LoadTrack(name, assetId)
    local resolvedId = anim2track(assetId)

    -- Avoid leaking a previously loaded track under the same name
    local existing = self.Tracks[name]
    if existing then
        existing:Stop(0)
        existing:Destroy()
    end

    local anim = Instance.new("Animation")
    anim.AnimationId = resolvedId

    local track = self.Animator:LoadAnimation(anim)
    self.Tracks[name] = track
    return track
end

function AnimationLib:PlayTrack(name, fadeTime, weight, speed)
    local track = self.Tracks[name]
    if track and track:IsA("AnimationTrack") then
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

function AnimationLib:_setupKeybinds()
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
