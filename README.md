SelfieMode Screenshot Module

Example Use:
```
local ReplicatedStorage = game:GetService('ReplicatedStorage');

local Polaroid = require(ReplicatedStorage.Polaroid);

local PolaroidController = Polaroid({
	CloseAfterShotTaken = false;
})

task.wait(5);

PolaroidController:SetEnabled(true);
```
