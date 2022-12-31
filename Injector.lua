require('lualzw')
require('Smallfolk')

local WardenLoader = {
	order = {
		-- defines the load order of payloads
		[1] = "lualzw",
		[2] = "Smallfolk",
		[3] = "CMH",
		[4] = "StatPointUI",
	},
	data = {
		-- defines data per payload
		["lualzw"] = {
			version = 1,
			compressed = 0,
			cached = 1,
			payload = lualzw.payload
		},
		["Smallfolk"] = {
			version = 1,
			compressed = 1,
			cached = 1,
			payload = Smallfolk.payload
		},
		["CMH"] = {
			version = 1,
			compressed = 1,
			cached = 1,
			payload = "local debug = false local CMH = {} local datacache = {} local delim = {'', '', '', '', ''} local pck = {REQ = '', DAT = ''} local function debugOut(prefix, x, msg) if(debug == true) then print(date('%X', time())..' '..x..' '..prefix..': '..msg) end end local function GenerateReqId() local length = 6 local reqId = '' for i = 1, length do reqId = reqId..string.char(math.random(97, 122)) end return reqId end local function ParseMessage(str) str = str or '' local output = {} local valTemp = {} local typeTemp = {} local valMatch = '[^'..table.concat(delim)..']+' local typeMatch = '['..table.concat(delim)..']+' for value in str:gmatch(valMatch) do table.insert(valTemp, value) end for varType in str:gmatch(typeMatch) do for k, v in pairs(delim) do if(v == varType) then table.insert(typeTemp, k) end end end for k, v in pairs(valTemp) do local varType = typeTemp[k] if(varType == 2) then if(v == string.char(tonumber('1A', 16))) then v = '' end elseif(varType == 3) then v = tonumber(v) elseif(varType == 4) then v = Smallfolk.loads(v, #v) elseif(varType == 5) then if(v == 'true') then v = true else v = false end end table.insert(output, v) end valTemp = nil typeTemp = nil return output end local function ProcessVariables(reqId, ...) local splitLength = 200 local arg = {...} local msg = '' for _, v in pairs(arg) do if(type(v) == 'string') then if(#v == 0) then v = string.char(tonumber('1A', 16)) end msg = msg..delim[2] elseif(type(v) == 'number') then msg = msg..delim[3] elseif(type(v) == 'table') then v = Smallfolk.dumps(v) msg = msg..delim[4] elseif(type(v) == 'boolean') then v = tostring(v) msg = msg..delim[5] end msg = msg..v end if not datacache[reqId] then datacache[reqId] = { count = 0, data = {}} end for i=1, msg:len(), splitLength do datacache[reqId].count = datacache[reqId].count + 1 datacache[reqId]['data'][datacache[reqId].count] = msg:sub(i,i+splitLength - 1) end return datacache[reqId] end function CMH.OnReceive(self, event, header, data, Type, sender) if event == 'CHAT_MSG_ADDON' and sender == UnitName('player') and Type == 'WHISPER' then local pfx, source, pckId = header:match('(.)(%u)(.)') if not pfx or not source or not pckId then return end if(pfx == delim[1] and source == 'S') then if(pckId == pck.REQ) then debugOut('REQ', 'Rx', 'REQ received, data: '..data) CMH.OnREQ(sender, data) elseif(pckId == pck.DAT) then debugOut('DAT', 'Rx', 'DAT received, data: '..data) CMH.OnDAT(sender, data) else debugOut('ERR', 'Rx', 'Invalid packet type, aborting') return end end end end local CMHFrame = CreateFrame('Frame') CMHFrame:RegisterEvent('CHAT_MSG_ADDON') CMHFrame:SetScript('OnEvent', CMH.OnReceive) function CMH.OnREQ(sender, data) debugOut('REQ', 'Rx', 'Processing data..') local functionId, linkCount, reqId, addon = data:match('(%d%d)(%d%d%d)(%w%w%w%w%w%w)(.+)'); if not functionId or not linkCount or not reqId or not addon then debugOut('REQ', 'Rx', 'Malformed data, aborting.') return end functionId, linkCount = tonumber(functionId), tonumber(linkCount); if not CMH[addon] then debugOut('REQ', 'Rx', 'Invalid addon, aborting.') return end if not CMH[addon][functionId] then debugOut('REQ', 'Rx', 'Invalid addon function, aborting.') return end if(datacache[reqId]) then datacache[reqId] = nil debugOut('REQ', 'Rx', 'Cache already exists, aborting.') return end datacache[reqId] = {addon = addon, funcId = functionId, count = linkCount, data = {}} debugOut('REQ', 'Rx', 'Header validated, cache created. Awaitng data..') end function CMH.OnDAT(sender, data) debugOut('DAT', 'Rx', 'Validating data..') local reqId = data:sub(1, 6) local payload = data:sub(#reqId+1) if not reqId then debugOut('DAT', 'Rx', 'Request ID missing, aborting.') return end if not datacache[reqId] then debugOut('DAT', 'Rx', 'Cache does not exist, aborting.') return end local reqTable = datacache[reqId] local sizeOfDataCache = #reqTable.data if reqTable.count == 0 then debugOut('DAT', 'Rx', 'Function expects no data, triggering function..') local func = CMH[reqTable.addon][reqTable.funcId] if func then _G[func](sender, {}) datacache[reqId] = nil debugOut('DAT', 'Rx', 'Function '..func..' @ '..reqTable.addon..' executed, cache cleared.') end return end if sizeOfDataCache+1 > reqTable.count then debugOut('DAT', 'Rx', 'Received more data than expected. Aborting.') return end reqTable['data'][sizeOfDataCache+1] = payload sizeOfDataCache = #reqTable.data debugOut('DAT', 'Rx', 'Data part '..sizeOfDataCache..' of '..reqTable.count..' added to cache.') if(sizeOfDataCache == reqTable.count) then debugOut('DAT', 'Rx', 'All expected data received, processing..') local fullPayload = table.concat(reqTable.data); local VarTable = ParseMessage(fullPayload) local func = CMH[reqTable.addon][reqTable.funcId] if func then _G[func](sender, VarTable) datacache[reqId] = nil debugOut('DAT', 'Rx', 'Function '..func..' @ '..reqTable.addon..' executed, cache cleared.') end end end function CMH.SendREQ(functionId, linkCount, reqId, addon) local header = string.format('%01s%01s%01s', delim[1], 'C', pck.REQ) local data = string.format('%02d%03d%06s%0'..tostring(#addon)..'s', functionId, linkCount, reqId, addon) SendAddonMessage(header, data, 'WHISPER', UnitName('player')) debugOut('REQ', 'Tx', 'Sent REQ with ID '..reqId..', Header '..header..', DAT '..data..' sending DAT..') end function CMH.SendDAT(reqId) local header = string.format('%01s%01s%01s', delim[1], 'C', pck.DAT) if(#datacache[reqId]['data'] == 0) then SendAddonMessage(header, reqId, 'WHISPER', UnitName('player')) else for _, v in pairs (datacache[reqId]['data']) do local payload = reqId..v SendAddonMessage(header, payload, 'WHISPER', UnitName('player')) end end datacache[reqId] = nil debugOut('DAT', 'Tx', 'Sent all DAT for ID '..reqId..', cache cleared, closing.') end function RegisterServerResponses(config) if(CMH[config.Prefix]) then return; end CMH[config.Prefix] = {} for functionId, functionName in pairs(config.Functions) do CMH[config.Prefix][functionId] = functionName end end function SendClientRequest(prefix, functionId, ...) local reqId = GenerateReqId() local varTable = ProcessVariables(reqId, ...) CMH.SendREQ(functionId, varTable.count, reqId, prefix) CMH.SendDAT(reqId) end"
		},
		["StatPointUI"] = {
			version = 1,
			compressed = 1,
			cached = 1,
			payload = "local config = {Prefix = 'StatPointUI', Functions = {[1] = 'OnCacheReceived'}} StatPointUI = {['cache'] = {}} function StatPointUI.OnLoad() StatPointUI.mainFrame = CreateFrame('Frame', config.Prefix, CharacterFrame) StatPointUI.mainFrame:SetToplevel(true) StatPointUI.mainFrame:SetSize(200, 260) StatPointUI.mainFrame:SetBackdrop( { bgFile = 'Interface/TutorialFrame/TutorialFrameBackground', edgeFile = 'Interface/DialogFrame/UI-DialogBox-Border', edgeSize = 16, tileSize = 32, insets = {left = 5, right = 5, top = 5, bottom = 5} } ) StatPointUI.mainFrame:SetPoint('TOPRIGHT', 170, -20) StatPointUI.mainFrame:Hide() StatPointUI.titleBar = CreateFrame('Frame', config.Prefix..'TitleBar', StatPointUI.mainFrame) StatPointUI.titleBar:SetSize(135, 25) StatPointUI.titleBar:SetBackdrop( { bgFile = 'Interface/CHARACTERFRAME/UI-Party-Background', edgeFile = 'Interface/DialogFrame/UI-DialogBox-Border', tile = true, edgeSize = 16, tileSize = 16, insets = {left = 5, right = 5, top = 5, bottom = 5} } ) StatPointUI.titleBar:SetPoint('TOP', 0, 9) StatPointUI.titleBarText = StatPointUI.titleBar:CreateFontString(config.Prefix..'TitleBarText') StatPointUI.titleBarText:SetFont('Fonts/FRIZQT__.TTF', 13) StatPointUI.titleBarText:SetSize(190, 5) StatPointUI.titleBarText:SetPoint('CENTER', 0, 0) StatPointUI.titleBarText:SetText('|cffFFC125Attribute Points|r') local rowOffset = -30 local titleOffset = -100 local btnOffset = 40 local rowContent = {'Strength', 'Agility', 'Stamina', 'Intellect', 'Spirit'} for k, v in pairs(rowContent) do StatPointUI[v] = {} StatPointUI[v].Val = StatPointUI.mainFrame:CreateFontString(config.Prefix..v..'Val') StatPointUI[v].Val:SetFont('Fonts/FRIZQT__.TTF', 15) if (k == 1) then StatPointUI[v].Val:SetPoint('CENTER', StatPointUI.titleBar, 'CENTER', 30, rowOffset) else local tmp = rowContent[k - 1] StatPointUI[v].Val:SetPoint('CENTER', StatPointUI[tmp].Val, 'CENTER', 0, rowOffset) end StatPointUI[v].Val:SetText('0') StatPointUI[v].Title = StatPointUI.mainFrame:CreateFontString(config.Prefix..v..'Title') StatPointUI[v].Title:SetFont('Fonts/FRIZQT__.TTF', 15) StatPointUI[v].Title:SetPoint('LEFT', StatPointUI[v].Val, 'LEFT', titleOffset, 0) StatPointUI[v].Title:SetText(v..':') StatPointUI[v].Button = CreateFrame('Button', config.Prefix..v..'Button', StatPointUI.mainFrame) StatPointUI[v].Button:SetSize(20, 20) StatPointUI[v].Button:SetPoint('RIGHT', StatPointUI[v].Val, 'RIGHT', btnOffset, 0) StatPointUI[v].Button:EnableMouse(false) StatPointUI[v].Button:Disable() StatPointUI[v].Button:SetNormalTexture('Interface/BUTTONS/UI-SpellbookIcon-NextPage-Up') StatPointUI[v].Button:SetHighlightTexture('Interface/BUTTONS/UI-Panel-MinimizeButton-Highlight') StatPointUI[v].Button:SetPushedTexture('Interface/BUTTONS/UI-SpellbookIcon-NextPage-Down') StatPointUI[v].Button:SetDisabledTexture('Interface/BUTTONS/UI-SpellbookIcon-NextPage-Disabled') StatPointUI[v].Button:SetScript( 'OnMouseUp', function() SendClientRequest(config.Prefix, 2, k) PlaySound('UChatScrollButton') end ) end StatPointUI.pointsLeftVal = StatPointUI.mainFrame:CreateFontString(config.Prefix..'PointsLeftVal') StatPointUI.pointsLeftVal:SetFont('Fonts/FRIZQT__.TTF', 15) local tmp = rowContent[#rowContent] StatPointUI.pointsLeftVal:SetPoint('CENTER', StatPointUI[tmp].Val, 'CENTER', 0, rowOffset) StatPointUI.pointsLeftVal:SetText('0') StatPointUI.pointsLeftTitle = StatPointUI.mainFrame:CreateFontString(config.Prefix..'PointsLeftVal') StatPointUI.pointsLeftTitle:SetFont('Fonts/FRIZQT__.TTF', 15) StatPointUI.pointsLeftTitle:SetPoint('LEFT', StatPointUI.pointsLeftVal, 'LEFT', titleOffset, 0) StatPointUI.pointsLeftTitle:SetText('Points left:') StatPointUI.resetButton = CreateFrame('Button', config.Prefix..'ResetButton', StatPointUI.mainFrame) StatPointUI.resetButton:SetSize(100, 25) StatPointUI.resetButton:SetPoint('CENTER', StatPointUI.titleBar, 'CENTER', 0, -220) StatPointUI.resetButton:EnableMouse(true) StatPointUI.resetButton:SetText('RESET') StatPointUI.resetButton:SetNormalFontObject('GameFontNormalSmall') local ntex = StatPointUI.resetButton:CreateTexture() ntex:SetTexture('Interface/Buttons/UI-Panel-Button-Up') ntex:SetTexCoord(0, 0.625, 0, 0.6875) ntex:SetAllPoints() StatPointUI.resetButton:SetNormalTexture(ntex) local htex = StatPointUI.resetButton:CreateTexture() htex:SetTexture('Interface/Buttons/UI-Panel-Button-Highlight') htex:SetTexCoord(0, 0.625, 0, 0.6875) htex:SetAllPoints() StatPointUI.resetButton:SetHighlightTexture(htex) local ptex = StatPointUI.resetButton:CreateTexture() ptex:SetTexture('Interface/Buttons/UI-Panel-Button-Down') ptex:SetTexCoord(0, 0.625, 0, 0.6875) ptex:SetAllPoints() StatPointUI.resetButton:SetPushedTexture(ptex) StatPointUI.resetButton:SetScript( 'OnMouseUp', function() SendClientRequest(config.Prefix, 3) PlaySound('UChatScrollButton') end ) PaperDollFrame:HookScript( 'OnShow', function() StatPointUI.mainFrame:Show() end ) PaperDollFrame:HookScript( 'OnHide', function() StatPointUI.mainFrame:Hide() end ) StatPointUI.pointsLeftVal:SetText(StatPointUI.cache[6]) PaperDollFrame:HookScript( 'OnShow', function() StatPointUI.mainFrame:Show() end ) PaperDollFrame:HookScript( 'OnHide', function() StatPointUI.mainFrame:Hide() end ) end function OnCacheReceived(sender, argTable) StatPointUI.cache = argTable[1] local rowContent = {'Strength', 'Agility', 'Stamina', 'Intellect', 'Spirit'} for i = 1, 5 do local rci = rowContent[i] StatPointUI[rci].Val:SetText(StatPointUI.cache[i]) if (StatPointUI.cache[i] > 0) then StatPointUI[rci].Val:SetTextColor(0, 1, 0, 1) else StatPointUI[rci].Val:SetTextColor(1, 1, 1, 1) end if (StatPointUI.cache[6] > 0) then StatPointUI[rci].Button:EnableMouse(true) StatPointUI[rci].Button:Enable() else StatPointUI[rci].Button:EnableMouse(false) StatPointUI[rci].Button:Disable() end end StatPointUI.pointsLeftVal:SetText(StatPointUI.cache[6]) end RegisterServerResponses(config) StatPointUI.OnLoad() SendClientRequest(config.Prefix, 1)"
		},
	}
}

