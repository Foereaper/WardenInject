-- Require the Server Message Handler
require("SMH")

local config = {
	Prefix = "StatPointUI",
	Functions = {
		[1] = "OnFullCacheRequest",
		[2] = "OnSpendPointRequest",
		[3] = "OnStatResetRequest"
	}
}

local StatPointUI = {
	cache = {}
}

function StatPointUI.LoadData(guid)
	local query = CharDBQuery("SELECT `str`, `agi`, `stam`, `int`, `spirit`, `points` FROM character_stats_extra WHERE `guid`="..guid..";");
	if(query) then
		StatPointUI.cache[guid] = {
			query:GetUInt32(0), -- Strength
			query:GetUInt32(1), -- Agility
			query:GetUInt32(2), -- Stamina
			query:GetUInt32(3), -- Intellect
			query:GetUInt32(4), -- Spirit
			query:GetUInt32(5)  -- statpoints
		}
	else
		StatPointUI.cache[guid] = {0, 0, 0, 0, 0, 0};
		CharDBQuery("INSERT INTO character_stats_extra(`guid`, `str`, `agi`, `stam`, `int`, `spirit`, `points`) VALUES ("..guid..", 0, 0, 0, 0, 0, 0);");
	end
end

function StatPointUI.OnLogin(event, player)
	if not(StatPointUI.cache[player:GetGUIDLow()]) then
		StatPointUI.LoadData(player:GetGUIDLow())
	end
	StatPointUI.SetStats(player:GetGUIDLow())
end

function StatPointUI.AddStatPoint(guid)
	local player = GetPlayerByGUID(guid)
	if(player) then
		StatPointUI.cache[guid][6] = StatPointUI.cache[guid][6]+1
		CharDBQuery("UPDATE character_stats_extra SET `points`=`points`+1 WHERE `guid`="..guid..";")
		player:SendServerResponse(config.Prefix, 1, StatPointUI.cache[guid])
	end
end

function StatPointUI.SetStats(guid, stat)
	stat = stat or nil
	local player = GetPlayerByGUID(guid)
	local auras = {7464, 7471, 7477, 7468, 7474}
	if(player) then
		if stat == nil then
			for i = 1, 5 do
				local aura = player:GetAura(auras[i])
				if (aura) then
					aura:SetStackAmount(StatPointUI.cache[guid][i])
				else
					if(StatPointUI.cache[guid][i] > 0) then
						player:AddAura(auras[i], player):SetStackAmount(StatPointUI.cache[guid][i])
					end
				end
			end
		else
			local aura = player:GetAura(auras[stat])
			if (aura) then
				aura:SetStackAmount(StatPointUI.cache[guid][stat])
			else
				if(StatPointUI.cache[player:GetGUIDLow()][stat] > 0) then
					player:AddAura(auras[stat], player):SetStackAmount(StatPointUI.cache[guid][stat])
				end
			end
		end
	end
end

function StatPointUI.ResetStats(guid)
	local player = GetPlayerByGUID(guid)
	local auras = {7464, 7471, 7477, 7468, 7474}
	for _, aura in pairs(auras) do
		player:RemoveAura(aura)
	end
end

function StatPointUI.OnElunaStartup(event)
	-- Re-cache online players' data in case of a hot reload
	for _, player in pairs(GetPlayersInWorld()) do
		StatPointUI.LoadData(player:GetGUIDLow())
	end
end

function StatPointUI.OnPointSpent(guid, stat)
	local inttostr = {"str", "agi", "stam", "int", "spirit"}
	CharDBQuery("UPDATE character_stats_extra SET `"..inttostr[stat].."` = `"..inttostr[stat].."` + 1, `points`=`points`-1 WHERE `guid`="..guid..";")
	StatPointUI.cache[guid][stat] = StatPointUI.cache[guid][stat]+1
	StatPointUI.cache[guid][6] = StatPointUI.cache[guid][6]-1
	StatPointUI.SetStats(guid, stat)
end

function StatPointUI.OnPointsReset(guid)
	local total = 0
	for _, points in pairs(StatPointUI.cache[guid]) do
		total = total+points
	end
	CharDBQuery("UPDATE character_stats_extra SET `str`=0, `agi`=0, `stam`=0, `int`=0, `spirit`=0, `points`="..total.." WHERE `guid`="..guid..";");
	StatPointUI.cache[guid] = {0, 0, 0, 0, 0, total};
	StatPointUI.ResetStats(guid)
end

function OnFullCacheRequest(player, argTable)
	player:SendServerResponse(config.Prefix, 1, StatPointUI.cache[player:GetGUIDLow()])
end

