SelfieMode Screenshot Module

Example Use:
```
local ReplicatedStorage = game:GetService('ReplicatedStorage');

local SelfieMode = require(ReplicatedStorage.SelfieMode);

local Controller = SelfieMode({
	CloseAfterShotTaken = false;
})

task.wait(5);

Controller:SetEnabled(true);
```