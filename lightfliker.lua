-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--
--
----------------------------------------------------------------------------------------------------
local LightFlicker =
{
    Properties =
    {
        FlickerInterval = 1.0,
        LightEntity = { default=EntityId(), description="Light entity to manipulate."},
    },
}

function LightFlicker:OnActivate()

    self.FlickerCountdown = self.Properties.FlickerInterval;
	-- If no light entity assigned, use our entity
    if (not self.Properties.LightEntity:IsValid()) then
        self.Properties.LightEntity = self.entityId;
    end

    Debug.Assert(self.Properties.LightEntity:IsValid(), "No entity is attached!");

    self.tickBusHandler = TickBus.Connect(self)
	LightComponentRequestBus.Event.ToggleLight(self.Properties.LightEntity)

    --Debug.Log("LightFlicker starting for entity: " .. tostring(self.Properties.LightEntity.id));
end

function LightFlicker:OnTick(deltaTime, timePoint)
    self.FlickerCountdown = self.FlickerCountdown - deltaTime;
    if (self.FlickerCountdown < 0.0) then
   	 	LightComponentRequestBus.Event.ToggleLight(self.Properties.LightEntity)
		self.FlickerCountdown = self.Properties.FlickerInterval;
    end
end

function LightFlicker:OnDeactivate()
	self.tickBusHandler:Disconnect()
end

return LightFlicker;