function OnSpendPointRequest(player, argTable)
	if(StatPointUI.cache[player:GetGUIDLow()][6] > 0) then
		-- Double check that the stat requested is actually a valid number
		if(tonumber(argTable[1]) <= 5 and tonumber(argTable[1]) >= 0) then
			StatPointUI.OnPointSpent(player:GetGUIDLow(), argTable[1])
		end
	else
		player:SendBroadcastMessage("You have no points left!")
	end
	player:SendServerResponse(config.Prefix, 1, StatPointUI.cache[player:GetGUIDLow()])
end

function OnStatResetRequest(player, argTable)
	StatPointUI.OnPointsReset(player:GetGUIDLow())
	player:SendServerResponse(config.Prefix, 1, StatPointUI.cache[player:GetGUIDLow()])
end

-- Helper function to add a stat point to the player through other scripts
function Player:AddPoint()
	StatPointUI.AddStatPoint(self:GetGUIDLow())
end

RegisterPlayerEvent(3, StatPointUI.OnLogin)
RegisterServerEvent(33, StatPointUI.OnElunaStartup)
RegisterClientRequests(config)

CMH.StatPointUIPayload = "local config = {Prefix = 'StatPointUI', Functions = {[1] = 'OnCacheReceived'}} StatPointUI = {['cache'] = {}} function StatPointUI.OnLoad() StatPointUI.mainFrame = CreateFrame('Frame', config.Prefix, CharacterFrame) StatPointUI.mainFrame:SetToplevel(true) StatPointUI.mainFrame:SetSize(200, 260) StatPointUI.mainFrame:SetBackdrop( { bgFile = 'Interface/TutorialFrame/TutorialFrameBackground', edgeFile = 'Interface/DialogFrame/UI-DialogBox-Border', edgeSize = 16, tileSize = 32, insets = {left = 5, right = 5, top = 5, bottom = 5} } ) StatPointUI.mainFrame:SetPoint('TOPRIGHT', 170, -20) StatPointUI.mainFrame:Hide() StatPointUI.titleBar = CreateFrame('Frame', config.Prefix..'TitleBar', StatPointUI.mainFrame) StatPointUI.titleBar:SetSize(135, 25) StatPointUI.titleBar:SetBackdrop( { bgFile = 'Interface/CHARACTERFRAME/UI-Party-Background', edgeFile = 'Interface/DialogFrame/UI-DialogBox-Border', tile = true, edgeSize = 16, tileSize = 16, insets = {left = 5, right = 5, top = 5, bottom = 5} } ) StatPointUI.titleBar:SetPoint('TOP', 0, 9) StatPointUI.titleBarText = StatPointUI.titleBar:CreateFontString(config.Prefix..'TitleBarText') StatPointUI.titleBarText:SetFont('Fonts/FRIZQT__.TTF', 13) StatPointUI.titleBarText:SetSize(190, 5) StatPointUI.titleBarText:SetPoint('CENTER', 0, 0) StatPointUI.titleBarText:SetText('|cffFFC125Attribute Points|r') local rowOffset = -30 local titleOffset = -100 local btnOffset = 40 local rowContent = {'Strength', 'Agility', 'Stamina', 'Intellect', 'Spirit'} for k, v in pairs(rowContent) do StatPointUI[v] = {} StatPointUI[v].Val = StatPointUI.mainFrame:CreateFontString(config.Prefix..v..'Val') StatPointUI[v].Val:SetFont('Fonts/FRIZQT__.TTF', 15) if (k == 1) then StatPointUI[v].Val:SetPoint('CENTER', StatPointUI.titleBar, 'CENTER', 30, rowOffset) else local tmp = rowContent[k - 1] StatPointUI[v].Val:SetPoint('CENTER', StatPointUI[tmp].Val, 'CENTER', 0, rowOffset) end StatPointUI[v].Val:SetText('0') StatPointUI[v].Title = StatPointUI.mainFrame:CreateFontString(config.Prefix..v..'Title') StatPointUI[v].Title:SetFont('Fonts/FRIZQT__.TTF', 15) StatPointUI[v].Title:SetPoint('LEFT', StatPointUI[v].Val, 'LEFT', titleOffset, 0) StatPointUI[v].Title:SetText(v..':') StatPointUI[v].Button = CreateFrame('Button', config.Prefix..v..'Button', StatPointUI.mainFrame) StatPointUI[v].Button:SetSize(20, 20) StatPointUI[v].Button:SetPoint('RIGHT', StatPointUI[v].Val, 'RIGHT', btnOffset, 0) StatPointUI[v].Button:EnableMouse(false) StatPointUI[v].Button:Disable() StatPointUI[v].Button:SetNormalTexture('Interface/BUTTONS/UI-SpellbookIcon-NextPage-Up') StatPointUI[v].Button:SetHighlightTexture('Interface/BUTTONS/UI-Panel-MinimizeButton-Highlight') StatPointUI[v].Button:SetPushedTexture('Interface/BUTTONS/UI-SpellbookIcon-NextPage-Down') StatPointUI[v].Button:SetDisabledTexture('Interface/BUTTONS/UI-SpellbookIcon-NextPage-Disabled') StatPointUI[v].Button:SetScript( 'OnMouseUp', function() SendClientRequest(config.Prefix, 2, k) PlaySound('UChatScrollButton') end ) end StatPointUI.pointsLeftVal = StatPointUI.mainFrame:CreateFontString(config.Prefix..'PointsLeftVal') StatPointUI.pointsLeftVal:SetFont('Fonts/FRIZQT__.TTF', 15) local tmp = rowContent[#rowContent] StatPointUI.pointsLeftVal:SetPoint('CENTER', StatPointUI[tmp].Val, 'CENTER', 0, rowOffset) StatPointUI.pointsLeftVal:SetText('0') StatPointUI.pointsLeftTitle = StatPointUI.mainFrame:CreateFontString(config.Prefix..'PointsLeftVal') StatPointUI.pointsLeftTitle:SetFont('Fonts/FRIZQT__.TTF', 15) StatPointUI.pointsLeftTitle:SetPoint('LEFT', StatPointUI.pointsLeftVal, 'LEFT', titleOffset, 0) StatPointUI.pointsLeftTitle:SetText('Points left:') StatPointUI.resetButton = CreateFrame('Button', config.Prefix..'ResetButton', StatPointUI.mainFrame) StatPointUI.resetButton:SetSize(100, 25) StatPointUI.resetButton:SetPoint('CENTER', StatPointUI.titleBar, 'CENTER', 0, -220) StatPointUI.resetButton:EnableMouse(true) StatPointUI.resetButton:SetText('RESET') StatPointUI.resetButton:SetNormalFontObject('GameFontNormalSmall') local ntex = StatPointUI.resetButton:CreateTexture() ntex:SetTexture('Interface/Buttons/UI-Panel-Button-Up') ntex:SetTexCoord(0, 0.625, 0, 0.6875) ntex:SetAllPoints() StatPointUI.resetButton:SetNormalTexture(ntex) local htex = StatPointUI.resetButton:CreateTexture() htex:SetTexture('Interface/Buttons/UI-Panel-Button-Highlight') htex:SetTexCoord(0, 0.625, 0, 0.6875) htex:SetAllPoints() StatPointUI.resetButton:SetHighlightTexture(htex) local ptex = StatPointUI.resetButton:CreateTexture() ptex:SetTexture('Interface/Buttons/UI-Panel-Button-Down') ptex:SetTexCoord(0, 0.625, 0, 0.6875) ptex:SetAllPoints() StatPointUI.resetButton:SetPushedTexture(ptex) StatPointUI.resetButton:SetScript( 'OnMouseUp', function() SendClientRequest(config.Prefix, 3) PlaySound('UChatScrollButton') end ) PaperDollFrame:HookScript( 'OnShow', function() StatPointUI.mainFrame:Show() end ) PaperDollFrame:HookScript( 'OnHide', function() StatPointUI.mainFrame:Hide() end ) StatPointUI.pointsLeftVal:SetText(StatPointUI.cache[6]) PaperDollFrame:HookScript( 'OnShow', function() StatPointUI.mainFrame:Show() end ) PaperDollFrame:HookScript( 'OnHide', function() StatPointUI.mainFrame:Hide() end ) end function OnCacheReceived(sender, argTable) StatPointUI.cache = argTable[1] local rowContent = {'Strength', 'Agility', 'Stamina', 'Intellect', 'Spirit'} for i = 1, 5 do local rci = rowContent[i] StatPointUI[rci].Val:SetText(StatPointUI.cache[i]) if (StatPointUI.cache[i] > 0) then StatPointUI[rci].Val:SetTextColor(0, 1, 0, 1) else StatPointUI[rci].Val:SetTextColor(1, 1, 1, 1) end if (StatPointUI.cache[6] > 0) then StatPointUI[rci].Button:EnableMouse(true) StatPointUI[rci].Button:Enable() else StatPointUI[rci].Button:EnableMouse(false) StatPointUI[rci].Button:Disable() end end StatPointUI.pointsLeftVal:SetText(StatPointUI.cache[6]) end RegisterServerResponses(config) StatPointUI.OnLoad() SendClientRequest(config.Prefix, 1)"