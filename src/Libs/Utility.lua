local Utility = {}

local EnumTable = {
	["PoseEasingDirection"] = "EasingDirection",
	["PoseEasingStyle"] = "EasingStyle",
}

function Utility:Merge(T, T2)
	for K, V in pairs(T2) do
		if type(V) == "table" then
			if type(T[K] or false) == "table" then
				Utility:Merge(T[K] or {}, T2[K] or {})
			else
				T[K] = V;
			end
		else
			T[K] = V;
		end
	end
	return T;
end

function Utility:ConvertEnum(_Enum)
	local Str = tostring(_Enum):split(".");
		
	if Str[1] == "Enum" then
		local Cat = Str[2]
		local Name = Str[3]
		Name = if Name == "Constant" then "Linear" else Name;
		if EnumTable[Cat] then
			return Enum[EnumTable[Cat]][Name]
		end
	end
	
	return _Enum;
end

function Utility:GetBoneMap(Character)
	if typeof(Character) ~= "Instance" then
		error(string.format("invalid argument 1 to 'getBoneMap' (Instance expected, got %s)", typeof(Character)))
	end

	local BoneMap = {}
	local Descendants = Character:GetDescendants();
	
	for _, Descendant in pairs(Character:GetDescendants()) do
		local Parent = Descendant.Parent;
		if Parent ~= nil and Descendant:IsA("Bone") then
			local ParentName = Parent.Name;
			local Name = Descendant.Name;
			
			if not BoneMap[ParentName] then
				BoneMap[ParentName] = {};
			end
			
			if not BoneMap[ParentName][Name] then
				BoneMap[ParentName][Name] = {};
			end
			
			table.insert(BoneMap[ParentName][Name], Descendant);
		end
	end

	return BoneMap
end

function Utility:GetMotorMap(Character)
	if typeof(Character) ~= "Instance" then
		error(string.format("invalid argument 1 to 'getMotorMap' (Instance expected, got %s)", typeof(Character)))
	end

	local MotorMap = {};
	
	for _, Descendant in pairs(Character:GetDescendants()) do
		if Descendant:IsA("Motor6D") and Descendant.Part0 ~= nil and Descendant.Part1 ~= nil then
			local P, P1 = Descendant.Part0.Name, Descendant.Part1.Name;

			if not MotorMap[P] then
				MotorMap[P] = {};
			end

			if not MotorMap[P][P1] then
				MotorMap[P][P1] = {};
			end

			table.insert(MotorMap[P][P1], Descendant);
		end
	end

	return MotorMap
end

return Utility