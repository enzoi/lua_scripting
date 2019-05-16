require "Scripts/Utils/Math"

local CloudGemSpeechRecognitionTest = {
	Properties =
		{
			character = {default = "NewCharacter_0", description = "Character Name"}
		},
}

-- Bot name: OrderFolowers
-- character: IVY

local UIEntities = {
}

local elicitInfoDlg = nil
local elicitInfoTxt = nil

function CloudGemSpeechRecognitionTest:OnActivate()
    self.tickBusHandler = TickBus.Connect(self)
    self.playbackHandler = TextToSpeechPlaybackNotificationBus.Connect(self, self.entityId)
    self.canvasEntityId = UiCanvasManagerBus.Broadcast.LoadCanvas("Levels/CloudGemSpeechRecognitionTest/UI/CloudGemSpeechRecognitionTest.uicanvas")
    self.uiEventHandler = UiCanvasNotificationBus.Connect(self, self.canvasEntityId)
    self.lexNotificationHandler = CloudGemSpeechRecognitionNotificationBus.Connect(self, self.entityId)

    for key, entity in pairs(UIEntities) do
        UiElementBus.Event.SetIsEnabled(entity, false)
    end

    LyShineLua.ShowMouseCursor(true)

end

function CloudGemSpeechRecognitionTest:OnDeactivate()
    self.lexNotificationHandler:Disconnect()
    self.uiEventHandler:Disconnect()
    self.tickBusHandler:Disconnect()
    self.playbackHandler:Disconnect()
end

function CloudGemSpeechRecognitionTest:PrintServiceErrorMessage(error)
    Debug.Log("Error type: " .. error.type)
    Debug.Log("Error message: " .. error.message)
end

function CloudGemSpeechRecognitionTest:AddCharacterSSMLToMessage(language, timbre, tags, ssml, message)
	if #tags == 0 and language == "" and timbre == 100 then
		-- Cached files from the CGP will already have start and end 'speak' ssml tags, even if everything else is default if the character has SSML tags enabled
		if ssml then
			return "<speak>" .. message .. "</speak>";
		end
		return message
	end

	local findTag = string.find(message, "<speak>", 1, true);
	if findTag == 1 and string.find(message, "</speak>", 1, true) == string.len(message) - 7 then
		Debug.Log("already have ssml in this text");
		message = string.sub(message, 8, string.len(message) - 8);
	end

	if language ~= "" then
		ssmlLangTag = "lang=\""..language.."\""
		message = "<lang xml:"..ssmlLangTag..">"..message.."</lang>"
	end

	if timbre ~= 100 then
		message = "<amazon:effect vocal-tract-length=\""..tostring(timbre).."%\">"..message.."</amazon:effect>"
	end

	local finalMessage = "<speak>";
	if #tags ~= 0 then
		finalMessage = finalMessage.."<prosody"
	end

	for index = 1, #tags do
		finalMessage = finalMessage.." "..tags[index];
	end
	if #tags ~= 0 then
		finalMessage = finalMessage .. ">";
	end
	finalMessage = finalMessage .. message
	if #tags ~= 0 then
		finalMessage = finalMessage.."</prosody>"
	end
	
	finalMessage = finalMessage .."</speak>";

	Debug.log("final message" .. finalMessage)	
	return finalMessage
end


function CloudGemSpeechRecognitionTest:CallTextService()
    local edtBotText = UiCanvasBus.Event.FindElementByName(self.canvasEntityId, "edtBotText")
    local textElement = UiElementBus.Event.FindChildByName(edtBotText, "Text")
    textToSend = UiTextBus.Event.GetText(textElement)
    UiTextBus.Event.SetText(textElement, "")

    local request = CloudGemSpeechRecognition_PostTextRequest();
    request.name = "OrderFlowers"
    request.bot_alias = "$LATEST"
    request.user_id = "helloworld"
    request.text = textToSend
    
    local sessionAttrMap = StringMap()
    sessionAttrMap:SetValue("foo", "bar")
    request.session_attributes = sessionAttrMap:ToJSON()

    CloudGemSpeechRecognitionRequestBus.Event.PostServicePosttext(self.entityId, request, nil)
end