-- Name of the global table storing the injected functionality
local cGTN = "wi"

function Player:SendLargePayload(addon, version, cache, comp, data)
	comp = comp or 0;
	cache = cache or 0;
	local chunk = {}
	local max_size = 900
	
	if(comp == 1) then
		-- payload should be compressed using lzw
		-- lzw can return nil, in that case we don't compress and set flag to 0
		local newstr = lualzw.compress(data)
		if(newstr) then
			data = newstr
		else
			comp = 0;
		end
	end
	
	-- Split string payload into chunks of a specified max size
	while #data > 0 do
		table.insert(chunk, data:sub(1, max_size))
		data = data:sub(max_size + 1)
	end
	
	-- Our max amount is 99 messages per payload.
	if #chunk > 99 then
		return;
	end
	
	-- generate our header
	local cstr = ""
	if(#chunk < 10) then
		cstr = "0"
	end
		cstr = cstr..tostring(#chunk)
	
	for i = 1, #chunk do
		local istr = ""
		if(i < 10) then
			istr = "0"
		end
		istr = istr..tostring(i)
		
		self:SendAddonMessage("ws", "_G['"..cGTN.."'].f.p('"..istr.."', '"..cstr.."', '"..addon.."', "..version..", "..cache..", "..comp..", [["..chunk[i].."]])", 7, self)
	end
end

local function SendPayloadInform(player)
	-- If the player has any payloads already cached, then they will be loaded immediately
	-- Otherwise, full payloads will be requested
	for _, v in ipairs(WardenLoader.order) do
		local t = WardenLoader.data[v]
		player:SendAddonMessage("ws", "_G['"..cGTN.."'].f.i('"..v.."', "..t.version..", "..t.cached..", "..t.compressed..")", 7, player)
	end
end

local function SendAddonInjector(player)
	-- Overwrite reload function
	player:SendAddonMessage("ws", "local copy,new=_G['ReloadUI'];function new() SendAddonMessage('wc', 'reload', 'WHISPER', UnitName('player')) copy() end _G['ReloadUI'] = new", 7, player)
	player:SendAddonMessage("ws", "SlashCmdList['RELOAD'] = function() _G['ReloadUI']() end", 7, player)

	-- Generate helper functions to load larger datasets
	player:SendAddonMessage("ws", "_G['"..cGTN.."'] = {}; _G['"..cGTN.."'].f = {}; _G['"..cGTN.."'].s = {};", 7, player)
	-- Load
	player:SendAddonMessage("ws", "_G['"..cGTN.."'].f.l = function(s, n) loadstring(s)() print('[WardenLoader]: '..n..' loaded!') end", 7, player) 
	-- Concatenate
	player:SendAddonMessage("ws", "_G['"..cGTN.."'].f.c = function(a) local b='' for _,d in ipairs(a) do b=b..d end; return b end", 7, player) 
	-- Execute
	player:SendAddonMessage("ws", "_G['"..cGTN.."'].f.e = function(n) local t=_G['"..cGTN.."']; local lt = t.s[n] local fn = t.f.c(lt.ca); local p, v = GetCVar(n..'Payload'), GetCVar(n..'Version') if(v) then SetCVar(n..'Version', lt.v) else RegisterCVar(n..'Version', tostring(lt.v)) end if(p) then SetCVar(n..'Payload', fn) else RegisterCVar(n..'Payload', fn) end; if(lt.co==1) then fn = lualzw.decompress(fn) end t.f.l(fn, n) t.s[n]=nil end", 7, player)
	-- Process
	player:SendAddonMessage("ws", "_G['"..cGTN.."'].f.p = function(a, b, n, v, c, co, s) local t,tc=_G['"..cGTN.."'], _G['"..cGTN.."'].s; if not tc[n] then tc[n] = {['v']=v, ['co']=co, ['c']=c, ['ca']={}} end local lt = tc[n] a=tonumber(a) b=tonumber(b) table.insert(lt.ca, a, s) if a == b and #lt.ca == b then t.f.e(n) end end", 7, player)
	-- Inform
	-- One potential issue is dependencies, this is something I'll have to look into at some point..
	player:SendAddonMessage("ws", "_G['"..cGTN.."'].f.i = function(n, v, c, co) t=_G['"..cGTN.."']; if(c == 1) then local cv = tonumber(GetCVar(n..'Version')) if(cv and cv == v) then local p = GetCVar(n..'Payload') if(p) then if(co == 1) then p = lualzw.decompress(p) end t.f.l(p, n) return; end end end SendAddonMessage('wc', 'req'..n, 'WHISPER', UnitName('player')) end", 7, player)
	
	-- Sends an inform to the player about the available payloads
	SendPayloadInform(player)
end

local function PushInitModule(eventid, delay, repeats, player)
	if(player:GetData("ModuleInit") == true) then
		player:RemoveEventById(eventid)
		SendAddonInjector(player)
		return;
	end
	
	player:SendAddonMessage("ws", "SendAddonMessage('wc', 'loaded', 'WHISPER', UnitName('player')); print('[WardenLoader]: Warden loader successfully injected. Ready to receive data.')", 7, player)
end

local function AwaitInjection(event, player)
	-- It is possible that the Warden injection happened while on the character screen.
	-- If so, it will not work, so we should set the warden packet as queued "just in case"
	-- This has no impact if the warden packet has not yet been sent, so eh.
	player:QueueWardenPayload()
	player:SendBroadcastMessage("[WardenLoader]: Waiting for Warden injection...")
	-- Register timed event to try and push data to the client.
	player:SetData("ModuleInit", false)
	player:RegisterEvent(PushInitModule, 1000, 0)
end

local function OnAddonMessageReceived(event, player, _type, header, data, target)
	if player:GetName() == target:GetName() and _type == 7 then
		if(header == "wc") then
			if(data == "reload") then
				-- flag the player for re-injection if they reloaded their ui
				AwaitInjection(_, player)
			elseif(data == "loaded") then
				-- module is loaded and ready to receive data
				player:SetData("ModuleInit", true)
			elseif(data:sub(1, 3) == "req") then
				local addon = data:gsub(data:sub(1, 3),'')
				local t = WardenLoader.data[addon]
				if(t) then
					player:SendLargePayload(addon, t.version, t.cached, t.compressed, t.payload)
				end
			end
		end
	end
end

RegisterPlayerEvent(42, SendAddonInjector)
RegisterServerEvent(30, OnAddonMessageReceived)
RegisterPlayerEvent(3, AwaitInjection)