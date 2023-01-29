local GuiService = game:GetService('GuiService');
local Trove = require(script.Parent.Trove);
local Signal = require(script.Parent.Signal);

return function(Container)
	local Wheel = Container:FindFirstChild("Wheel");
	local Slider = Container:FindFirstChild("Slider");

    if not Wheel or not Slider then
		warn("Container must have a Wheel and Slider");
		return
	end

	local Cleaner = Trove.new();

    local ColorWheel = {
		OnUpdate = Cleaner:Add(Signal.new(), "Destroy");
		OnCompleted = Cleaner:Add(Signal.new(), "Destroy");
	};

	local Color = Color3.fromRGB(255, 255, 255);
	local Hue = 1;
	local Sat = 1;
	local Value = 1;

	if Wheel:IsA("ImageButton") then
		local _Input = nil;
		local AbsolutePosition, AbsoluteSize = Wheel.AbsolutePosition, Wheel.AbsoluteSize;
		local Center = AbsolutePosition + AbsoluteSize/2;

		local function UpdateWheel(Position)
			Position = Vector2.new(Position.X, Position.Y);

			local DistanceFromCenter = (Center - Position).Magnitude;

			if DistanceFromCenter <= AbsoluteSize.X/2 then
				Wheel.Picker.Position = UDim2.fromScale(
					math.clamp((Position.X - AbsolutePosition.X)/AbsoluteSize.X, 0, 1),
					math.clamp((Position.Y - AbsolutePosition.Y)/AbsoluteSize.Y, 0, 1)
				);

				Hue = (math.pi - math.atan2(Position.Y - Center.Y, Position.X - Center.X)) / (math.pi * 2);
				Sat = (Position - Center).Magnitude / (AbsoluteSize.X / 2);
				Color = Color3.fromHSV(math.clamp(Hue, 0, 1), math.clamp(Sat, 0, 1), math.clamp(Value, 0, 1));
				ColorWheel.OnUpdate:Fire(Color);
			end
		end

		Cleaner:Connect(Wheel.InputBegan, function(Input) 
			if not _Input and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
				_Input = Input;
				UpdateWheel(Input.Position);	
			end
		end);

		Cleaner:Connect(Wheel.InputChanged, function(Input)
			if not _Input and Input.UserInputState == Enum.UserInputState.Begin and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
				_Input = Input;
				UpdateWheel(Input.Position);
			elseif _Input == Input then
				UpdateWheel(Input.Position);
			end
		end);

		Cleaner:Connect(Wheel.InputEnded, function(Input)
			if _Input == Input then
				_Input = nil;
				UpdateWheel(Input.Position);
				ColorWheel.OnCompleted:Fire(Color);
			end
		end);

        Cleaner:Connect(Wheel.MouseMoved, function(X, Y) 
			if _Input ~= nil then
				UpdateWheel(Vector2.new(X, Y) - GuiService:GetGuiInset());
			end
		end);
	end

    if Slider:IsA("ImageButton") then
		local Indicator = Slider:FindFirstChild("Indicator", true);

        local _Input = nil;
		local AbsolutePosition, AbsoluteSize = Wheel.AbsolutePosition, Wheel.AbsoluteSize;

        local function UpdateSlider(Position)
			Value = math.clamp((Position.X-AbsolutePosition.X)/AbsoluteSize.X, 0, 1);
			if Indicator then
				Indicator.Position = UDim2.fromScale(Value, .5);
			end
			Color = Color3.fromHSV(math.clamp(Hue, 0, 1), math.clamp(Sat, 0, 1), math.clamp(Value, 0, 1));
		end

        Cleaner:Connect(Slider.InputBegan, function(Input)
			if not _Input and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
				_Input = Input;
				UpdateSlider(Input.Position);
			end
		end);

		Cleaner:Connect(Slider.InputChanged, function(Input)
			if not _Input and Input.UserInputState == Enum.UserInputState.Begin and (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch) then
				_Input = Input;
				UpdateSlider(Input.Position);
			elseif _Input == Input then
				UpdateSlider(Input.Position);
			end
		end);

		Cleaner:Connect(Slider.InputEnded, function(Input)
			if _Input == Input then
				_Input = nil;
				UpdateSlider(Input.Position);
				ColorWheel.OnCompleted:Fire(Color);
			end
		end);

		Cleaner:Connect(Slider.MouseMoved, function(X, Y)
			if _Input ~= nil then
				UpdateSlider(Vector2.new(X, Y) - GuiService:GetGuiInset());
			end
		end);
	end

	function ColorWheel:Destroy()
		Cleaner:Destroy();
	end

	return ColorWheel;
end