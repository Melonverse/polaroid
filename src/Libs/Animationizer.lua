--!strict
--!optimize 2
local TweenService = game:GetService("TweenService");

local Trove = require(script.Parent.Trove);
local Signal = require(script.Parent.Signal);
local Utility = require(script.Parent.Utility);

local Tokenizer = {};

export type PoseData = {
	Name: string;
	CFrame: CFrame;
	EasingDirection: Enum.EasingDirection?;
	EasingStyle: Enum.EasingStyle?;
	Weight: number;
	SubPoses: { PoseData }?;
}

export type KeyframeData = {
	Name: string;
	Time: number;
	Poses: { PoseData };
}

export type CustomAnimationType = {
	Completed: typeof(Signal);
	DidLoop: typeof(Signal);
	Stopped: typeof(Signal);
	Playing: typeof(Signal);

	Length: number;
	Speed: number;

	Loop: boolean;
	Priority: Enum.AnimationPriority;
	Frames: { KeyframeData };
	
	IsPlaying: (_: CustomAnimationType) -> boolean;
	Play: (_: CustomAnimationType, Fade: number?, Weight: number?, Speed: number?) -> nil;
	Stop: (_: CustomAnimationType) -> nil;
	Destroy: (_: CustomAnimationType) -> nil;
	AdjustSpeed: (_: CustomAnimationType, Speed: number) -> nil;
}

function Tokenizer:Pose(Pose: Pose): PoseData
	local PoseInfo: PoseData = {
		Name = Pose.Name;
		CFrame = Pose.CFrame;
		EasingDirection = Utility:ConvertEnum(Pose.EasingDirection);
		EasingStyle = Utility:ConvertEnum(Pose.EasingStyle);
		Weight = Pose.Weight;
		SubPoses = if #Pose:GetChildren() > 0 then {} else nil;
	};

	if PoseInfo.SubPoses then
		for _, SubPose in pairs(Pose:GetChildren()) do
			if SubPose:IsA("Pose") then
				table.insert(PoseInfo.SubPoses, Tokenizer:Pose(SubPose) :: PoseData);
			end
		end
	end

	return PoseInfo;
end

function Tokenizer:Keyframe(Keyframe: Keyframe): KeyframeData
	local KeyframeInfo: KeyframeData = { Name = Keyframe.Name, Time = Keyframe.Time, Poses = {}};

	for _, Object in pairs(Keyframe:GetChildren()) do
		if Object:IsA("Pose") then
			table.insert(KeyframeInfo.Poses, Tokenizer:Pose(Object));
		end
	end

	return KeyframeInfo;
end

