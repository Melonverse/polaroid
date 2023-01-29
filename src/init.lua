--!strict
--!optimize 2
local RunService = game:GetService('RunService');
local TweenService = game:GetService('TweenService');
local PlayerService = game:GetService('Players');
local Lighting = game:GetService('Lighting');

local Skybox = Lighting:FindFirstChildOfClass("Sky");
local BackgroundImage = if Skybox then Skybox.SkyboxFt else "rbxassetid://653719321";

local Signal = require(script.Libs.Signal);
local Trove = require(script.Libs.Trove);
local Wheel = require(script.Libs.ColorWheel);
local Animationizer = require(script.Libs.Animationizer);

local Hud = script.UI.Polaroid;
local PictureTemplate = script.UI.Template;

export type Polaroid = {
	OnCapture: typeof(Signal);
	Destroy: (self: Polaroid?) -> ();
}

local function GetPoints(Object: BasePart | Model)
	local Center: CFrame, Size: Vector3 = Object:GetPivot(), if Object:IsA("Model") then Object:GetExtentsSize() else Object.Size;

    local NewVectors = {
		Vector3.new(1, 1, 1);
		Vector3.new(1, -1, 1);
		Vector3.new(1, 1, -1);
		Vector3.new(1, -1, -1);

        Vector3.new(-1, 1, 1);
		Vector3.new(-1, -1, 1);
		Vector3.new(-1, 1, -1);
		Vector3.new(-1, -1, -1);
	};

    local Points = {};

    table.foreach(NewVectors, function(Index, Vector)
		Points[Index] = (Center + Center:Inverse():VectorToObjectSpace(Vector * Size/2)).Position;
	end)

    return Points;
end

