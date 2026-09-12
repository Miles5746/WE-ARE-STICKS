local AnimationLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Miles5746/WE-ARE-STICKS/refs/heads/main/Lib.luau"))()

-- Initialize the library with configured actions and keybinds
local animController = AnimationLib.new({
    Actions = {
        {
            Name = "EmoteAction",
            Key = Enum.KeyCode.E,
            AnimationId = "rbxassetid://507771019",
            FadeTime = 0.2,
            Weight = 1,
            Speed = 1,
            Callback = function(lib)
                print("Emote triggered via E key")
            end
        },
        {
            Name = "ToggleFlyKey",
            Key = Enum.KeyCode.X,
            Callback = function(lib)
                lib:ToggleModule("Fly")
                print("Fly module toggled")
            end
        },
        {
            Name = "ToggleFlingKey",
            Key = Enum.KeyCode.Z,
            Callback = function(lib)
                lib:ToggleModule("WalkFling")
                print("WalkFling module toggled")
            end
        }
    }
})

-- Animation Replacements / Overrides
-- Intercepts the target animation when it plays and overrides it with the replacement
animController:AddOverride(
    "rbxassetid://913403248", -- Default R15 walk animation
    "rbxassetid://507771019", -- Replacement animation (e.g., custom walk/emote)
    "CustomWalkOverride"
)

animController:AddOverride(
    "rbxassetid://913384386", -- Default R15 jump animation
    "rbxassetid://507770818", -- Replacement jump animation
    "CustomJumpOverride"
)

-- Load and play a standalone track manually
--animController:LoadTrack("Salute", "rbxassetid://507770818")
--animController:PlayTrack("Salute", 0.2, 1, 1)
