local raycast = 
{
	Properties = 
	{
		RayLength = 20,
		UseNavMesh = true,
		UseTerrain = true,
		RaycastInputEventName = "Teleport",
		ValidLocation = {default=EntityId()},
		InvalidLocation = {default=EntityId()}
	},
}

function raycast:SetEntityPosition(entity, position)
	if entity and entity:IsValid() then
		local TM = TransformBus.Event.GetWorldTM(entity)
		if TM ~= nil then
			TM:SetPosition(position)
			TransformBus.Event.SetWorldTM(entity, TM)
		end
	end
end

function raycast:HideLocations(ValidLocationEntity, InvalidLocationEntity)
	-- This is a hack to hide these Entities, because I can't do anything with materials in lua yet
	local zeroVec = Vector3.CreateZero()
	
	self:SetEntityPosition(ValidLocationEntity, zeroVec)
	self:SetEntityPosition(InvalidLocationEntity, zeroVec)
end

function raycast:UpdateLocationEntities(entityTM, ValidLocationEntity, InvalidLocationEntity, RayLength, UseNavMesh, UseTerrain)
	if entityTM ~= nil then
		local entityPos = entityTM:GetPosition()
		local rayLength = RayLength
		local rayDirection = entityTM.basisY
		local rayPos = nil
		local rayCollision = true

		self:HideLocations(ValidLocationEntity, InvalidLocationEntity)
						
		local rayCastConfiguration = RayCastConfiguration()
		rayCastConfiguration.origin = entityPos
		rayCastConfiguration.direction = rayDirection
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
			local navRayCastResult = NavigationSystemRequestBus.Broadcast.RayCast(entityPos, rayDirection, rayLength)
			rayCollision = navRayCastResult.collision
			if rayCollision then
				if UseTerrain == false then
					rayPos = navRayCastResult.position
				end
			end
		end
		
		if rayPos ~= nil then
			if rayCollision then
				self:SetEntityPosition(ValidLocationEntity, rayPos)
			else
				self:SetEntityPosition(InvalidLocationEntity, rayPos)
			end
		end
	end
end

function raycast:OnActivate()
	local raycastInputBusId = InputEventNotificationId(self.Properties.RaycastInputEventName)
	self.raycastInputBus = InputEventNotificationBus.Connect(self, raycastInputBusId)
			
	self:HideLocations(self.Properties.ValidLocation, self.Properties.InvalidLocation)
end

function raycast:OnDeactivate()
	if self.TickHandler ~= nil then
		self.TickHandler:Disconnect()
		self.TickHandler = nil
	end
	
	if self.raycastInputBus then
		self.raycastInputBus:Disconnect()
		self.raycastInputBus = nil
	end
end

function raycast:OnPressed(floatValue)
	-- show indicator
	self.TickHandler = TickBus.Connect(self, 0)
end

function raycast:OnHeld(floatValue)
end

function raycast:OnReleased(floatValue)
	if self.TickHandler ~= nil then
		self.TickHandler:Disconnect()
		self.TickHandler = nil
	end
	
	self:HideLocations(self.Properties.ValidLocation, self.Properties.InvalidLocation)
end

function raycast:OnTick(delta, timepoint)
	local entityTM = TransformBus.Event.GetWorldTM(self.entityId)
	self:UpdateLocationEntities(self.entityId, self.Properties.ValidLocation, self.Properties.InvalidLocation, self.Properties.RayLength, self.Properties.UseNavMesh, self.Properties.UseTerrain)
end

return raycast
