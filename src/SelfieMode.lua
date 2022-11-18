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

export type SelfieMode = {
    SetEnabled: (IsEnabled: boolean) -> nil;
    MapButtonTo: (OverlayObject: GuiObject) -> nil;
    Destroy: () -> nil;
}

return function(Configuration: SelfieConfiguration?): SelfieMode
    local ScreenshotHud = GuiService:WaitForChild("ScreenshotHud");

    local SelfieMode = {};
    local Connections: { RBXScriptConnection } = {};

    local OverlayObject = Configuration.OverlayObject;
    ScreenshotHud.CameraButtonPosition = Configuration.CameraButtonPosition or UDim2.fromScale(.5, .95);
    ScreenshotHud.CloseButtonPosition = ScreenshotHud.CameraButtonPosition - (Configuration.CloseButtonOffset or UDim2.fromScale(0.035, 0));
    ScreenshotHud.CloseWhenScreenshotTaken = if Configuration.CloseAfterShotTaken ~= nil then Configuration.CloseAfterShotTaken else true; -- Defaults to true

    local CoreGuiTypes = {};

    function SelfieMode:SetEnabled(IsEnabled: boolean)
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

    function SelfieMode:MapButtonTo(_OverlayObject: GuiObject)
        OverlayObject = _OverlayObject;
    end

    function SelfieMode:Destroy()
        for _, Connection in pairs(Connections) do
            Connection:Disconnect();
        end

        table.clear(Connections);
        table.clear(SelfieMode);
    end

    table.insert(Connections, RunService.RenderStepped:Connect(function()
        if OverlayObject then
            local Offset = OverlayObject.AbsoluteSize / 2;
            local Position = OverlayObject.AbsolutePosition + Offset;
            ScreenshotHud.CameraButtonPosition = UDim2.fromOffset(Position.X, Position.Y);
            ScreenshotHud.CloseButtonPosition = ScreenshotHud.CameraButtonPosition - (Configuration.CloseButtonOffset or UDim2.fromScale(0.035, 0));
        end
    end))

    return SelfieMode :: SelfieMode;
end