function Tokenizer:KeyframeSequence(Character: Model, KeyframeSeq: KeyframeSequence): CustomAnimationType
	local Keyframes = KeyframeSeq:GetKeyframes() :: { Instance & Keyframe };

	table.sort(Keyframes, function(K, K2) 
		return K.Time < K2.Time;
	end)

	local Playing = false;
	local Stopped = false;

	local Cleaner = Trove.new();
	local RunningThread = nil;

	local CustomAnimation : CustomAnimationType = {
		Name = KeyframeSeq.Name;
		Completed = Cleaner:Add(Signal.new(), "Destroy");
		Stopped = Cleaner:Add(Signal.new(), "Destroy");
		Playing = Cleaner:Add(Signal.new(), "Destroy");
		DidLoop = Cleaner:Add(Signal.new(), "Destroy");

		Length = 0;
		Speed = 1;

		Frames = {} :: { KeyframeData };

		Loop = KeyframeSeq.Loop;
		Priority = KeyframeSeq.Priority;

		IsPlaying = function()
			return Playing;
		end;

		AdjustSpeed = function(self: CustomAnimationType, Speed: number)
			self.Speed = Speed;
			return nil;
		end;

		Play = function() end;
		Stop = function() end;

		Destroy = function(self)
			if RunningThread then
				task.cancel(RunningThread);
			end

			Cleaner:Destroy();
			table.clear(self);
		end;
	};

	local MotorMap = Utility:GetMotorMap(Character);
	local BoneMap = Utility:GetBoneMap(Character);

	CustomAnimation.Length = Keyframes[#Keyframes].Time;

	for _, Frame in pairs(Keyframes) do
		table.insert(CustomAnimation.Frames, Tokenizer:Keyframe(Frame));
	end

	local function PlayPose(Pose: PoseData, Parent: PoseData?, FadeTime: number)
		local SubPoses = Pose.SubPoses;

		if SubPoses then
			for _, SubPose in SubPoses do
				task.spawn(PlayPose, SubPose, Pose, FadeTime);
			end
		end

		if Parent then
			local TInfo = TweenInfo.new(FadeTime, Pose.EasingStyle, Pose.EasingDirection);
			local Target = { Transform = Pose.CFrame };

			local MotorSubMap = MotorMap[Parent.Name];
			local BoneSubMap = BoneMap[Parent.Name];
			local Combination = {};

			if MotorSubMap then
				local Motors = MotorSubMap[Pose.Name] or {};
				Combination = Utility:Merge(Combination, Motors);
			end

			if BoneSubMap then
				local Bones = BoneSubMap[Pose.Name] or {};
				Combination = Utility:Merge(Combination, Bones);
			end

			for _, Object: Instance & (Bone | Motor6D) in pairs(Combination) do
				if not CustomAnimation or Stopped then
					break
				end

				if FadeTime > 0 then
					TweenService:Create(Object, TInfo, Target):Play();
				else
					Object.Transform = Pose.CFrame;
				end
			end
		end
	end


	function CustomAnimation:Play(Fade: number?, Weight: number?, Speed: number?)
		if not Character or not Character.Parent or Playing then
			return
		end

		self.Playing:Fire();
		Playing = true;
		Stopped = false;
		
		local Start = tick();

		RunningThread = Cleaner:Add(task.spawn(function()
			local Count = 0;
			
			repeat
				if Count >= 1 then
					self.DidLoop:Fire();
				end
				
				for Index: number, FrameData: KeyframeData in pairs(self.Frames) do
					if Stopped then
						return
					end

					local T = FrameData.Time / (Speed or self.Speed);

					local Poses = FrameData.Poses;
					
					if Poses then
						for _, Pose in pairs(Poses) do
							local FadeTime = Fade;

							if Index ~= 1 then
								FadeTime = (T * (Speed or self.Speed) - self.Frames[Index - 1].Time) / (Speed or self.Speed);
							end

							task.spawn(PlayPose, Pose, nil, FadeTime or .10000001);
						end
					end

					if T > tick() - Start then
						repeat
							task.wait();
						until Stopped or tick() - Start >= T;
					end
				end
				
				if not self.Loop then
					Playing = false;
					self.Stopped:Fire();
					return
				end
				
				Count += 1;
				task.wait();
			until Stopped;
		end))

		return nil;
	end

	function CustomAnimation:Stop()
		Stopped = true;
		Playing = false;
		self.Stopped:Fire();
		return nil;
	end

	return CustomAnimation :: CustomAnimationType;
end

return function(Character: Model)
	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid;
	local Animate = Character:WaitForChild("Animate") :: Script;
	local Animator = Humanoid:WaitForChild("Animator") :: Animator;

	local Cleaner = Trove.new();
	local Died = false;

	Cleaner:AttachToInstance(Humanoid);
	Cleaner:Connect(Humanoid.Died, function()
		Died = true;
	end);

	local function StopAnimations()
		if Humanoid and Animator then
			for _, AnimationTrack in pairs(Animator:GetPlayingAnimationTracks()) do
				AnimationTrack:Stop();
			end
		end
	end

	local CustomAnimator = {};
	local Animations: { CustomAnimationType } = {};
	
	function CustomAnimator:GetPlayingTracks()
		local T = {};
		
		for _, Animation in pairs(Animations) do
			if Animation:IsPlaying() then
				table.insert(T, Animation);
			end
		end
		
		return T;
	end	

	function CustomAnimator:LoadSequence(KeyframeSeq: KeyframeSequence)
		if Died then return end

		local CustomAnimation = Tokenizer:KeyframeSequence(Character, KeyframeSeq);
		table.insert(Animations, CustomAnimation);
		
		Cleaner:Add(CustomAnimation, "Destroy");

		Cleaner:Connect(CustomAnimation.Playing, function()
			if Animate and not Animate.Disabled then
				Animate.Disabled = true;
				StopAnimations();
			end
		end)

		Cleaner:Connect(CustomAnimation.Stopped, function()	
			if Animate and Animate.Parent and #CustomAnimator:GetPlayingTracks() == 0 then
				Animate.Disabled = false;
			end
		end)

		return CustomAnimation;
	end
	
	function CustomAnimator:Destroy()
		Cleaner:Destroy();
	end

	return CustomAnimator;
end