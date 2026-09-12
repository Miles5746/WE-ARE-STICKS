local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

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
    self.Connections = {}
    self.CurrentTrack = nil

    -- Placeholders for built-in modules
    self.Modules = {
        Fly = {
            Enabled = false,
            Start = function()
                -- Add fly implementation here
            end,
            Stop = function()
                -- Add fly cleanup here
            end
        },
        WalkFling = {
            Enabled = false,
            Start = function()
                -- Add walkfling implementation here
            end,
            Stop = function()
                -- Add walkfling cleanup here
            end
        }
    }

    self:_setupCharacter()
    self:_setupKeybinds()

    return self
end

function AnimationLib:_setupCharacter()
    -- Rebind animator reference when character respawns
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
    if track then
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
        conn:Disconnect()
    end
    for _, track in pairs(self.Tracks) do
        track:Stop()
        track:Destroy()
    end
    table.clear(self.Tracks)
    table.clear(self.Connections)
end

return AnimationLib