function CloudGemSpeechRecognitionTest:TalkStart()
    CloudGemSpeechRecoginition.Broadcast.BeginSpeechCapture()
end

function CloudGemSpeechRecognitionTest:TalkEnd()
    -- Just an example of some user data that might be sent along with request
    local sessionAttrMap = StringMap()
    sessionAttrMap:SetValue("user_position", "10,40")

    CloudGemSpeechRecoginition.Broadcast.EndSpeechCaptureAndCallBot("OrderFlowers", "$LATEST", "lumberyard_user", sessionAttrMap:ToJSON())
end

function CloudGemSpeechRecognitionTest:HandleResponse(response)
    self:SaySomething(response.message)
    
    local outString =  "Message: " .. response.message .. "\n"
                    .. "Intent: " .. response.intent .. "\n"
                    .. "Slots: " .. response.slots .. "\n"
                    .. "Dialog State: " .. response.dialog_state .. "\n"
                    .. "Slot to elicit: " .. response.slot_to_elicit .. "\n"
                    .. "Input Transcript: " .. response.input_transcript .. "\n"
                    .. "Session attributes: " .. response.session_attributes .. "\n"
    local txtResults = UiCanvasBus.Event.FindElementByName(self.canvasEntityId, "txtResults")
    UiTextBus.Event.SetText(txtResults, outString)
end

function CloudGemSpeechRecognitionTest:SaySomething(message)

    local characterInput = self.Properties.character
    local voice = TextToSpeechRequestBus.Event.GetVoiceFromCharacter(self.entityId, characterInput)
    local text = message
    local marks = "VS"
    if voice == '' then
        voice = characterInput;
    else  
        local prosodyTags = TextToSpeechRequestBus.Event.GetProsodyTagsFromCharacter(self.entityId, characterInput)
        local languageOverride = TextToSpeechRequestBus.Event.GetLanguageOverrideFromCharacter(self.entityId, characterInput)
        local timbre = TextToSpeechRequestBus.Event.GetTimbreFromCharacter(self.entityId, characterInput)
        marks = TextToSpeechRequestBus.Event.GetSpeechMarksFromCharacter(self.entityId, characterInput)
        text = self:AddCharacterSSMLToMessage(languageOverride, timbre, prosodyTags, string.match(marks, "T"), message)
    end
    Debug.Log("ConvertTextToSpeechWithMarks" .. text)
    Debug.Log(message)
    Debug.Log(characterInput)
    Debug.Log(voice)
    Debug.Log(marks)
    TextToSpeechRequestBus.Event.ConvertTextToSpeechWithMarks(self.entityId, voice, text, marks)
end

function CloudGemSpeechRecognitionTest:PlayWithLipSync(voicePath, speechMarksPath)
	Debug.Log("Play with lip sync");
end

function CloudGemSpeechRecognitionTest:LogError(error)
    Debug.Log("Error Type: " .. error.type)
    Debug.Log("Error Message: " .. error.message)
end

function CloudGemSpeechRecognitionTest:PlayWithLipSync(voicePath, speechMarksPath)
    Debug.Log("Play with lip sync");
end

function CloudGemSpeechRecognitionTest:OnPostServicePosttextRequestSuccess(response)
    Debug.Log("Got Text Request")
    self:HandleResponse(response)

end

function CloudGemSpeechRecognitionTest:OnPostServicePosttextRequestError(error)
    self:LogError(error)
end

function CloudGemSpeechRecognitionTest:OnPostServicePostaudioRequestSuccess(response)
    Debug.Log("Got Audio Request")
    self:HandleResponse(response)
end

function CloudGemSpeechRecognitionTest:OnPostServicePostaudioRequestError(error)
    self:LogError(error)
end

function CloudGemSpeechRecognitionTest:OnAction(entityId, actionName)
    Debug.Log("Action Name: " .. actionName)
    if actionName == "SendTextMessage" or actionName == "TextEntered" then
        self:CallTextService()
    elseif actionName == "TalkStart" then
        self:TalkStart()
    elseif actionName == "TalkEnd" then
        self:TalkEnd()
    end
end

function CloudGemSpeechRecognitionTest:OnTick(deltaTime, timePoint)
    -- self:ServiceAnimations(deltaTime, timePoint)
end

return CloudGemSpeechRecognitionTest
