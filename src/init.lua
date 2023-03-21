--!strict
--!optimize 2
local RunService = game:GetService('RunService');
local PlayerService = game:GetService('Players');
local Lighting = game:GetService('Lighting');

local UIFolder = script:WaitForChild("UI");
local PosesFolder = script:WaitForChild("Poses");
local Libs = script:WaitForChild("Libs");

local Skybox = Lighting:FindFirstChildOfClass("Sky");
local BackgroundImage = if Skybox then Skybox.SkyboxFt else "rbxassetid://653719321";

local Signal = require(Libs.Signal);
local Trove = require(Libs.Trove);
local Wheel = require(Libs.ColorWheel);
local Animationizer = require(Libs.Animationizer);
local State = require(Libs.State);
local Filters = require(Libs.Filters);

local Hud = UIFolder:FindFirstChild("PolaroidUI");
local PictureTemplate = UIFolder:FindFirstChild("TemplateCapture");
local PoseTemplate = UIFolder:FindFirstChild("TemplatePose");
local FilterTemplate = UIFolder:FindFirstChild("TemplateFilter");

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

	for Index, Vector in pairs(NewVectors) do
		Points[Index] = Center:PointToWorldSpace(Vector * Size/2);
	end

	return Points;
end

export type Polaroid = {
	OnCapture: typeof(Signal.new());
	Show: () -> ();
	Hide: () -> ();
	Destroy: () -> ();
}

export type PolaroidConfig = {
	MaxInstances: number?
}

