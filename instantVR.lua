--[[
Handles basic VR features:
- Controller Tracking
- Teleport
--]]

local controllerScript = require('scripts/vr/controller')
local teleportScript = require('scripts/vr/teleport')
local raycastScript = require('scripts/vr/raycast')

local instantVR =
{
    Properties =
    {
		CameraEntity = {default=EntityId()},
		ControllerEntityLeft = {default=EntityId()},
		ControllerEntityRight = {default=EntityId()},
		TeleportEntityValid = {default=EntityId()},
		TeleportEntityInvalid = {default=EntityId()},
		TeleportBeamSpawner = {default=EntityId()},
		TeleportInputEventNameLeft = "TeleportLeft",
		TeleportInputEventNameRight = "TeleportRight",
		TeleportUseTerrain = true,
		TeleportUseNavMesh = true,
		TeleportMaxDistance = 20
    },
	InputEvent = 
	{
		TeleportLeft = {},
		TeleportRight = {}
	},
	SpawnEvent = 
	{
		TeleportEntityValid = {},
		TeleportEntityInvalid = {},
		TeleportEntityBeam = {}
	},
	TeleportBeamTickets = 
	{
		Left = {},
		Right = {}
	},
	TeleportBeamEntities = 
	{
		Left = {},
		Right = {}
	}
}

-- returns the transform at a particular time of a projectile launched using the incoming transform
function instantVR:CalculateProjectile(entityTM, percent)
	local gravity = -9.8
	local ySpeed = self.Properties.TeleportMaxDistance * (1 - math.abs(entityTM.basisY.z))
	local zSpeed = 10*entityTM.basisY.z
	
	local newPoint = Vector3:CreateZero()
	newPoint.y = ySpeed * percent -- constant y speed over time
	newPoint.z = zSpeed*percent + 0.5*gravity*percent*percent -- z initial velocity plus gravity accelleration over time
	
	-- create a new transform without z elevation
	local newBasisY = entityTM.basisY:Clone()
	newBasisY.z = 0
	newBasisY:Normalize()
	local newEntityTM = Transform:CreateIdentity()
	local newBasisX = newBasisY:Cross(newEntityTM.basisZ)
	newEntityTM:SetBasisAndPosition(newBasisX, newBasisY, newEntityTM.basisZ, Vector3:CreateZero())
	
	-- translate the position of the transform by the new point
	newPoint = newEntityTM * newPoint;
	newEntityTM:SetPosition(entityTM:GetPosition() + newPoint)

	-- set the orientation of the transform in the direction of the predicted velocity
	local facing = Transform.CreateRotationX(math.atan2(zSpeed + gravity*percent, ySpeed)) -- rotate around x by inverse tangent of height and length
	newEntityTM = newEntityTM*facing
		
	return newEntityTM;
end

function instantVR:OnActivate()
	self.TickHandler = TickBus.Connect(self, 0)
	
	self.teleportLeftBus = InputEventNotificationBus.Connect(self.InputEvent.TeleportLeft, InputEventNotificationId(self.Properties.TeleportInputEventNameLeft))
	self.InputEvent.TeleportLeft.root = self
	
	self.teleportRightBus = InputEventNotificationBus.Connect(self.InputEvent.TeleportRight, InputEventNotificationId(self.Properties.TeleportInputEventNameRight))
	self.InputEvent.TeleportRight.root = self
	
	self.spawnBusHandlerValid = SpawnerComponentNotificationBus.Connect(self.SpawnEvent.TeleportEntityValid, self.Properties.TeleportEntityValid)
	self.SpawnEvent.TeleportEntityValid.root = self
	
	self.spawnBusHandlerInvalid = SpawnerComponentNotificationBus.Connect(self.SpawnEvent.TeleportEntityInvalid, self.Properties.TeleportEntityInvalid)
	self.SpawnEvent.TeleportEntityInvalid.root = self
	
	self.spawnBusHandlerBeam = SpawnerComponentNotificationBus.Connect(self.SpawnEvent.TeleportEntityBeam, self.Properties.TeleportBeamSpawner)
	self.SpawnEvent.TeleportEntityBeam.root = self
	
	self.BeamCount = 20
end

function instantVR:OnDeactivate()
	if self.TickHandler ~= nil then
		self.TickHandler:Disconnect()
		self.TickHandler = nil
	end
	
	if self.teleportLeftBus ~= nil then
		self.teleportLeftBus:Disconnect()
		self.teleportLeftBus = nil
	end
	
	if self.teleportRightBus ~= nil then
		self.teleportRightBus:Disconnect()
		self.teleportRightBus = nil
	end
	
	if self.spawnBusHandlerValid ~= nil then
		self.spawnBusHandlerValid:Disconnect()
		self.spawnBusHandlerValid = nil
	end
	
	if self.spawnBusHandlerInvalid ~= nil then
		self.spawnBusHandlerInvalid:Disconnect()
		self.spawnBusHandlerInvalid = nil
	end
	
	if self.spawnBusHandlerBeam ~= nil then
		self.spawnBusHandlerBeam:Disconnect()
		self.spawnBusHandlerBeam = nil
	end
end

-- TeleportLeft InputEvent handlers --------
function instantVR.InputEvent.TeleportLeft:OnPressed(floatValue)
	local props = self.root.Properties
	self.root.LeftValidTicket = SpawnerComponentRequestBus.Event.Spawn(props.TeleportEntityValid)
	self.root.LeftInvalidTicket = SpawnerComponentRequestBus.Event.Spawn(props.TeleportEntityInvalid)
	for i=1,self.root.BeamCount,1 do
		self.root.TeleportBeamTickets.Left[i] = SpawnerComponentRequestBus.Event.Spawn(props.TeleportBeamSpawner)
	end
