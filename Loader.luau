local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

-- Load the clean base library
local AnimationLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/animationlib.lua"))()

-- Extend the constructor to initialize the modules table dynamically
local originalNew = AnimationLib.new
function AnimationLib.new(config)
    local self = originalNew(config)

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
                    local deathConn
                    deathConn = humanoid.Died:Connect(function()
                        if self.Modules.WalkFling.Enabled then
                            self:ToggleModule("WalkFling")
                        end
                        deathConn:Disconnect()
                    end)
                end

                self:_startWalkFling(character, root)
            end,
            Stop = function()
                self:_stopWalkFling()
            end
        }
    }

    return self
end

-- Inject the exploit-specific methods into the library class prototype
function AnimationLib:_startWalkFling(character, root)
    self._walkFlingActive = true
    local movel = 0.1

    task.spawn(function()
        while self._walkFlingActive do
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
    end)
end

function AnimationLib:_stopWalkFling()
    self._walkFlingActive = false
    task.defer(function()
        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            root.Velocity = Vector3.new()
        end
    end)
end

function AnimationLib:_startFly()
    local flySpeed = 50
    self._flyingConn = RunService.Stepped:Connect(function()
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
    table.insert(self.Connections, self._flyingConn)
end

function AnimationLib:_stopFly()
    if self._flyingConn then
        self._flyingConn:Disconnect()
        self._flyingConn = nil
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

-- Initialize the extended library
local animController = AnimationLib.new({
    Actions = {
        {
            Name = "ToggleFlyKey",
            Key = Enum.KeyCode.X,
            Callback = function(lib)
                lib:ToggleModule("Fly")
                print("Fly toggled")
            end
        },
        {
            Name = "ToggleFlingKey",
            Key = Enum.KeyCode.Z,
            Callback = function(lib)
                lib:ToggleModule("WalkFling")
                print("WalkFling toggled")
            end
        }
    }
})

-- Animation replacements can also be safely applied here
animController:AddOverride(
    "rbxassetid://913403248", -- Target Walk Anim
    "rbxassetid://507771019", -- Replacement Anim
    "CustomWalk"
)
