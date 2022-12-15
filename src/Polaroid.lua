local StarterGui = game:GetService('StarterGui');
local GuiService = game:GetService('GuiService');
local RunService = game:GetService('RunService');

export type SelfieConfiguration = {
    OverlayObject: GuiObject?;
    CameraButtonIcon: string?;
    CloseAfterShotTaken: boolean?;
    CameraButtonPosition: UDim2?;
    CloseButtonOffset: UDim2?;
};

export type PolaroidType = {
    SetEnabled: (IsEnabled: boolean) -> nil;
    MapButtonTo: (OverlayObject: GuiObject) -> nil;
    Destroy: () -> nil;
}

return function(Configuration: SelfieConfiguration?): PolaroidType
    local ScreenshotHud = GuiService:WaitForChild("ScreenshotHud");

    local Polaroid = {};
    local Connections: { RBXScriptConnection } = {};

    local OverlayObject = Configuration and Configuration.OverlayObject;
    ScreenshotHud.ExperienceNameOverlayEnabled = false; -- Turn off the default text (place name)
	ScreenshotHud.CameraButtonPosition = Configuration and Configuration.CameraButtonPosition or UDim2.fromScale(.5, .95);
	ScreenshotHud.CloseButtonPosition = ScreenshotHud.CameraButtonPosition - (Configuration and Configuration.CloseButtonOffset or UDim2.fromScale(0.035, 0));
	ScreenshotHud.CloseWhenScreenshotTaken = if Configuration and Configuration.CloseAfterShotTaken ~= nil then Configuration.CloseAfterShotTaken else true; -- Defaults to true

    local CoreGuiTypes = {};

    function Polaroid:SetEnabled(IsEnabled: boolean)
        ScreenshotHud.Visible = IsEnabled;

        for _, CoreEnum in pairs(Enum.CoreGuiType:GetEnumItems()) do
            if CoreEnum ~= Enum.CoreGuiType.All then
                if IsEnabled then
                    CoreGuiTypes[CoreEnum] = StarterGui:GetCoreGuiEnabled(CoreEnum);
                end

                StarterGui:SetCoreGuiEnabled(CoreEnum, if IsEnabled then false else CoreGuiTypes[CoreEnum]);
            end
        end
    end

    function Polaroid:MapButtonTo(_OverlayObject: GuiObject)
        OverlayObject = _OverlayObject;
    end

    function Polaroid:Destroy()
        for _, Connection in pairs(Connections) do
            Connection:Disconnect();
        end

        table.clear(Connections);
        table.clear(Polaroid);
    end

    table.insert(Connections, RunService.RenderStepped:Connect(function()
        if OverlayObject then
            local Offset = OverlayObject.AbsoluteSize / 2;
            local Position = OverlayObject.AbsolutePosition + Offset;
            ScreenshotHud.CameraButtonPosition = UDim2.fromOffset(Position.X, Position.Y);
            ScreenshotHud.CloseButtonPosition = ScreenshotHud.CameraButtonPosition - (Configuration and Configuration.CloseButtonOffset or UDim2.fromScale(0.035, 0));
        end
    end))

    return Polaroid :: PolaroidType;
end