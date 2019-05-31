--[[
Sets the position and orientation of the entity this script is attached to to the 
numbered controller position and orientation. The controller is positioned an oriented
relative to camera entity with the active view
--]]
local controller =
{
    Properties =
    {
		Camera = {default=EntityId()},
		ControllerNum = {default=1},
    },
}

function controller:UpdateControllerTransform(CameraEntity, ControllerNum, ControllerEntity)
	if CameraEntity ~= nil and CameraEntity:IsValid() then
		local parentTM = TransformBus.Event.GetWorldTM(CameraEntity)

		if ControllerRequestBus.Broadcast.IsConnected(ControllerNum) and 
			parentTM ~= nil and StereoRendererRequestBus.Broadcast.IsRenderingToHMD() and 
			ControllerEntity ~= nil and ControllerEntity:IsValid() then
			
			local entityTM = TransformBus.Event.GetWorldTM(ControllerEntity)
			local entityTMScale = entityTM:RetrieveScale() -- save scale for later
			local parentPos = parentTM:GetPosition()
			local controllerPos = ControllerRequestBus.Broadcast.GetTrackingState(ControllerNum).pose.position
			local controllerOrient = ControllerRequestBus.Broadcast.GetTrackingState(ControllerNum).pose.orientation
			
			-- set the transform to the controller, as a child of the parent
			entityTM:SetPosition(controllerPos)
			entityTM:SetRotationPartFromQuaternion(controllerOrient) -- Note: this blows away scale
			entityTM = parentTM * entityTM;
			entityTM:MultiplyByScale(entityTMScale) -- set scale back
			
			TransformBus.Event.SetWorldTM(ControllerEntity, entityTM)
		end
	end
end

function controller:OnActivate()
	self.TickHandler = TickBus.Connect(self, 0)
end

function controller:OnDeactivate()
	if self.TickHandler ~= nil then
		self.TickHandler:Disconnect()
		self.TickHandler = nil
	end
end

function controller:OnTick(delta, timepoint)
	self:UpdateControllerTransform(self.Properties.Camera, self.Properties.ControllerNum, self.entityId)
end

return controller
