Polaroid Capture Instance

Example Use:
```
local PlayerService = game:GetService('Players');
local ReplicatedStorage = game:GetService('ReplicatedStorage');
local Polaroid = require(ReplicatedStorage.Polaroid);

local Player = PlayerService.LocalPlayer;

if not Player:HasAppearanceLoaded() then
    Player.CharacterAppearanceLoaded:Wait();
end

local Camera = Polaroid({ MaxInstances = 50 }); -- MaxInstances is completely optional and defaults to 50.

Camera.OnCapture:Connect(function(Capture)
    print(Capture.Name);
end)

task.delay(5, Camera.Hide);
task.delay(10, Camera.Show);
```
