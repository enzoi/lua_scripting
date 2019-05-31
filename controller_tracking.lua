local controllerScript = require('scripts/vr/controller')

local controller_tracking =
{
    Properties =
    {
		CameraEntity = {default=EntityId()},
		ControllerEntityLeft = {default=EntityId()},
		ControllerEntityRight = {default=EntityId()},
    }
}

function controller_tracking:OnTick(delta, timepoint)
	controllerScript:UpdateControllerTransform(self.Properties.CameraEntity, 1, self.Properties.ControllerEntityRight)
	controllerScript:UpdateControllerTransform(self.Properties.CameraEntity, 0, self.Properties.ControllerEntityLeft)
end

function controller_tracking:OnActivate()
	self.TickHandler = TickBus.Connect(self, 0)
end

function controller_tracking:OnDeactivate()
	if self.TickHandler ~= nil then
		self.TickHandler:Disconnect()
		self.TickHandler = nil
	end
end

return controller_tracking
