local teleport = 
{
	Properties = 
	{		
		UseNavMesh = true,
		UseTerrain = true,
		TeleportMaxDistance = 20,
		TeleportInputEventName = "Teleport",
		Camera = {default=EntityId()}
	},
}

function teleport:TeleportHMDToPosition(position, CameraEntity)
	if CameraEntity ~= nil and CameraEntity:IsValid() then
		local TM = TransformBus.Event.GetWorldTM(CameraEntity)
		if TM ~= nil then
			local newCameraPos = position
			
			-- offset for HMD
			if StereoRendererRequestBus.Broadcast.IsRenderingToHMD() then
				local HMDOffset = nil
				HMDOffset = HMDDeviceRequestBus.Broadcast.GetTrackingState().pose.position
				HMDOffset.z = 0
				newCameraPos = newCameraPos - HMDOffset;
			end
			
			TM:SetPosition(newCameraPos)
			TransformBus.Event.SetWorldTM(CameraEntity, TM)
		end
	end
end

function teleport:Teleport(ControllerEntity, CameraEntity, MaxDistance, UseNavMesh, UseTerrain)
	local entityTM = TransformBus.Event.GetWorldTM(ControllerEntity)
			
	-- ray cast with the world
	if entityTM ~= nil then
		local entityPos = entityTM:GetPosition()
		local rayLength = MaxDistance
		local rayDirection = entityTM.basisY
		local rayPos = nil
		local rayCollision = true
		
		local rayCastConfiguration = RayCastConfiguration()
		rayCastConfiguration.origin = entityPos
		rayCastConfiguration.direction = entityTM.basisY
		rayCastConfiguration.maxDistance = rayLength
		rayCastConfiguration.physicalEntityTypes = TogglePhysicalEntityTypeMask(PhysicalEntityTypes.All, PhysicalEntityTypes.Living) -- raycast against all but living entities
		
		local rayCastResult = PhysicsSystemRequestBus.Broadcast.RayCast(rayCastConfiguration)

		if rayCastResult:HasBlockingHit() then
			local topRayCastResult = rayCastResult:GetBlockingHit()
			rayPos = topRayCastResult.position
			
			if UseTerrain then
				rayLength = topRayCastResult.distance
				rayDirection = (topRayCastResult.position - entityPos) / rayLength
				rayCollision = true
			end
		end
			
		if UseNavMesh then
			-- ray cast with the nav mesh at the world intersection
			local navRayCastResult = NavigationSystemRequestBus.Broadcast.RayCast(entityPos, rayDirection, rayLength)
			rayCollision = navRayCastResult.collision
			if rayCollision then
				if UseTerrain == false then
					rayPos = navRayCastResult.position
				end
			end
		end
		
		if rayCollision and rayPos ~= nil then
			self:TeleportHMDToPosition(rayPos, CameraEntity)
			return true
		end
	end
	
	return false;
end

function teleport:OnActivate()
	self.TickHandler = TickBus.Connect(self, 0)
	
	local teleportBusId = InputEventNotificationId(self.Properties.TeleportInputEventName)
	self.teleportBus = InputEventNotificationBus.Connect(self, teleportBusId)
end

function teleport:OnDeactivate()
	if self.TickHandler ~= nil then
		self.TickHandler:Disconnect()
		self.TickHandler = nil
	end
	
	if self.teleportBus then
		self.teleportBus:Disconnect()
		self.teleportBus = nil
	end
end

function teleport:OnPressed(floatValue)
	-- show indicator
end

function teleport:OnHeld(floatValue)
end

function teleport:OnReleased(floatValue)
	self:Teleport(self.entityId, self.Properties.Camera, self.Properties.TeleportMaxDistance, self.Properties.UseNavMesh, self.Properties.UseTerrain)
end

function teleport:OnTick(delta, timepoint)
	
end

return teleport