return function()
	if not RunService:IsClient() then
		warn("Polaroid Instance can't be ran on the Server!");
		return
	end

    local Player = PlayerService.LocalPlayer;
	local Character = Player.Character;

    if not Character then
		warn("Please try again when the Character Instance is finished");
		return
	end

    local Cleaner = Trove.new();
	local Cleaner2 = Cleaner:Add(Trove.new(), "Destroy");
	local Animator = Cleaner:Add(Animationizer(Character), "Destroy");

    local Camera = workspace.CurrentCamera;
	local Humanoid = Character:WaitForChild("Humanoid");

    Cleaner:AttachToInstance(Humanoid);
	local Head = Character:WaitForChild("Head");

	local PlayerGui = Player.PlayerGui;

    local ScreenGui = Hud:Clone();
	ScreenGui.Parent = PlayerGui;
	Cleaner:Add(ScreenGui, "Destroy");

    local Main = ScreenGui:FindFirstChild("Main");
	local Inventory = ScreenGui:FindFirstChild("Inventory");

    local Polaroid = {
		OnCapture = Signal.new();
	};

    local Captures : { GuiObject } = {};

    local function GetObjectsInView()
		local ObjectsInView: {{ Position: Vector3, Object: Instance & (Model | BasePart) }} = {};

        local function AlreadyInView(Object: BasePart | Model)
			for _, ObjectInView in pairs(ObjectsInView) do
				if Object == ObjectInView.Object or Object:IsDescendantOf(ObjectInView.Object) then
					return true;
				end
			end 
			return false;
		end

        local function CheckChildren(Parent: any)
			for _, Object in pairs(Parent:GetChildren()) do
				if not Object:IsA("Terrain") and (Object:IsA("Model") or Object:IsA("BasePart")) then
					Object = Object :: (Model | BasePart);
					local Points = GetPoints(Object);

					for _, Point in pairs(Points) do
						if AlreadyInView(Object) then
							break
						end

						local Check = false;			
						for _, Point2 in pairs(Points) do
							if Point ~= Point2 then
								for Interval = 0, 1, .1 do
									if Check then
										break
									end

									local PointToObserve = Point:Lerp(Point2, Interval);
									local ViewportPosition, InView = Camera:WorldToViewportPoint(PointToObserve);

									if InView then
										Check = true;
										table.insert(ObjectsInView, { Position = ViewportPosition, Object = Object });
									end								
								end
							end
						end
					end
				else
					CheckChildren(Object);
				end
			end
		end

        CheckChildren(workspace);

        return ObjectsInView;
	end

    local Controls = ScreenGui:WaitForChild("Controls");
	local Debounce = false;

    local function Capture()
		if Debounce == false then
			Debounce = true;

            local Objects = GetObjectsInView();
			local Picture = PictureTemplate:Clone();
			local Background = Picture:FindFirstChild("Background");

            Background.Image = BackgroundImage;
			local ClonedCamera = Camera:Clone();

            local View = Background:FindFirstChildOfClass("ViewportFrame");
			local World = View:FindFirstChildOfClass("WorldModel");

			if #Objects > 0 then
				for _, ObjectInfo in pairs(Objects) do
					pcall(function()
						local Origin = ObjectInfo.Object;
						local Archivable = Origin.Archivable;

                        Origin.Archivable = true;
						local Object = Origin:Clone();
						Origin.Archivable = Archivable;

                        for _, Descendant in pairs(Object:GetDescendants()) do
							if Descendant:IsA("BasePart") then
								Descendant.Anchored = true;
							elseif Descendant:IsA("LocalScript") then
								Descendant.Disabled = true;
								Descendant:Destroy();
							end
						end

                        Object.Parent = World;
					end)
				end
			end

            View.CurrentCamera = ClonedCamera;
			ClonedCamera.Parent = View;

            local Index = #Captures + 1;
			Picture.Name = string.format("Capture: #%d", Index);

            table.insert(Captures, Index, Picture);
			Picture.Visible = true;
			Picture.Parent = ScreenGui;
			Controls.Visible = true;

            local Tween = TweenService:Create(Picture, TweenInfo.new(2, Enum.EasingStyle.Circular), {
				Position = UDim2.fromScale(.99, .55);
				Size = UDim2.fromScale(0, 0);
			});

            local Cancelled = false;

            Cleaner2:Add(function()
				if not Cancelled then
					Polaroid.OnCapture:Fire(Picture);
					Picture.Parent = ScreenGui.Inventory;
				else
					table.remove(Captures, Index);
					Picture:Destroy();
				end

                Controls.ColorPicker.Visible = false;
				Controls.Visible = false;
				Debounce = false;
			end);

            Cleaner2:Connect(Controls.Panel.Confirm.Activated, function(Input)
				Tween:Play();
				Tween.Completed:Wait();
				Cleaner2:Clean();
			end)

            Cleaner2:Connect(Controls.Panel.Cancel.Activated, function(Input)
				Cancelled = true;
				Tween:Play();
				Tween.Completed:Wait();
				Cleaner2:Clean();
			end)

            local ColorWheel = nil;
			local Activated = {
				false, false
			}

            local Cleaner3 = Cleaner2:Add(Trove.new(), "Destroy");

            Cleaner2:Connect(Controls.Panel.Ambient.Activated, function(Input)
				local Bool = not Activated[1];

                if Bool then
					Activated[2] = false;

                    if ColorWheel then
						ColorWheel:Destroy();
						ColorWheel = nil;
					end

                    Controls.ColorPicker.Visible = true;
					ColorWheel = Cleaner3:Add(Wheel(Controls.ColorPicker), "Destroy");

                    Cleaner3:Connect(ColorWheel.OnUpdate, function(Color)
						View.Ambient = Color;
					end)

					Cleaner3:Connect(ColorWheel.OnCompleted, function(Color)
						View.Ambient = Color;
					end)
				else
					if ColorWheel then
						ColorWheel:Destroy();
						ColorWheel = nil;
					end

					Controls.ColorPicker.Visible = false;
				end

                Activated[1] = Bool;
			end)

            Cleaner2:Connect(Controls.Panel.Light.Activated, function(Input)
				local Bool = not Activated[2];

                if Bool then
					Activated[1] = false;

                    if ColorWheel then
						ColorWheel:Destroy();
						ColorWheel = nil;
					end

                    Controls.ColorPicker.Visible = true;

					ColorWheel = Cleaner3:Add(Wheel(Controls.ColorPicker), "Destroy");

                    Cleaner3:Connect(ColorWheel.OnUpdate, function(Color) 
						View.LightColor = Color;
					end)

                    Cleaner3:Connect(ColorWheel.OnCompleted, function(Color) 
						View.LightColor = Color;
					end)
				else
					if ColorWheel then
						ColorWheel:Destroy();
						ColorWheel = nil;
					end

                    Controls.ColorPicker.Visible = false;
				end

                Activated[2] = Bool;
			end)
		end
	end

    function Polaroid.Destroy(self: Polaroid?)
		Cleaner:Destroy();
		table.clear(Polaroid);
	end

    local IsActive = false;
	local Count = 1;

    for _, Pose in pairs(script.Poses:GetChildren()) do
		local Animation = Animator:LoadSequence(Pose);

        local Button = script.UI.TemplatePose:Clone();
		Button.Name = Pose.Name;
		Button.LayoutOrder = Count;
		Button.Visible = true;
		Button.Parent = ScreenGui.Main.PosePanel;

        Cleaner:Connect(Button.Activated, function(Input)
			if Animation:IsPlaying() then
				Animation:Stop();
			else
				for _, Track in pairs(Animator:GetPlayingTracks()) do
					if Track:IsPlaying() then
						Track:Stop();
					end
				end

                Animation:Play();
			end
		end)

        Count += 1;
	end

	Cleaner:Connect(Main.Action.Activated, function(Input)
		if not IsActive then
			IsActive = true;
			Main.Close.Visible = true;
			Main.View.Visible = true;
			Main.Poses.Visible = true;

            Camera.CameraType = Enum.CameraType.Scriptable;

            Cleaner:BindToRenderStep("PolaroidManipulation", Enum.RenderPriority.Camera.Value, function()
				local Cframe = Head.CFrame;
				Camera.CFrame = Cframe * CFrame.new(0, 0, -5) * CFrame.fromEulerAnglesXYZ(0, math.rad(180), 0);
			end)
		else
			task.spawn(Capture);
		end
	end)

    local function DisablePolaroid()
		IsActive = false;

        if ScreenGui.Parent ~= nil then
			if Main then
				Main.Close.Visible = false;
				Main.View.Visible = false;
				Main.Poses.Visible = false;
				Main.PosePanel.Visible = true;
			end

            if Inventory then
				Inventory.Visible = false;
			end

            if Controls then
				Controls.Visible = false;
			end
		end
		Cleaner2:Clean();
		RunService:UnbindFromRenderStep("PolaroidManipulation");
		task.wait();
		Camera.CameraType = Enum.CameraType.Custom;
	end

    Cleaner:Connect(Main.Close.Activated, function(Input)
		if IsActive then
			DisablePolaroid();
		end
	end)

    Cleaner:Connect(Main.View.Activated, function(Input)
		if Inventory then
			Inventory.Visible = not Inventory.Visible;
		end
	end)

    Cleaner:Connect(Main.Poses.Activated, function(Input)
		if Main.Poses.Visible then
			Main.Poses.Visible = false;
			Main.PosePanel.Visible = true;
		end
	end)

	Cleaner:Connect(Main.PosePanel.Close.Activated, function(Input)
		if not Main.Poses.Visible then
			Main.Poses.Visible = true;
			Main.PosePanel.Visible = false;
		end
	end)

    Cleaner:Add(DisablePolaroid);
    Cleaner:Connect(Humanoid.Died, function()
		Polaroid:Destroy();
	end)

	return Polaroid :: Polaroid;
end