end
function instantVR.InputEvent.TeleportLeft:OnHeld(floatValue)
	local props = self.root.Properties
	if props.ControllerEntityLeft ~= nil and props.ControllerEntityLeft:IsValid() then
		local entityTM = TransformBus.Event.GetWorldTM(props.ControllerEntityLeft)
		
		for i=1,self.root.BeamCount,1 do
			local newTM = self.root:CalculateProjectile(entityTM, (i/self.root.BeamCount)*2)
			if self.root.TeleportBeamEntities.Left[i] ~= nil then
				TransformBus.Event.SetWorldTM(self.root.TeleportBeamEntities.Left[i], newTM)
			end
		end
		raycastScript:UpdateLocationEntities(entityTM, self.root.LeftEntityValid, self.root.LeftEntityInvalid, props.TeleportMaxDistance, props.TeleportUseNavMesh, props.TeleportUseTerrain)
	end
end
function instantVR.InputEvent.TeleportLeft:OnReleased(floatValue)
	local props = self.root.Properties
	
	if teleportScript:Teleport(props.ControllerEntityLeft, props.CameraEntity, props.TeleportMaxDistance, props.TeleportUseNavMesh, props.TeleportUseTerrain) then
		AudioTriggerComponentRequestBus.Event.Play(self.root.Properties.ControllerEntityLeft)
		GameplayNotificationBus.Event.OnEventBegin(GameplayNotificationId(self.root.entityId, "TeleportEvent", "float"), 0);
	end
	
	raycastScript:HideLocations(props.TeleportEntityValid, props.TeleportEntityInvalid)
	GameEntityContextRequestBus.Broadcast.DestroyGameEntityAndDescendants(self.root.LeftEntityValid)
	GameEntityContextRequestBus.Broadcast.DestroyGameEntityAndDescendants(self.root.LeftEntityInvalid)
	
	for i=1,self.root.BeamCount,1 do
		if self.root.TeleportBeamEntities.Left[i] ~= nil then
			GameEntityContextRequestBus.Broadcast.DestroyGameEntityAndDescendants(self.root.TeleportBeamEntities.Left[i])
		end
	end
end
--------------------------------------------

-- TeleportRight InputEvent handlers -------
function instantVR.InputEvent.TeleportRight:OnPressed(floatValue)
	local props = self.root.Properties
	self.root.RightValidTicket = SpawnerComponentRequestBus.Event.Spawn(props.TeleportEntityValid)
	self.root.RightInvalidTicket = SpawnerComponentRequestBus.Event.Spawn(props.TeleportEntityInvalid)
end
function instantVR.InputEvent.TeleportRight:OnHeld(floatValue)
	local props = self.root.Properties;
	if props.ControllerEntityRight ~= nil and props.ControllerEntityRight:IsValid() then
		local entityTM = TransformBus.Event.GetWorldTM(props.ControllerEntityRight)
		raycastScript:UpdateLocationEntities(entityTM, self.root.RightEntityValid, self.root.RightEntityInvalid, props.TeleportMaxDistance, props.TeleportUseNavMesh, props.TeleportUseTerrain)
	end
end
function instantVR.InputEvent.TeleportRight:OnReleased(floatValue)
	local props = self.root.Properties;
	if teleportScript:Teleport(props.ControllerEntityRight, props.CameraEntity, props.TeleportMaxDistance, props.TeleportUseNavMesh, props.TeleportUseTerrain) then 
		AudioTriggerComponentRequestBus.Event.Play(self.root.Properties.ControllerEntityRight)
		GameplayNotificationBus.Event.OnEventBegin(GameplayNotificationId(self.root.entityId, "TeleportEvent", "float"), 0);
	end
	raycastScript:HideLocations(props.TeleportEntityValid, props.TeleportEntityInvalid)
	GameEntityContextRequestBus.Broadcast.DestroyGameEntityAndDescendants(self.root.RightEntityValid)
	GameEntityContextRequestBus.Broadcast.DestroyGameEntityAndDescendants(self.root.RightEntityInvalid)
	
	
end
--------------------------------------------

function instantVR.SpawnEvent.TeleportEntityValid:OnEntitySpawned(sliceTicket,entityId)
	if self.root.RightValidTicket == sliceTicket then
		self.root.RightEntityValid = entityId
	end
	
	if self.root.LeftValidTicket == sliceTicket then
		self.root.LeftEntityValid = entityId
	end
end

function instantVR.SpawnEvent.TeleportEntityInvalid:OnEntitySpawned(sliceTicket,entityId)
	if self.root.RightInvalidTicket == sliceTicket then
		self.root.RightEntityInvalid = entityId
	end
	
	if self.root.LeftInvalidTicket == sliceTicket then
		self.root.LeftEntityInvalid = entityId
	end
end

function instantVR.SpawnEvent.TeleportEntityBeam:OnEntitySpawned(sliceTicket,entityId)
	for i=1,self.root.BeamCount,1 do
		if self.root.TeleportBeamTickets.Left[i] == sliceTicket then
			self.root.TeleportBeamEntities.Left[i] = entityId
		end
	end
end

function instantVR:OnTick(delta, timepoint)
	controllerScript:UpdateControllerTransform(self.Properties.CameraEntity, 1, self.Properties.ControllerEntityRight)
	controllerScript:UpdateControllerTransform(self.Properties.CameraEntity, 0, self.Properties.ControllerEntityLeft)
end

return instantVR
