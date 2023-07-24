local Signal = require(script.Parent.Signal);

return function(InitialValue)
	return {
		OnChange = Signal.new();
		
		Get = function()
			return InitialValue;
		end,
		
		Set = function(self, Value)
			if InitialValue ~= Value then
				self.OnChange:Fire(Value, InitialValue);
				InitialValue = Value;
			end
		end,
		
		Destroy = function(self)
			self.OnChange:Destroy();
		end,
	}
end