return function(Configurations: PolaroidConfig?): Polaroid?
	if not RunService:IsClient() then
		warn("Polaroid Instance can't be ran on the Server!");
		return
	end

	local MAX_INSTANCES = if Configurations and Configurations.MaxInstances then Configurations.MaxInstances else 50;

	local Player = PlayerService.LocalPlayer;
	local Character = Player.Character;

	if not Character or not Character:IsDescendantOf(workspace) then
		warn("Character must exist and be a descendant of workspace.");
		return
	end

	local Cleaner = Trove.new();
	local Cleaner2 = Cleaner:Add(Trove.new(), "Destroy");
	local Animator = Cleaner:Add(Animationizer(Character), "Destroy");

	local Camera = workspace.CurrentCamera;
	local Humanoid = Character:WaitForChild("Humanoid");

	Cleaner:AttachToInstance(Humanoid);
	local Hrp = Character:WaitForChild("HumanoidRootPart");

	local PlayerGui = Player.PlayerGui;	

	local ScreenGui: ScreenGui = Hud:Clone();
	ScreenGui.Parent = PlayerGui;
	Cleaner:Add(ScreenGui, "Destroy");

	local Main = ScreenGui:FindFirstChild("Main") :: Frame;
	local EditCapture = ScreenGui:FindFirstChild("EditCapture") :: Frame;
	local Gallery = ScreenGui:FindFirstChild("Gallery") :: ImageLabel;
	local Menu = ScreenGui:FindFirstChild("Menu") :: Frame;

	local CloseButton = Main:FindFirstChild("Close") :: ImageButton;
	local GalleryButton = Main:FindFirstChild("Gallery") :: ImageButton;
	local MenuButton = Main:FindFirstChild("Menu") :: ImageButton;
	local InteractButton = Main:FindFirstChild("Interact") :: ImageButton;

	local CloseMenu = Menu:FindFirstChild("Button", true) :: TextButton;

	local PictureFrame = EditCapture:FindFirstChild("Picture") :: Frame;
	local ConfirmButton = PictureFrame:FindFirstChild("Confirm") :: ImageButton;
	local CancelButton = PictureFrame:FindFirstChild("Cancel") :: ImageButton;

	local Controls = EditCapture:FindFirstChild("Controls") :: Frame;
	local ColorController = Controls:FindFirstChild("ColorController") :: Frame;
	local ContextController = Controls:FindFirstChild("ContextController") :: Frame;
	local Container = Controls:FindFirstChild("Container") :: ScrollingFrame;

	local Context = ContextController:FindFirstChild("Context") :: ImageLabel;
	local ContextPrev = ContextController:FindFirstChild("Previous") :: ImageButton;
	local ContextNext = ContextController:FindFirstChild("Next") :: ImageButton;
	local ContextLabel = Context:FindFirstChild("TextLabel") :: TextLabel;

	local InitialProps = {};

	local IsActive = false;
	local Debounce = false;

	local Contexts = {
		"Light Color";
		"Filter Color";
		"Filters"
	}

	for _, Descendant in pairs(ScreenGui:GetDescendants()) do
		if Descendant:IsA("GuiObject") then
			InitialProps[Descendant] = {};

			pcall(function()
				InitialProps[Descendant].Visible = Descendant.Visible;
			end)

			pcall(function()
				InitialProps[Descendant].Image = Descendant.Image;
			end)

			pcall(function()
				InitialProps[Descendant].Color = Descendant.Color;
			end)
		end
	end

	local FilterObjects = {};

	for FilterName, ImageId in pairs(Filters) do
		local Temp = FilterTemplate:Clone();
		Temp.Name = FilterName;
		Temp.FilterName.Text = FilterName;
		Temp.FilterImage.Image = ImageId;
		Temp.Parent = Container;
		FilterObjects[FilterName] = Temp;
	end

	local Polaroid = {};
	Polaroid.OnCapture = Signal.new();

	local Params = RaycastParams.new();
	Params.FilterType = Enum.RaycastFilterType.Exclude;
	Params.FilterDescendantsInstances = { Character }

	local Captures : { GuiObject } = {};

	local function GetObjectsInView()
		local ObjectsInView: { Instance & (Model | BasePart) } = {};

		local CameraPos = Camera.CFrame.Position;
		local LookDirection = Camera.CFrame.LookVector;

		local R = Ray.new(CameraPos, CameraPos + LookDirection * 9999);

		local function AlreadyInView(Object: Model | BasePart)
			for _, ObjectInView in pairs(ObjectsInView) do
				if Object == ObjectInView or Object:IsDescendantOf(ObjectInView) then
					return true;
				end
			end 
			return false;
		end

		local Descendants = {};

		for _, Object in pairs(workspace:GetDescendants()) do
			local Ancestor = Object:FindFirstAncestorOfClass("Model");
			if Ancestor then
				Object = Ancestor;
			end

			if not Object:IsA("Terrain") and not table.find(Descendants, Object) and (Object:IsA("BasePart") or Object:IsA("Model")) then
				table.insert(Descendants, Object);
			end
		end

		table.sort(Descendants, function(A, B) 
			local PA, PB = A:GetPivot().Position, B:GetPivot().Position;
			return R:ClosestPoint(PA).Magnitude < R:ClosestPoint(PB).Magnitude;
		end)

		for _, Object in pairs(Descendants) do
			local Points = GetPoints(Object);

			for _, Point in pairs(Points) do
				if AlreadyInView(Object) or #ObjectsInView > MAX_INSTANCES then
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
							local _, InView = Camera:WorldToViewportPoint(PointToObserve);

							if InView then
								Check = true;
								table.insert(ObjectsInView, Object);
							end
						end
					end
				end
			end
		end

		local Below = workspace:Raycast(Hrp.Position, Vector3.new(0, -20, 0), Params);

		if Below and Below.Instance and not AlreadyInView(Below.Instance) then
			table.insert(ObjectsInView, Below.Instance);
		end

		return ObjectsInView;
	end


	local function Capture()
		if Debounce == false then
			Debounce = true;

			local Objects = GetObjectsInView();
			local Picture = PictureTemplate:Clone();
			local Background = Picture:FindFirstChild("Background");

			local Colors = {
				["Light Color"] = Color3.fromRGB(255, 255, 255);
				["Filter Color"] = Color3.fromRGB(255, 255, 255);
			}

			local function ApplyFilter(FilterName)
				if not Picture or (FilterName == "Default" and Picture:FindFirstChild("Default")) then return end

				local Filter = Picture:GetAttribute("Filter");

				if Filter then
					local FO = Picture:FindFirstChild(Filter);
					if FO then
						FO:Destroy();
					end
				end

				if Filter ~= FilterName then
					Picture:SetAttribute("Filter", FilterName);
					local F = FilterObjects[FilterName].FilterImage:Clone();

					F.Name = FilterName;
					F.Position = UDim2.fromScale(0.5, 0.5);
					F.Size = UDim2.fromScale(0.9, 0.9);
					F.ImageTransparency = if FilterName ~= "Default" then 0 else 1;
					F.BackgroundTransparency = if FilterName ~= "Default" then 1 else 0.8;
					F.ImageColor3 = Colors["Filter Color"];
					F.BackgroundColor3 = Colors["Filter Color"];
					F.ZIndex = 4;
					F.Parent = Picture;
				elseif Filter ~= "Default" then
					ApplyFilter("Default");
				end
			end

			ApplyFilter("Default");

			Background.Image = BackgroundImage;
			local ClonedCamera = Camera:Clone();

			local View = Background:FindFirstChildOfClass("ViewportFrame");
			local World = View:FindFirstChildOfClass("WorldModel");

			if #Objects > 0 then
				for _, Object in pairs(Objects) do
					pcall(function()
						local Archivable = Object.Archivable;

						Object.Archivable = true;
						local Object = Object:Clone();
						Object.Archivable = Archivable;

						for _, Descendant in pairs(Object:GetDescendants()) do
							if Descendant:IsA("BasePart") then
								Descendant.Anchored = true;
							elseif Descendant:IsA("BaseScript") then
								Descendant.Disabled = true;
								Descendant:Destroy();
							end
						end

						Object.Parent = World;
					end)
				end
			end

			for _, Animation in pairs(Animator:GetPlayingTracks()) do
				Animation:Stop();
			end

			if Menu.Visible then
				MenuButton.Visible = true;
				Menu.Visible = false;
			end

			View.CurrentCamera = ClonedCamera;
			ClonedCamera.Parent = View;

			local Index = #Captures + 1;
			Picture.Name = string.format("Capture: #%d", Index);
			Picture.Visible = true;
			Picture.Parent = EditCapture:FindFirstChild("Picture");
			EditCapture.Visible = true;

			local Cancelled = false;

			Cleaner2:Add(function()
				if not Cancelled then
					Polaroid.OnCapture:Fire(Picture);
					Picture.Parent = Gallery:FindFirstChild("Frame");
					ColorController.Visible = false;
					table.insert(Captures, Index, Picture);
				else
					Picture:Destroy();
				end
				Debounce = false;
			end);

			Cleaner2:Connect(ConfirmButton.Activated, function()
				EditCapture.Visible = false;
				Cleaner2:Clean();
			end)

			Cleaner2:Connect(CancelButton.Activated, function()
				Cancelled = true;
				EditCapture.Visible = false;
				Cleaner2:Clean();
			end)

			local ColorWheel = nil;

			local Cleaner3 = Cleaner2:Add(Trove.new(), "Destroy");

			local State = Cleaner2:Add(State(""), "Destroy");

			Cleaner2:Add(State.OnChange:Connect(function(NewState, OldState)
				ContextLabel.Text = NewState;

				if table.find({"Light Color", "Filter Color"}, NewState) and not table.find({"Light Color", "Filter Color"}, OldState) then
					Cleaner3:Clean();

					Container.Visible = false;
					ColorController.Visible = true;

					ColorWheel = Cleaner3:Add(Wheel(ColorController), "Destroy");

					local Filter = Picture:FindFirstChild(Picture:GetAttribute("Filter"));

					Cleaner3:Connect(ColorWheel.OnUpdate, function(Color)
						local Prop = State:Get():gsub(" ", "");

						if Prop == "FilterColor" then
							Filter.ImageColor3 = Color;
							Filter.BackgroundColor3 = Color;
						else
							View.LightColor = Color;
						end

						Colors[Prop] = Color;
					end)

					Cleaner3:Connect(ColorWheel.OnCompleted, function(Color)
						local Prop = State:Get():gsub(" ", "");

						if Prop == "FilterColor" then
							Filter.ImageColor3 = Color;
							Filter.BackgroundColor3 = Color;
						else
							View.LightColor = Color;
						end

						Colors[Prop] = Color;
					end)
				elseif table.find({"Light Color", "Filter Color"}, OldState) and not table.find({"Light Color", "Filter Color"}, NewState) then
					Cleaner3:Clean();

					ColorController.Visible = false;
					Container.Visible = true;

					for Name, Object in pairs(FilterObjects) do
						Cleaner3:Connect(Object.Activated, function()
							ApplyFilter(Name);
						end)
					end
				end
			end), "Disconnect");

			Cleaner2:Connect(ContextNext.Activated, function()
				local Current : number? = table.find(Contexts, State:Get());
				State:Set(if Current and Current + 1 <= #Contexts then Contexts[Current + 1] else Contexts[1]);
			end)

			Cleaner2:Connect(ContextPrev.Activated, function()
				local Current : number? = table.find(Contexts, State:Get());
				State:Set(if Current and Current - 1 >= 1 then Contexts[Current - 1] else Contexts[#Contexts]);
			end)

			State:Set(Contexts[1]);
		end
	end

	Cleaner:Connect(InteractButton.Activated, function()
		if not IsActive then
			IsActive = true;
			CloseButton.Visible = true;
			MenuButton.Visible = true;
			GalleryButton.Visible = true;
			InteractButton.Image = "rbxassetid://12371606205";

			Camera.CameraType = Enum.CameraType.Scriptable;

			Cleaner:BindToRenderStep("PolaroidManipulation", Enum.RenderPriority.Camera.Value, function()
				local Cframe = Hrp.CFrame;
				Camera.CFrame = Cframe * CFrame.new(0, 1.5, -5) * CFrame.fromEulerAnglesXYZ(0, math.rad(180), 0);
			end)
		else
			task.spawn(Capture);
		end
	end)

	local function DisablePolaroid()
		IsActive = false;

		if ScreenGui.Parent ~= nil then
			for Object, Props in pairs(InitialProps) do
				pcall(function()
					Object.Visible = Props.Visible;
				end)

				pcall(function()
					Object.Image = Props.Image;
				end)

				pcall(function()
					Object.Color = Props.Color;
				end)
			end
		end

		Cleaner2:Clean();
		for _, Animation in pairs(Animator:GetPlayingTracks()) do
			Animation:Stop();
		end

		RunService:UnbindFromRenderStep("PolaroidManipulation");
		task.wait();
		Camera.CameraType = Enum.CameraType.Custom;
	end

	Cleaner:Connect(CloseButton.Activated, function()
		if IsActive then
			DisablePolaroid();
		end
	end)

	Cleaner:Connect(GalleryButton.Activated, function()
		if Gallery then
			Gallery.Visible = not Gallery.Visible;
		end
	end)

	Cleaner:Connect(MenuButton.Activated, function()
		if Menu and not Menu.Visible then
			Menu.Visible = true;
			MenuButton.Visible = false;
		end
	end)

	Cleaner:Connect(CloseMenu.Activated, function()
		if Menu and Menu.Visible then
			Menu.Visible = false;
			MenuButton.Visible = true;
		end
	end)

	Cleaner:Add(DisablePolaroid);

	for _, Pose in pairs(PosesFolder:GetChildren()) do
		local Animation = Cleaner:Add(Animator:LoadSequence(Pose), "Destroy");

		local PoseUI = PoseTemplate:Clone();
		local TextLabel = PoseUI:FindFirstChild("TextLabel") :: TextLabel;
		TextLabel.Text = Pose.Name;

		local Button = PoseUI:FindFirstChild("Button", true) :: TextButton;

		Cleaner:Connect(Animation.Playing, function()
			if Button.Parent and Button.Parent:IsA("Frame") then
				Button.Parent.BackgroundColor3 = Color3.fromRGB(255, 0, 0);
			end
			Button.Text = "Stop";
		end)

		Cleaner:Connect(Animation.Stopped, function()
			if Button.Parent and Button.Parent:IsA("Frame") then 
				Button.Parent.BackgroundColor3 = Color3.fromRGB(0, 255, 0);
			end
			Button.Text = "View";
		end)

		Cleaner:Connect(Button.Activated, function()
			for _, _Animation in pairs(Animator:GetPlayingTracks()) do
				if _Animation ~= Animation then
					_Animation:Stop();
				end
			end

			if Animation:IsPlaying() then
				Animation:Stop();
			else
				Animation:Play();
			end
		end)

		PoseUI.Parent = Menu:FindFirstChild("Frame");
	end

	function Polaroid.Hide()
		DisablePolaroid();
		if ScreenGui then			
			for Object in pairs(InitialProps) do			
				pcall(function()
					Object.Visible = false;
				end)
			end
		end
	end

	function Polaroid.Show()
		if ScreenGui then
			for Object, Properties in pairs(InitialProps) do
				pcall(function()
					Object.Visible = Properties.Visible;
				end)

				pcall(function()
					Object.Image = Properties.Image;
				end)

				pcall(function()
					Object.Color = Properties.Color;
				end)
			end
		end
	end

	function Polaroid.Destroy()
		Cleaner:Destroy();
		table.clear(Polaroid);
	end

	Cleaner:Connect(Humanoid.Died, function()
		task.defer(Polaroid.Destroy);
	end)

	--[[-[
		--[ The Polaroid Capture Instance API ]--
			Polaroid: {
				OnCapture: typeof(Signal.new())
					Signals when a photo is successfully taken and sends a reference of the Capture.
					This was left exposed in-case the developer wishes to do anything externally with the Capture.

				Hide: (self) -> ()
					Used to turn the visibility of the User Interface off.

				Show: (self) -> ()
					Used to turn the visibility of the User Interface on.

				Destroy: (self) -> ()
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

	return Polaroid;
end