--[[
    --[ The Polaroid Capture Instance API ]--
        Polaroid: {
            OnCapture: typeof(Signal.new()) 
                Signals when a photo is successfully taken and sends a reference of the Capture.
                This was left exposed in-case the developer wishes to do anything externally with the Capture.
                
            Hide: () -> ()
                Used to turn the visibility of the User Interface off.
                
            Show: () -> ()
                Used to turn the visibility of the User Interface on.
            
            Destroy: () -> ()
                A function that is used to clean up the Polaroid Capture Instance and any correlating UI.
        }
        
        Capture Hierarchy
            ImageLabel -> named "Capture: #" Where # is a number that grows with the number of captures taken.
                Background -> This is the Polaroid Frame and shouldn't be subject to changes. (Changing make break the terms of use)
                    View -> ViewportFrame Allows for changing in some Lighting Characteristics, and currently is the only way to Pseudo-Render Models on the Roblox Platform.
                        WorldModel -> An unnecessary measure as of the latest update, originally intended for use with Animations however due to roblox's handling of animations "Pose's" are set internally as a work around.
    
    
    --[ Example Usage ]--        
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
]]