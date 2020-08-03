--[[
	DrunkardSK.lua
		Drunkard Suicide Kings
--]]

DrunkardSK = LibStub("AceAddon-3.0"):NewAddon("DrunkardSK", "AceConsole-3.0", "AceHook-3.0", "AceComm-3.0", "AceSerializer-3.0",  "AceEvent-3.0")

DrunkardSK.bg = {
	bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
	edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
	insets = {left = 11, right = 11, top = 12, bottom = 11},
	tile = true,
	tileSize = 32,
	edgeSize = 32,
}

--master globals
local Master = false;
local BidNotOpen = true;
local ItemLink = nil
local HighRank = 5000
local HighName = ""
local BidsReceived = 0
local BidList = {}
local OffSpecBids = 0
local OffspecList = {}
local OffspecCount = 0
local MUList = {}
local MUCount = 0
local HighRoller = ""
local HighRoll = 0

local PositionBeforeVote = 0
local PositionAfterVote = 0
local LastListUsed

--other globals
local EntrySelected = nil
local MyBidType = ""

--on loot item icon mouseover
local function IconEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
    --GameTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT");
    GameTooltip:SetHyperlink(ItemLink);
    GameTooltip:Show();
	CursorUpdate(self);
end

--no more loot item icon mouseover
local function IconLeave()
	GameTooltip:Hide();
	ResetCursor();
end

--icon on update
local function IconUpdate(self)
	if ( GameTooltip:IsOwned(self) ) then
		IconEnter(self);
	end
	CursorOnUpdate(self);
end

--icon click
local function IconClick(self)
	if ( IsModifiedClick() ) then
		HandleModifiedItemClick(ItemLink);
	end
end

--on mouseover of openlist button
local function OpenListEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("BOTTOMLEFT", self, "TOPRIGHT")
    GameTooltip:SetText("View Lists")
    GameTooltip:Show()
end

--no more mouseover of openlist button
local function OpenListLeave()
	GameTooltip:Hide()
end


--uno reverse
local function UnoReverse(entry, list)
	local suicider = entry;
	local current = entry - 1;

	if(list == "nList") then
		if (PositionBeforeVote ~= PositionAfterVote) then
			for i=current, PositionBeforeVote, -1 do
				if (UnitPlayerOrPetInRaid(DrunkardSK.db.realm.nList[i].name) == 1) then
					--swap selected with current
					local temp = DrunkardSK.db.realm.nList[i];
					DrunkardSK.db.realm.nList[i] = DrunkardSK.db.realm.nList[suicider];
					DrunkardSK.db.realm.nList[suicider] = temp;
					suicider = i;
				end
			end
			DrunkardSK.db.realm.nStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.nStamp);
		end
	else
		if (PositionBeforeVote ~= PositionAfterVote) then
			for i=current, PositionBeforeVote, -1 do
				if (UnitPlayerOrPetInRaid(DrunkardSK.db.realm.tList[i].name) == 1) then
					--swap selected with current
					local temp = DrunkardSK.db.realm.tList[i];
					DrunkardSK.db.realm.tList[i] = DrunkardSK.db.realm.tList[suicider];
					DrunkardSK.db.realm.tList[suicider] = temp;
					suicider = i;
				end
			end
			DrunkardSK.db.realm.tStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.tStamp);
		end
	end
end

--suicide entry
local function Suicide(entry, list)
	local suicider = entry;
	local current = entry + 1;
	PositionBeforeVote = entry;
	LastListUsed = list;

	if(list == "nList") then
		if (current < DrunkardSK.db.realm.nLength) then
			for i=current, DrunkardSK.db.realm.nLength, 1 do
				if (UnitPlayerOrPetInRaid(DrunkardSK.db.realm.nList[i].name) == 1) and (DrunkardSK.db.realm.nList[i].class ~= "ALT") then
					--swap selected with current
					local temp = DrunkardSK.db.realm.nList[i];
					DrunkardSK.db.realm.nList[i] = DrunkardSK.db.realm.nList[suicider];
					DrunkardSK.db.realm.nList[suicider] = temp;
					--set new suicider position
					suicider = i;
				end
			end
			DrunkardSK.db.realm.nStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.nStamp);
		end
	else
		if (current < DrunkardSK.db.realm.tLength) then
			for i=current, DrunkardSK.db.realm.tLength, 1 do
				if (UnitPlayerOrPetInRaid(DrunkardSK.db.realm.tList[i].name) == 1) and (DrunkardSK.db.realm.tList[i].class ~= "ALT") then
					--swap selected with current
					local temp = DrunkardSK.db.realm.tList[i];
					DrunkardSK.db.realm.tList[i] = DrunkardSK.db.realm.tList[suicider];
					DrunkardSK.db.realm.tList[suicider] = temp;
					--set new suicider position
					suicider = i;
				end
			end
			DrunkardSK.db.realm.tStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.tStamp);
		end
	end
	DSKListFrame.selectedEntry = suicider;
	PositionAfterVote = suicider;

	if (Master) then
		ReverseButton:Enable();
	else
		ReverseButton:Disable();
	end
end

--update scroll frame
local function ScrollList_Update()
	local entryOffset = FauxScrollFrame_GetOffset(ScrollList);
	--set hightlight and up/down buttons on selected entry
	for i=1, 18, 1 do
		entryIndex = entryOffset + i;
		if (entryIndex == DSKListFrame.selectedEntry) then
			getglobal("entry"..i):LockHighlight();
			DSKListFrame.down:SetPoint('RIGHT', getglobal("entry"..i), 'RIGHT', -2, 0);
			DSKListFrame.down:Show();
			DSKListFrame.up:Show();
		else
			getglobal("entry"..i):UnlockHighlight();
		end
	end

	--if selected entry is not on screen hide up/down buttons
	if (DSKListFrame.selectedEntry > entryOffset+18) or (DSKListFrame.selectedEntry <= entryOffset) then
		downButton:Hide();
		upButton:Hide();
	end

	--which tab is selected
	if(PanelTemplates_GetSelectedTab(DSKListFrame) == 1) then
		local line; -- 1 through 18 of our window to scroll
		local lineplusoffset; -- an index into our data calculated from the scroll offset
		--loop through and set names and colors in list
		for line=1,18 do
			lineplusoffset = line + FauxScrollFrame_GetOffset(ScrollList);
			if lineplusoffset <= DrunkardSK.db.realm.nLength then
				if (DrunkardSK.db.realm.nList[lineplusoffset].bid == "") or (Master == false) then
					getglobal("entry"..line).text:SetText(lineplusoffset..". "..DrunkardSK.db.realm.nList[lineplusoffset].name);
				elseif (Master) then
					getglobal("entry"..line).text:SetText(lineplusoffset..". "..DrunkardSK.db.realm.nList[lineplusoffset].name.." - "..DrunkardSK.db.realm.nList[lineplusoffset].bid);
				end
				if (UnitPlayerOrPetInRaid(DrunkardSK.db.realm.nList[lineplusoffset].name) == 1) then
					if (DrunkardSK.db.realm.nList[lineplusoffset].class == "ALT") then
						getglobal("entry"..line).text:SetTextColor(255, 0, 255);
					else
						local color = RAID_CLASS_COLORS[DrunkardSK.db.realm.nList[lineplusoffset].class];
						getglobal("entry"..line).text:SetTextColor(color.r, color.g, color.b);
					end

				else
					getglobal("entry"..line).text:SetTextColor(0.5, 0.5, 0.5);
				end
				getglobal("entry"..line).text:Show();
			else
				getglobal("entry"..line).text:Hide();
			end
		end

		--disable up/down if top/bottom entry selected
		if(DSKListFrame.selectedEntry == 1) and Master then
			upButton:Disable();
		elseif Master then
			upButton:Enable();
		end

		if(DSKListFrame.selectedEntry == DrunkardSK.db.realm.nLength) and Master then
			downButton:Disable();
		elseif Master then
			downButton:Enable();
		end

		if(DSKListFrame.selectedEntry > DrunkardSK.db.realm.nLength) and Master then
			downButton:Disable();
			upButton:Disable();
		end

		FauxScrollFrame_Update(ScrollList,DrunkardSK.db.realm.nLength,18,16);
	elseif(PanelTemplates_GetSelectedTab(DSKListFrame) == 2) then
		local line; -- 1 through 18 of our window to scroll
		local lineplusoffset; -- an index into our data calculated from the scroll offset
		--loop through and set names and colors in list
		for line=1,18 do
			lineplusoffset = line + FauxScrollFrame_GetOffset(ScrollList);
			if lineplusoffset <= DrunkardSK.db.realm.tLength then
				if (DrunkardSK.db.realm.tList[lineplusoffset].bid == "") or (Master == false) then
					getglobal("entry"..line).text:SetText(lineplusoffset..". "..DrunkardSK.db.realm.tList[lineplusoffset].name);
				else
					getglobal("entry"..line).text:SetText(lineplusoffset..". "..DrunkardSK.db.realm.tList[lineplusoffset].name.." - "..DrunkardSK.db.realm.tList[lineplusoffset].bid);
				end
				if (UnitPlayerOrPetInRaid(DrunkardSK.db.realm.tList[lineplusoffset].name) == 1) then
					if (DrunkardSK.db.realm.tList[lineplusoffset].class == "ALT") then
						getglobal("entry"..line).text:SetTextColor(255, 0, 255);
					else
						local color = RAID_CLASS_COLORS[DrunkardSK.db.realm.tList[lineplusoffset].class];
						getglobal("entry"..line).text:SetTextColor(color.r, color.g, color.b);
					end
				else
					getglobal("entry"..line).text:SetTextColor(0.5, 0.5, 0.5);
				end
				getglobal("entry"..line).text:Show();
			else
				getglobal("entry"..line).text:Hide();
			end
		end

		--disable up/down if top/bottom entry selected
		if(DSKListFrame.selectedEntry == 1) and Master then
			upButton:Disable();
		elseif Master then
			upButton:Enable();
		end

		if(DSKListFrame.selectedEntry == DrunkardSK.db.realm.tLength) and Master then
			downButton:Disable();
		elseif Master then
			downButton:Enable();
		end

		if(DSKListFrame.selectedEntry > DrunkardSK.db.realm.tLength) and Master then
			downButton:Disable();
			upButton:Disable();
		end

		FauxScrollFrame_Update(ScrollList,DrunkardSK.db.realm.tLength,18,16);
	end
end

--on Token tab click
local function ClickTTab()
	PlaySound("igCharacterInfoTab");
	PanelTemplates_SetTab(DSKListFrame, 2);
	DSKListFrame.title:SetText("Token List");
	DSKListFrame.selectedEntry = 0;
	DSKListFrame.add:Show();
	DSKListFrame.del:Show();
	DSKListFrame.up:Show();
	DSKListFrame.down:Show();
	DSKListFrame.murder:Show();
	DSKListFrame.closeBid:Show();
	DSKListFrame.sync:Show();
	DSKListFrame.list:Show();
	DSKListFrame.entry1:Show();
	DSKListFrame.entry2:Show();
	DSKListFrame.entry3:Show();
	DSKListFrame.entry4:Show();
	DSKListFrame.entry5:Show();
	DSKListFrame.entry6:Show();
	DSKListFrame.entry7:Show();
	DSKListFrame.entry8:Show();
	DSKListFrame.entry9:Show();
	DSKListFrame.entry10:Show();
	DSKListFrame.entry11:Show();
	DSKListFrame.entry12:Show();
	DSKListFrame.entry13:Show();
	DSKListFrame.entry14:Show();
	DSKListFrame.entry15:Show();
	DSKListFrame.entry16:Show();
	DSKListFrame.entry17:Show();
	DSKListFrame.entry18:Show();
	DSKListFrame.import:Hide();
	DSKListFrame.export:Hide();
	DSKListFrame.tokenRadio:Hide();
	DSKListFrame.normalRadio:Hide();
	DSKListFrame.editScroll:Hide();
	DSKListFrame.reverse:Show();
	ScrollList_Update();
end

--on Normal Tab click
local function ClickNTab()
	PlaySound("igCharacterInfoTab");
	PanelTemplates_SetTab(DSKListFrame, 1);
	DSKListFrame.title:SetText("Normal List");
	DSKListFrame.selectedEntry = 0;
	DSKListFrame.add:Show();
	DSKListFrame.del:Show();
	DSKListFrame.up:Show();
	DSKListFrame.down:Show();
	DSKListFrame.murder:Show();
	DSKListFrame.closeBid:Show();
	DSKListFrame.sync:Show();
	DSKListFrame.list:Show();
	DSKListFrame.entry1:Show();
	DSKListFrame.entry2:Show();
	DSKListFrame.entry3:Show();
	DSKListFrame.entry4:Show();
	DSKListFrame.entry5:Show();
	DSKListFrame.entry6:Show();
	DSKListFrame.entry7:Show();
	DSKListFrame.entry8:Show();
	DSKListFrame.entry9:Show();
	DSKListFrame.entry10:Show();
	DSKListFrame.entry11:Show();
	DSKListFrame.entry12:Show();
	DSKListFrame.entry13:Show();
	DSKListFrame.entry14:Show();
	DSKListFrame.entry15:Show();
	DSKListFrame.entry16:Show();
	DSKListFrame.entry17:Show();
	DSKListFrame.entry18:Show();
	DSKListFrame.import:Hide();
	DSKListFrame.export:Hide();
	DSKListFrame.tokenRadio:Hide();
	DSKListFrame.normalRadio:Hide();
	DSKListFrame.editScroll:Hide();
	DSKListFrame.reverse:Show();
	ScrollList_Update();
end

--on i/e Tab click
local function ClickITab()
	PlaySound("igCharacterInfoTab");
	PanelTemplates_SetTab(DSKListFrame, 3);
	DSKListFrame.title:SetText("Import/Export Lists");
	DSKListFrame.add:Hide();
	DSKListFrame.del:Hide();
	DSKListFrame.up:Hide();
	DSKListFrame.down:Hide();
	DSKListFrame.murder:Hide();
	DSKListFrame.closeBid:Hide();
	DSKListFrame.sync:Hide();
	DSKListFrame.list:Hide();
	DSKListFrame.entry1:Hide();
	DSKListFrame.entry2:Hide();
	DSKListFrame.entry3:Hide();
	DSKListFrame.entry4:Hide();
	DSKListFrame.entry5:Hide();
	DSKListFrame.entry6:Hide();
	DSKListFrame.entry7:Hide();
	DSKListFrame.entry8:Hide();
	DSKListFrame.entry9:Hide();
	DSKListFrame.entry10:Hide();
	DSKListFrame.entry11:Hide();
	DSKListFrame.entry12:Hide();
	DSKListFrame.entry13:Hide();
	DSKListFrame.entry14:Hide();
	DSKListFrame.entry15:Hide();
	DSKListFrame.entry16:Hide();
	DSKListFrame.entry17:Hide();
	DSKListFrame.entry18:Hide();
	DSKListFrame.import:Show();
	DSKListFrame.export:Show();
	DSKListFrame.tokenRadio:Show();
	DSKListFrame.normalRadio:Show();
	DSKListFrame.editScroll:Show();
	DSKListFrame.reverse:Hide();
	--DSKListFrame.selectedEntry = 0;
	--ScrollList_Update();
end

--on open list click
local function OpenListClick()
	ScrollList_Update();
	DSKListFrame:Show()
end

--on entry button click
local function EntrySelect(self)
	DSKListFrame.selectedEntry = FauxScrollFrame_GetOffset(ScrollList) + self:GetID()
	ScrollList_Update()
end

local function EntryClick(self, button, down)
	EntrySelect(self);
end


function DrunkardSK:GibPlayerClass()

	local guildName, rankName, rankIndex = GetGuildInfo("target");
	local playerClass;

	if (guildName ~= nil) and (guildName == "Forsaken") and (rankName == "Alt" or rankName == "Executor alt") then
		playerClass = "ALT";
	else
		local _, englishClass = UnitClass("target");
		playerClass = englishClass;
	end

	return playerClass;
end


--on add button click
local function AddClick(self, button, down)
	if(PanelTemplates_GetSelectedTab(DSKListFrame) == 1) and (BidNotOpen) and (DrunkardSK:FindInTable(UnitName("target"),"nList") == 0) then
		if (UnitExists("target") == 1) and (UnitIsPlayer("target") == 1) then
			if (DrunkardSK.db.realm.nLength == nil) then
				DrunkardSK.db.realm.nLength = 0;
			end
			if (DrunkardSK.db.realm.nList == nil) then
				DrunkardSK.db.realm.nList = {};
			end

			-- start with zero
			local lastPersonIndex = DrunkardSK.db.realm.nLength;
			-- assume that you should add the player at the end of the list
			local whereToInsert = DrunkardSK.db.realm.nLength + 1;
			DrunkardSK.db.realm.nLength = DrunkardSK.db.realm.nLength + 1;

			-- if index = 0 it means that no players are in the list, whereToInsert equals 1
			if (lastPersonIndex ~= 0) then
				for i = lastPersonIndex, 1, -1 do
					-- check if alt, alts are always on the bottom of the list, loops looks for the highest alt on the list
					if (DrunkardSK.db.realm.nList[i].class == "ALT") then
						whereToInsert = i;
					end
				end
			end

			local playerClass = DrunkardSK:GibPlayerClass();

			if (whereToInsert == lastPersonIndex+1) or (playerClass == "ALT") then
				DrunkardSK.db.realm.nList[DrunkardSK.db.realm.nLength] = {name = UnitName("target"), class = playerClass, bid = ""};
			else
				--DrunkardSK.db.realm.nList[lastPersonIndex+1] = {name = DrunkardSK.db.realm.nList[whereToInsert].name, class = DrunkardSK.db.realm.nList[whereToInsert].class, bid = ""};
				--DrunkardSK.db.realm.nList[whereToInsert] = {name = UnitName("target"), class = playerClass, bid = ""};


				DrunkardSK.db.realm.nList[lastPersonIndex+1] = {name = DrunkardSK.db.realm.nList[lastPersonIndex].name, class = DrunkardSK.db.realm.nList[lastPersonIndex].class, bid = ""};

				for i = DrunkardSK.db.realm.nLength, whereToInsert, -1 do
					DrunkardSK.db.realm.nList[i] = {name = DrunkardSK.db.realm.nList[i - 1].name, class = DrunkardSK.db.realm.nList[i - 1].class, bid = ""};
				end

				DrunkardSK.db.realm.nList[whereToInsert] = {name = UnitName("target"), class = playerClass, bid = ""};
			end

			DrunkardSK.db.realm.nStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.nStamp);
		end
	elseif(PanelTemplates_GetSelectedTab(DSKListFrame) == 2) and (BidNotOpen) and (DrunkardSK:FindInTable(UnitName("target"),"tList") == 0) then
		if (UnitExists("target") == 1) and (UnitIsPlayer("target") == 1) then
			if (DrunkardSK.db.realm.tLength == nil) then
				DrunkardSK.db.realm.tLength = 0;
			end
			if (DrunkardSK.db.realm.tList == nil) then
				DrunkardSK.db.realm.tList = {};
			end

			-- start with zero
			local lastPersonIndex = DrunkardSK.db.realm.tLength;
			-- assume that you should add the player at the end of the list
			local whereToInsert = DrunkardSK.db.realm.tLength + 1;
			DrunkardSK.db.realm.tLength = DrunkardSK.db.realm.tLength + 1;

			-- if index = 0 it means that no players are in the list, whereToInsert equals 1
			if (lastPersonIndex ~= 0) then
				for i = lastPersonIndex, 1, -1 do
					-- check if alt, alts are always on the bottom of the list, loops looks for the highest alt on the list
					if (DrunkardSK.db.realm.tList[i].class == "ALT") then
						whereToInsert = i;
					end
				end
			end

			local playerClass = DrunkardSK:GibPlayerClass();

			if (whereToInsert == lastPersonIndex+1) or (playerClass == "ALT") then
				DrunkardSK.db.realm.tList[DrunkardSK.db.realm.tLength] = {name = UnitName("target"), class = playerClass, bid = ""};
			else

				DrunkardSK.db.realm.tList[lastPersonIndex+1] = {name = DrunkardSK.db.realm.tList[lastPersonIndex].name, class = DrunkardSK.db.realm.tList[lastPersonIndex].class, bid = ""};

				for i = DrunkardSK.db.realm.tLength, whereToInsert, -1 do
					DrunkardSK.db.realm.tList[i] = {name = DrunkardSK.db.realm.tList[i - 1].name, class = DrunkardSK.db.realm.tList[i - 1].class, bid = ""};
				end

				DrunkardSK.db.realm.tList[whereToInsert] = {name = UnitName("target"), class = playerClass, bid = ""};

			end

			DrunkardSK.db.realm.tStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.tStamp);

		end

		elseif (PanelTemplates_GetSelectedTab(DSKListFrame) == 1) and (DrunkardSK:FindInTable(UnitName("target"),"nList") ~= 0) then
			DrunkardSK:Print(UnitName("target").." is already on the normal list you blind fool!");

		elseif (PanelTemplates_GetSelectedTab(DSKListFrame) == 2) and (DrunkardSK:FindInTable(UnitName("target"),"tList") ~= 0) then
				DrunkardSK:Print(UnitName("target").." is already on the token list you blind fool!");

	elseif(BidNotOpen == false) then
		DrunkardSK:Print("You cannot add players while vote is active. Close the vote first");
	end
	DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
	ScrollList_Update();
end

--on up button click
local function UpClick(self, button, down)
	if(PanelTemplates_GetSelectedTab(DSKListFrame) == 1) and (BidNotOpen) then
		local temp = DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry];
		DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry] = DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry-1];
		DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry-1] = temp;
		DSKListFrame.selectedEntry = DSKListFrame.selectedEntry-1;
		DrunkardSK.db.realm.nStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.nStamp);
	elseif(PanelTemplates_GetSelectedTab(DSKListFrame) == 2) and (BidNotOpen)then
		local temp = DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry];
		DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry] = DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry-1];
		DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry-1] = temp;
		DSKListFrame.selectedEntry = DSKListFrame.selectedEntry-1;
		DrunkardSK.db.realm.tStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.tStamp);

	elseif(BidNotOpen == false) then
		DrunkardSK:Print("You cannot change position on the list while vote is active. Close the vote first");
	end
	ScrollList_Update();
end

--on down button click
local function DownClick(self, button, down)
	if(PanelTemplates_GetSelectedTab(DSKListFrame) == 1) and (BidNotOpen)then
		local temp = DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry];
		DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry] = DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry+1];
		DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry+1] = temp;
		DSKListFrame.selectedEntry = DSKListFrame.selectedEntry+1;
		DrunkardSK.db.realm.nStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.nStamp);
	elseif(PanelTemplates_GetSelectedTab(DSKListFrame) == 2) and (BidNotOpen) then
		local temp = DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry];
		DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry] = DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry+1];
		DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry+1] = temp;
		DSKListFrame.selectedEntry = DSKListFrame.selectedEntry+1;
		DrunkardSK.db.realm.tStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.tStamp);

	elseif(BidNotOpen == false) then
		DrunkardSK:Print("You cannot change position on the list while vote is active. Close the vote first");
	end
	ScrollList_Update();
end

--on delete button click
local function DeleteClick(self, button, down)
	if(DSKListFrame.selectedEntry ~= 0) and (BidNotOpen) then
		if(PanelTemplates_GetSelectedTab(DSKListFrame) == 1) then
			if(DrunkardSK.db.realm.nLength > 0) then
				table.remove(DrunkardSK.db.realm.nList, DSKListFrame.selectedEntry)
				DrunkardSK.db.realm.nLength = DrunkardSK.db.realm.nLength - 1;
				DrunkardSK.db.realm.nStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.nStamp);
			end
		elseif(PanelTemplates_GetSelectedTab(DSKListFrame) == 2) then
			if(DrunkardSK.db.realm.tLength > 0) then
				table.remove(DrunkardSK.db.realm.tList, DSKListFrame.selectedEntry);
				DrunkardSK.db.realm.tLength = DrunkardSK.db.realm.tLength - 1;
				DrunkardSK.db.realm.tStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.tStamp);
			end
		end
		DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
		ScrollList_Update();

	elseif(BidNotOpen == false) then
		DrunkardSK:Print("You cannot delete players while vote is active. Close the vote first");
	end
end

local function ReverseTheBid(self, button, down)

	UnoReverse(PositionAfterVote,LastListUsed);
	SendChatMessage("Last vote got cancelled, positions changed to the one before the vote", "RAID");
	DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
	ScrollList_Update();
	LastListUsed = "";
	PositionBeforeVote = 0;
	PositionAfterVote = 0;
	ReverseButton:Disable();

end

local function CloseFrame(self, button, down)

	SendChatMessage("Master looter closed the frame", "RAID");
	--reset everything
	HighRank = 5000;
	HighName = "";
	BidsReceived = 0;
	OffSpecBids = 0;
	ItemLink = nil;
	BidList = {};
	OffspecList = {};
	OffspecCount = 0;
	MUList = {};
	MUCount = 0;
	HighRoller = "";
	HighRoll = 0;
	BidNotOpen = true;

	DrunkardSK:SendCommMessage("DSKCloseBid", "cb", "RAID");
	DSKListFrame.closeBid:Disable();
	ScrollList_Update();

end

--close bid button click
local function CloseBidClick(self, button, down)
    local list = DrunkardSK:WhichList();
	local fuckup = 0;
    -- check if frame is selected, then check if correct list is selected otherwise display a error message
    if (DSKListFrame.selectedEntry ~= 0) then
        if (list == "nList") and (PanelTemplates_GetSelectedTab(DSKListFrame) == 1) then
            SendChatMessage("LC decided that "..ItemLink.." goes to ".. DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry].name, "RAID");

			if (DrunkardSK.db.realm.nList[DSKListFrame.selectedEntry].bid == "MS") then
				Suicide(DSKListFrame.selectedEntry, list);
			end

			DSKListFrame.selectedEntry = 0;
            DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
	    elseif (list == "tList") and (PanelTemplates_GetSelectedTab(DSKListFrame) == 2) then
	        SendChatMessage("LC decided that "..ItemLink.." goes to ".. DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry].name, "RAID");

			if (DrunkardSK.db.realm.tList[DSKListFrame.selectedEntry].bid == "MS") then
				Suicide(DSKListFrame.selectedEntry, list);
			end
            DSKListFrame.selectedEntry = 0;
            DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
        else
        	SendChatMessage("Master looter tried to close the bids while using a wrong list. Good thing that our beloved GM thought about it and blocked the action", "RAID");
			fuckup = 1;
	    end
	elseif (HighName ~= "") then
		SendChatMessage(HighName.." wins "..ItemLink.."!", "RAID");
		Suicide(HighRank, list);
		DSKListFrame.selectedEntry = 0;
		DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
	elseif (HighRoller ~= "") then
		-- if roll > 1000 it means that roll was an offspec, everything lower then 1000 means MU
		if (HighRoll > 1000) then
			SendChatMessage(HighRoller.." wins "..ItemLink.." with a roll of "..HighRoll.." (Offspec)", "RAID");
		else
			SendChatMessage(HighRoller.." wins "..ItemLink.." with a roll of "..HighRoll.." (Minor upgrade)", "RAID");
		end

		DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
	end

	if(fuckup == 0) then
		--reset everything
		HighRank = 5000;
		HighName = "";
		BidsReceived = 0;
		OffSpecBids = 0;
		ItemLink = nil;
		BidList = {};
		OffspecList = {};
		OffspecCount = 0;
		MUList = {};
		MUCount = 0;
		HighRoller = "";
		HighRoll = 0;
		BidNotOpen = true;

		DrunkardSK:SendCommMessage("DSKCloseBid", "cb", "RAID");

		DSKListFrame.closeBid:Disable();

		ScrollList_Update();
	end

end

--murder button click
local function MurderClick(self, button, down)
	local list;
	if (DSKListFrame.selectedEntry ~= 0) and (BidNotOpen) then
		if(PanelTemplates_GetSelectedTab(DSKListFrame) == 1) then
			list = "nList";
		elseif(PanelTemplates_GetSelectedTab(DSKListFrame) == 2) then
			list = "tList";
		end
		Suicide(DSKListFrame.selectedEntry, list);
		DSKListFrame.selectedEntry = 0;
		DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
		ScrollList_Update();
	elseif(BidNotOpen == false) then
		DrunkardSK:Print("You cannot murder someone while vote is active. Close the vote first");
	end
end

--sync button click
local function SyncClick(self, button, down)
	if (Master) then
		--send sync req with master
		DrunkardSK:SendCommMessage("DSKSyncReq", "master", "RAID");
	else
		--send sync req without master
		DrunkardSK:SendCommMessage("DSKSyncReq", "not master", "RAID");
	end
end

--export click
local function ExportClick(self, button, down)
	local exportList = "";

	if(DSKListFrame.normalRadio:GetChecked() == 1) then
		for i=1, DrunkardSK.db.realm.nLength, 1 do
			exportList = exportList..i..". "..DrunkardSK.db.realm.nList[i].name.." "..strlower(DrunkardSK.db.realm.nList[i].class).."\n";
		end
		DSKListFrame.editArea:SetText(exportList);
		DSKListFrame.editArea:HighlightText(0);

	elseif(DSKListFrame.tokenRadio:GetChecked() == 1) then
		for i=1, DrunkardSK.db.realm.tLength, 1 do
			exportList = exportList..i..". "..DrunkardSK.db.realm.tList[i].name.." "..strlower(DrunkardSK.db.realm.tList[i].class).."\n";
		end
		DSKListFrame.editArea:SetText(exportList);
		DSKListFrame.editArea:HighlightText(0);
	end
end

--import click
local function ImportClick(self, button, down)
--DrunkardSK:Print("Import functionality is not currently implemented... but how did you manage to hit the button?");
	DSKConfirmFrame:Show();
end

local function NormalRadioClick(self, button, down)
	DSKListFrame.tokenRadio:SetChecked(nil);
end

local function TokenRadioClick(self, button, down)
	DSKListFrame.normalRadio:SetChecked(nil);
end

--bid button click
local function BidClick(self, button, down)
	MyBidType = "bid";
	DrunkardSK:SendCommMessage("DSKSendBid", DrunkardSK:Serialize(MyBidType, UnitName("player")), "RAID");
	DSKBidFrame.offspec:Disable();
	DSKBidFrame.pass:Disable();
	DSKBidFrame.bid:Disable();
	DSKBidFrame.bidMU:Disable();
	DSKBidFrame.retract:Enable();
end

local function MUClick(self, button, down)
	MyBidType = "MU";
	DrunkardSK:SendCommMessage("DSKSendBid", DrunkardSK:Serialize(MyBidType, UnitName("player")), "RAID");
	DSKBidFrame.bid:Disable();
	DSKBidFrame.offspec:Disable();
	DSKBidFrame.pass:Disable();
	DSKBidFrame.bidMU:Disable();
	DSKBidFrame.retract:Enable();
end

--offspec button click
local function OffspecClick(self, button, down)
	MyBidType = "offspec";
	DrunkardSK:SendCommMessage("DSKSendBid", DrunkardSK:Serialize(MyBidType, UnitName("player")), "RAID");
	DSKBidFrame.offspec:Disable();
	DSKBidFrame.pass:Disable();
	DSKBidFrame.bid:Disable();
	DSKBidFrame.bidMU:Disable();
	DSKBidFrame.retract:Enable();
end

--pass button click
local function PassClick(self, button, down)
	MyBidType = "pass";
	DrunkardSK:SendCommMessage("DSKSendBid", DrunkardSK:Serialize(MyBidType, UnitName("player")), "RAID");
	DSKBidFrame.offspec:Disable();
	DSKBidFrame.pass:Disable();
	DSKBidFrame.bid:Disable();
	DSKBidFrame.bidMU:Disable();
	DSKBidFrame.retract:Enable();
end

--retract button click
local function RetractClick(self, button, down)
	DrunkardSK:SendCommMessage("DSKSendRetract", DrunkardSK:Serialize(MyBidType, UnitName("player")), "RAID");
	DSKBidFrame.offspec:Enable();
	DSKBidFrame.pass:Enable();
	DSKBidFrame.bidMU:Enable();
	DSKBidFrame.retract:Disable();

	if(DrunkardSK:CheckIfAlt()) then
		DSKBidFrame.bid:Disable();
	else
		DSKBidFrame.bid:Enable();
	end

end

--accept button click
local function AcceptClick(self, button, down)
	local text = DSKListFrame.editArea:GetText();
	local i = 1;
	local found, e, rank, pname, class, uclass;

	if (DSKListFrame.normalRadio:GetChecked() == 1) then
		DrunkardSK.db.realm.nLength = 0;
		DrunkardSK.db.realm.nList = {};
	elseif (DSKListFrame.tokenRadio:GetChecked() == 1) then
		DrunkardSK.db.realm.tLength = 0;
		DrunkardSK.db.realm.tList = {};
	end

	local listOfImportedPlayers = {};

	while 1 do
		found, e, rank, pname, class = string.find(text, "(%d+)%p%s(%a+)%s(%a+)", i);
		if (found == nil) then
			break;
		else

			for i = 1, table.getn(listOfImportedPlayers), 1 do
				if(pname == listOfImportedPlayers[i]) then
					DrunkardSK:Print(pname.." is on the list more then once!");
					DSKConfirmFrame:Hide();
					return;
				else

				end
			end
			table.insert(listOfImportedPlayers, pname)

			uclass = strupper(class);
			--DrunkardSK:Print(rank.." "..pname.." "..uclass);

			--make sure entered classes are actually classes
			if ((uclass ~= "SHAMAN") and (uclass ~= "PALADIN") and (uclass ~= "DRUID") and (uclass ~= "WARRIOR") and (uclass ~= "ROGUE") and
			(uclass ~= "DEATHKNIGHT") and (uclass ~= "PRIEST") and (uclass ~= "WARLOCK") and (uclass ~= "MAGE") and (uclass ~= "HUNTER") and
					(uclass ~= "ALT")) then
				DrunkardSK:Print("Error: "..class.." is not a valid class!");
				break;
			end

			--name to vars
			--class to vars
			if (DSKListFrame.normalRadio:GetChecked() == 1) then
				DrunkardSK.db.realm.nLength = DrunkardSK.db.realm.nLength + 1;

				DrunkardSK.db.realm.nList[DrunkardSK.db.realm.nLength] = {name = pname, class = uclass, bid = ""};
				DrunkardSK.db.realm.nStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.nStamp);

			elseif (DSKListFrame.tokenRadio:GetChecked() == 1) then
				DrunkardSK.db.realm.tLength = DrunkardSK.db.realm.tLength + 1;

				DrunkardSK.db.realm.tList[DrunkardSK.db.realm.tLength] = {name = pname, class = uclass, bid = ""};
				DrunkardSK.db.realm.tStamp = DrunkardSK:CreateTimeStamp(DrunkardSK.db.realm.tStamp);
			end

		end
		i = e + 1;
	end

	DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
	ScrollList_Update();

	DSKConfirmFrame:Hide();
end

--decline button click
local function DeclineClick(self, button, down)
	DSKConfirmFrame:Hide();
end

--[[
	Loading/Profile Functions
--]]



function DrunkardSK:OnInitialize()
--DrunkardSK:Print(HandleModifiedItemClick);
	--saved vars
	self.db = LibStub("AceDB-3.0"):New("DrunkardSKDB")

	if (DrunkardSK.db.realm.nLength == nil) then
		DrunkardSK.db.realm.nLength = 0;
	end
	if (DrunkardSK.db.realm.tLength == nil) then
		DrunkardSK.db.realm.tLength = 0;
	end

	if (DrunkardSK.db.realm.nStamp == nil) then
		DrunkardSK.db.realm.nStamp = 0;
	end
	if (DrunkardSK.db.realm.tStamp == nil) then
		DrunkardSK.db.realm.tStamp = 0;
	end



	--slash command
	DrunkardSK:RegisterChatCommand("dsk", "OpenList")
	DrunkardSK:RegisterChatCommand("DSK", "OpenList")

	--set bids in list to ensure backwards compatability
	if (DrunkardSK.db.realm.nLength > 0) then
		for i=1, DrunkardSK.db.realm.nLength, 1 do
			DrunkardSK.db.realm.nList[i].bid = "";
		end
	end

	if (DrunkardSK.db.realm.tLength > 0) then
		for i=1, DrunkardSK.db.realm.tLength, 1 do
			DrunkardSK.db.realm.tList[i].bid = "";
		end
	end

end

function DrunkardSK:OnEnable()
    -- Called when the addon is enabled
	--hooks
	--hookexists, hookhandler = DrunkardSK:IsHooked("HandleModifiedItemClick")
	--if(hookexists == false) then
	--	DrunkardSK:SecureHook("HandleModifiedItemClick", "DSK_HandleModifiedItemClick")
	--end
--DrunkardSK:Print(HandleModifiedItemClick);
	--set bids in list to ensure backwards compatability

	local f = CreateFrame('Frame', 'DSKBidFrame', UIParent)
	f:Hide()

	f:SetWidth(400);
	f:SetHeight(150);
	f:SetPoint("CENTER");
	f:SetBackdrop(DrunkardSK.bg)
	f:EnableMouse(true)
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:SetFrameStrata('DIALOG')
	f:SetScript('OnMouseDown', f.StartMoving)
	f:SetScript('OnMouseUp', f.StopMovingOrSizing)

	--title text
	f.text = f:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	f.text:SetText('<No High Bidder>')
	f.text:SetPoint('TOP', 0, -15)

	--item link
	f.link = CreateFrame('ScrollingMessageFrame', nil, f)
	f.link:SetWidth(290)
	f.link:SetHeight(14)
	f.link:SetMaxLines(1)
	f.link:SetFontObject("GameFontNormal");
	f.link:EnableMouse(true)
	f.link:SetScript("OnHyperlinkClick", ChatFrame_OnHyperlinkShow)
	f.link:SetFading(false)
	f.link:SetPoint('CENTER', 0, -45)

	--item icon
	f.item = CreateFrame('Button', "ItemIcon", f, "ItemButtonTemplate")
	--f.item:SetNormalTexture(GetItemIcon(itemID))
	f.item:SetScale(1.3);
	f.item:EnableMouse(true)
	f.item:SetPoint('CENTER', 0, 2.5)
	f.item.hasItem = 1;
	f.item:Show()
	f.item:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	f.item:SetScript("OnEnter", IconEnter);
	f.item:SetScript("OnLeave", IconLeave);
	f.item:SetScript("OnUpdate", IconUpdate);
	f.item:SetScript("OnClick", IconClick);

	--ms button
	f.bid = CreateFrame('Button', nil, f, "OptionsButtonTemplate")
	f.bid:SetText('Main spec')
	f.bid:SetPoint('TOPLEFT', 30, -35)
	f.bid:SetScript('OnClick', BidClick)
	f.bid:SetWidth(120)


	--offspec button
	f.offspec = CreateFrame('Button', nil, f, "OptionsButtonTemplate")
	f.offspec:SetText('Offspec / alt')
	f.offspec:SetPoint('TOPLEFT', 30, -60)
	f.offspec:SetScript('OnClick', OffspecClick)
	f.offspec:SetWidth(120)

	--mu button
	f.bidMU = CreateFrame('Button', nil, f, "OptionsButtonTemplate")
	f.bidMU:SetText('Minor Upgrade')
	f.bidMU:SetPoint('TOPLEFT', 30, -85)
	f.bidMU:SetScript('OnClick', MUClick)
	f.bidMU:SetWidth(120)

	--retract button
	f.retract = CreateFrame('Button', nil, f, "OptionsButtonTemplate")
	f.retract:SetText('Retract')
	f.retract:SetPoint('TOPRIGHT', -30, -35)
	f.retract:SetScript('OnClick', RetractClick)
	f.retract:Disable()
	f.retract:SetWidth(120)

	--pass button
	f.pass = CreateFrame('Button', nil, f, "OptionsButtonTemplate")
	f.pass:SetText('Pass')
	f.pass:SetPoint('TOPRIGHT', -30, -60)
	f.pass:SetScript('OnClick', PassClick)
	f.pass:SetWidth(120)

	--close button
	f.closeF = CreateFrame('Button', closeFrameButton, f, 'UIPanelCloseButton')
	f.closeF:SetPoint('TOPRIGHT', -5, -5)
	f.closeF:SetScript("OnClick", CloseFrame)
	f.closeF:Hide();

	--open list button
	f.openList = CreateFrame('Button', nil, f, 'OptionsButtonTemplate')
	f.openList:SetPoint('TOPRIGHT', -30, -85)
	f.openList:SetText('View list')
	f.openList:SetScript("OnClick", OpenListClick)
	f.openList:SetWidth(120)

	local l = CreateFrame('Frame', 'DSKListFrame', UIParent)
	l:Hide()

	l:SetWidth(250);
	l:SetHeight(400);
	l:SetPoint("CENTER");
	l:SetBackdrop(DrunkardSK.bg)
	l:EnableMouse(true)
	l:SetToplevel(true)
	l:SetMovable(true)
	l:SetClampedToScreen(true)
	l:SetFrameStrata('DIALOG')
	l:SetScript('OnMouseDown', l.StartMoving)
	l:SetScript('OnMouseUp', l.StopMovingOrSizing)

	--listframe title
	l.title = l:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	l.title:SetText('Normal List')
	l.title:SetPoint('TOP', 0, -15)

	--close button
	l.close = CreateFrame('Button', nil, l, 'UIPanelCloseButton')
	l.close:SetPoint('TOPRIGHT', -5, -5)

	--normal list tab
	l.nTab = CreateFrame('Button', 'DSKListFrameTab1', l, "CharacterFrameTabButtonTemplate")
	l.nTab:SetPoint('CENTER', l, 'BOTTOMLEFT', 50, -10)
	l.nTab:SetID(1)
	l.nTab:SetText('Normal List')
	l.nTab:SetScript('OnClick', ClickNTab)


	--token list tab
	l.tTab = CreateFrame('Button', 'DSKListFrameTab2', l, "CharacterFrameTabButtonTemplate")
	l.tTab:SetPoint("LEFT", DSKListFrameTab1, "RIGHT", -14, 0);
	l.tTab:SetID(2)
	l.tTab:SetText('Token List')
	l.tTab:SetScript('OnClick', ClickTTab)


	--i/e list tab
	l.tTab = CreateFrame('Button', 'DSKListFrameTab3', l, "CharacterFrameTabButtonTemplate")
	l.tTab:SetPoint("LEFT", DSKListFrameTab2, "RIGHT", -14, 0);
	l.tTab:SetID(3)
	l.tTab:SetText('I/E Lists')
	l.tTab:SetScript('OnClick', ClickITab)


	--add button
	l.add = CreateFrame('Button', 'ListAddButton', l, "OptionsButtonTemplate")
	l.add:SetText('Add')
	l.add:SetPoint('TOPLEFT', 35, -28)
	l.add:SetScript('OnClick', AddClick)

	--delete button
	l.del = CreateFrame('Button', nil, l, "OptionsButtonTemplate")
	l.del:SetText('Delete')
	l.del:SetPoint('LEFT', ListAddButton, 'RIGHT', 0, 0)
	l.del:SetScript('OnClick', DeleteClick)

	--murder button
	l.murder = CreateFrame('Button', 'ListMurderButton', l, "OptionsButtonTemplate")
	l.murder:SetText('Murder')
	l.murder:SetPoint('BOTTOMLEFT', 35, 38)
	l.murder:SetScript('OnClick', MurderClick)

	--close bid button
	l.closeBid = CreateFrame('Button', 'ListCloseBidButton', l, "OptionsButtonTemplate")
	l.closeBid:SetText('Close Bid')
	l.closeBid:SetPoint('BOTTOM', -45, 15)
	l.closeBid:SetScript('OnClick', CloseBidClick)

	--ReverseButton
	l.reverse = CreateFrame('Button', 'ReverseButton', l, "OptionsButtonTemplate")
	l.reverse:SetText('Uno reverse')
	l.reverse:SetPoint('BOTTOM', 45, 15)
	l.reverse:SetScript('OnClick', ReverseTheBid)
	l.reverse:Disable()

	--sync button
	l.sync = CreateFrame('Button', nil, l, "OptionsButtonTemplate")
	l.sync:SetText('Sync')
	l.sync:SetPoint('LEFT', ListMurderButton, 'RIGHT', 0, 0)
	l.sync:SetScript('OnClick', SyncClick)

	--export button
	l.export = CreateFrame('Button', 'ExportButton', l, "OptionsButtonTemplate")
	l.export:SetText('Export')
	l.export:SetPoint('BOTTOMLEFT', 35, 15)
	l.export:SetScript('OnClick', ExportClick)
	l.export:Hide();

	--import button
	l.import = CreateFrame('Button', nil, l, "OptionsButtonTemplate")
	l.import:SetText('Import')
	l.import:SetPoint('LEFT', ExportButton, 'RIGHT', 0, 0)
	l.import:SetScript('OnClick', ImportClick)
	l.import:Hide();

	--normal radio button
	l.normalRadio = CreateFrame("CheckButton", "NormalRadioButton", l, "UIRadioButtonTemplate")
	NormalRadioButtonText:SetText('Normal List')
	l.normalRadio:SetPoint('BOTTOMLEFT', 35, 40)
	l.normalRadio:SetScript('OnClick', NormalRadioClick)
	l.normalRadio:SetChecked(1)
	l.normalRadio:Hide()

	--token radio button
	l.tokenRadio = CreateFrame("CheckButton", "TokenRadioButton", l, "UIRadioButtonTemplate")
	TokenRadioButtonText:SetText('Token List')
	l.tokenRadio:SetPoint('LEFT', NormalRadioButton, 'RIGHT', 75, 0)
	l.tokenRadio:SetScript('OnClick', TokenRadioClick)
	l.tokenRadio:Hide()

	--editbox
	l.editScroll = CreateFrame("ScrollFrame", "IEEditScroll", l, "UIPanelScrollFrameTemplate")
	l.editScroll:SetPoint('TOPLEFT', 20, -50)
	l.editScroll:SetWidth(190);
	l.editScroll:SetHeight(288);

	l.editArea = CreateFrame("EditBox", "IEEditScrollText", l.editScroll)
	l.editArea:SetAutoFocus(false)
	l.editArea:SetMultiLine(true)
	l.editArea:SetFontObject(ChatFontNormal) --GameFontHighlightSmall)
	l.editArea:SetMaxLetters(99999)
	l.editArea:EnableMouse(true)
	l.editArea:SetScript("OnEscapePressed", l.editArea.ClearFocus)
	-- XXX why the fuck doesn't SetPoint work on the editbox?
	l.editArea:SetWidth(190)
	l.editArea:SetText("To Export: Select a list below and hit export.\n\nTo Import: Fill this box with the following format.  Make sure names are capitalized correctly.  Make sure the correct list is selected below and hit import.\n\nFormat:\n1. Name Class\n2. Name Class\netc")

	l.editScroll:SetScrollChild(l.editArea)
	l.editScroll:Hide()

	--down button
	l.down = CreateFrame('Button', 'downButton', l, 'UIPanelScrollDownButtonTemplate')
	l.down:SetPoint('RIGHT', entry1, 'RIGHT')
	l.down:SetFrameStrata('FULLSCREEN')
	l.down:SetScript('OnClick', DownClick)
	l.down:Hide()

	--up button
	l.up = CreateFrame('Button', 'upButton', l, 'UIPanelScrollUpButtonTemplate')
	l.up:SetPoint('RIGHT', downButton, 'LEFT')
	l.up:SetFrameStrata('FULLSCREEN')
	l.up:SetScript('OnClick', UpClick)
	l.up:Hide()

	--scroll frame (actual list)
	l.list = CreateFrame('ScrollFrame', 'ScrollList', l, 'FauxScrollFrameTemplate')
	l.list:SetPoint('TOPLEFT', 10, -50)
	l.list:SetWidth(200);
	l.list:SetHeight(288);
	l.list:SetScript('OnVerticalScroll', function(self, offset)
			FauxScrollFrame_OnVerticalScroll(self, offset, 16, ScrollList_Update);
			end)


	--entry buttons
	l.entry1 = CreateFrame('Button', 'entry1', l)
	l.entry1:SetPoint('TOPLEFT', ScrollList, 'TOPLEFT', 8, 0)
	l.entry1.text = l.entry1:CreateFontString('entry1_Text', 'BORDER','GameFontHighlightLeft')
	l.entry1.text:SetText('entry1')
	l.entry1.text:SetPoint('LEFT')
	l.entry1:SetWidth(200)
	l.entry1:SetHeight(16)
	l.entry1:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry1:EnableMouse(true)
	l.entry1:SetScript('OnClick', EntryClick)
	l.entry1:SetID(1)

	l.entry2 = CreateFrame('Button', 'entry2', l)
	l.entry2:SetPoint('TOPLEFT', entry1, 'BOTTOMLEFT')
	l.entry2.text = l.entry2:CreateFontString('entry2_Text', 'BORDER','GameFontHighlightLeft')
	l.entry2.text:SetText('entry2')
	l.entry2.text:SetPoint('LEFT')
	l.entry2:SetWidth(200)
	l.entry2:SetHeight(16)
	l.entry2:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry2:EnableMouse(true)
	l.entry2:SetScript('OnClick', EntryClick)
	l.entry2:SetID(2)

	l.entry3 = CreateFrame('Button', 'entry3', l)
	l.entry3:SetPoint('TOPLEFT', entry2, 'BOTTOMLEFT')
	l.entry3.text = l.entry3:CreateFontString('entry3_Text', 'BORDER','GameFontHighlightLeft')
	l.entry3.text:SetText('entry3')
	l.entry3.text:SetPoint('LEFT')
	l.entry3:SetWidth(200)
	l.entry3:SetHeight(16)
	l.entry3:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry3:EnableMouse(true)
	l.entry3:SetScript('OnClick', EntryClick)
	l.entry3:SetID(3)

	l.entry4 = CreateFrame('Button', 'entry4', l)
	l.entry4:SetPoint('TOPLEFT', entry3, 'BOTTOMLEFT')
	l.entry4.text = l.entry4:CreateFontString('entry4_Text', 'BORDER','GameFontHighlightLeft')
	l.entry4.text:SetText('entry4')
	l.entry4.text:SetPoint('LEFT')
	l.entry4:SetWidth(200)
	l.entry4:SetHeight(16)
	l.entry4:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry4:EnableMouse(true)
	l.entry4:SetScript('OnClick', EntryClick)
	l.entry4:SetID(4)

	l.entry5 = CreateFrame('Button', 'entry5', l)
	l.entry5:SetPoint('TOPLEFT', entry4, 'BOTTOMLEFT')
	l.entry5.text = l.entry5:CreateFontString('entry5_Text', 'BORDER','GameFontHighlightLeft')
	l.entry5.text:SetText('entry5')
	l.entry5.text:SetPoint('LEFT')
	l.entry5:SetWidth(200)
	l.entry5:SetHeight(16)
	l.entry5:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry5:EnableMouse(true)
	l.entry5:SetScript('OnClick', EntryClick)
	l.entry5:SetID(5)

	l.entry6 = CreateFrame('Button', 'entry6', l)
	l.entry6:SetPoint('TOPLEFT', entry5, 'BOTTOMLEFT')
	l.entry6.text = l.entry6:CreateFontString('entry6_Text', 'BORDER','GameFontHighlightLeft')
	l.entry6.text:SetText('entry6')
	l.entry6.text:SetPoint('LEFT')
	l.entry6:SetWidth(200)
	l.entry6:SetHeight(16)
	l.entry6:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry6:EnableMouse(true)
	l.entry6:SetScript('OnClick', EntryClick)
	l.entry6:SetID(6)

	l.entry7 = CreateFrame('Button', 'entry7', l)
	l.entry7:SetPoint('TOPLEFT', entry6, 'BOTTOMLEFT')
	l.entry7.text = l.entry7:CreateFontString('entry7_Text', 'BORDER','GameFontHighlightLeft')
	l.entry7.text:SetText('entry7')
	l.entry7.text:SetPoint('LEFT')
	l.entry7:SetWidth(200)
	l.entry7:SetHeight(16)
	l.entry7:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry7:EnableMouse(true)
	l.entry7:SetScript('OnClick', EntryClick)
	l.entry7:SetID(7)

	l.entry8 = CreateFrame('Button', 'entry8', l)
	l.entry8:SetPoint('TOPLEFT', entry7, 'BOTTOMLEFT')
	l.entry8.text = l.entry8:CreateFontString('entry8_Text', 'BORDER','GameFontHighlightLeft')
	l.entry8.text:SetText('entry8')
	l.entry8.text:SetPoint('LEFT')
	l.entry8:SetWidth(200)
	l.entry8:SetHeight(16)
	l.entry8:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry8:EnableMouse(true)
	l.entry8:SetScript('OnClick', EntryClick)
	l.entry8:SetID(8)

	l.entry9 = CreateFrame('Button', 'entry9', l)
	l.entry9:SetPoint('TOPLEFT', entry8, 'BOTTOMLEFT')
	l.entry9.text = l.entry9:CreateFontString('entry9_Text', 'BORDER','GameFontHighlightLeft')
	l.entry9.text:SetText('entry9')
	l.entry9.text:SetPoint('LEFT')
	l.entry9:SetWidth(200)
	l.entry9:SetHeight(16)
	l.entry9:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry9:EnableMouse(true)
	l.entry9:SetScript('OnClick', EntryClick)
	l.entry9:SetID(9)

	l.entry10 = CreateFrame('Button', 'entry10', l)
	l.entry10:SetPoint('TOPLEFT', entry9, 'BOTTOMLEFT')
	l.entry10.text = l.entry10:CreateFontString('entry10_Text', 'BORDER','GameFontHighlightLeft')
	l.entry10.text:SetText('entry10')
	l.entry10.text:SetPoint('LEFT')
	l.entry10:SetWidth(200)
	l.entry10:SetHeight(16)
	l.entry10:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry10:EnableMouse(true)
	l.entry10:SetScript('OnClick', EntryClick)
	l.entry10:SetID(10)

	l.entry11 = CreateFrame('Button', 'entry11', l)
	l.entry11:SetPoint('TOPLEFT', entry10, 'BOTTOMLEFT')
	l.entry11.text = l.entry11:CreateFontString('entry11_Text', 'BORDER','GameFontHighlightLeft')
	l.entry11.text:SetText('entry11')
	l.entry11.text:SetPoint('LEFT')
	l.entry11:SetWidth(200)
	l.entry11:SetHeight(16)
	l.entry11:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry11:EnableMouse(true)
	l.entry11:SetScript('OnClick', EntryClick)
	l.entry11:SetID(11)

	l.entry12 = CreateFrame('Button', 'entry12', l)
	l.entry12:SetPoint('TOPLEFT', entry11, 'BOTTOMLEFT')
	l.entry12.text = l.entry12:CreateFontString('entry12_Text', 'BORDER','GameFontHighlightLeft')
	l.entry12.text:SetText('entry12')
	l.entry12.text:SetPoint('LEFT')
	l.entry12:SetWidth(200)
	l.entry12:SetHeight(16)
	l.entry12:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry12:EnableMouse(true)
	l.entry12:SetScript('OnClick', EntryClick)
	l.entry12:SetID(12)

	l.entry13 = CreateFrame('Button', 'entry13', l)
	l.entry13:SetPoint('TOPLEFT', entry12, 'BOTTOMLEFT')
	l.entry13.text = l.entry13:CreateFontString('entry13_Text', 'BORDER','GameFontHighlightLeft')
	l.entry13.text:SetText('entry13')
	l.entry13.text:SetPoint('LEFT')
	l.entry13:SetWidth(200)
	l.entry13:SetHeight(16)
	l.entry13:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry13:EnableMouse(true)
	l.entry13:SetScript('OnClick', EntryClick)
	l.entry13:SetID(13)

	l.entry14 = CreateFrame('Button', 'entry14', l)
	l.entry14:SetPoint('TOPLEFT', entry13, 'BOTTOMLEFT')
	l.entry14.text = l.entry14:CreateFontString('entry14_Text', 'BORDER','GameFontHighlightLeft')
	l.entry14.text:SetText('entry14')
	l.entry14.text:SetPoint('LEFT')
	l.entry14:SetWidth(200)
	l.entry14:SetHeight(16)
	l.entry14:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry14:EnableMouse(true)
	l.entry14:SetScript('OnClick', EntryClick)
	l.entry14:SetID(14)

	l.entry15 = CreateFrame('Button', 'entry15', l)
	l.entry15:SetPoint('TOPLEFT', entry14, 'BOTTOMLEFT')
	l.entry15.text = l.entry15:CreateFontString('entry15_Text', 'BORDER','GameFontHighlightLeft')
	l.entry15.text:SetText('entry15')
	l.entry15.text:SetPoint('LEFT')
	l.entry15:SetWidth(200)
	l.entry15:SetHeight(16)
	l.entry15:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry15:EnableMouse(true)
	l.entry15:SetScript('OnClick', EntryClick)
	l.entry15:SetID(15)

	l.entry16 = CreateFrame('Button', 'entry16', l)
	l.entry16:SetPoint('TOPLEFT', entry15, 'BOTTOMLEFT')
	l.entry16.text = l.entry16:CreateFontString('entry16_Text', 'BORDER','GameFontHighlightLeft')
	l.entry16.text:SetText('entry16')
	l.entry16.text:SetPoint('LEFT')
	l.entry16:SetWidth(200)
	l.entry16:SetHeight(16)
	l.entry16:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry16:EnableMouse(true)
	l.entry16:SetScript('OnClick', EntryClick)
	l.entry16:SetID(16)

	l.entry17 = CreateFrame('Button', 'entry17', l)
	l.entry17:SetPoint('TOPLEFT', entry16, 'BOTTOMLEFT')
	l.entry17.text = l.entry17:CreateFontString('entry17_Text', 'BORDER','GameFontHighlightLeft')
	l.entry17.text:SetText('entry17')
	l.entry17.text:SetPoint('LEFT')
	l.entry17:SetWidth(200)
	l.entry17:SetHeight(16)
	l.entry17:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry17:EnableMouse(true)
	l.entry17:SetScript('OnClick', EntryClick)
	l.entry17:SetID(17)

	l.entry18 = CreateFrame('Button', 'entry18', l)
	l.entry18:SetPoint('TOPLEFT', entry17, 'BOTTOMLEFT')
	l.entry18.text = l.entry18:CreateFontString('entry18_Text', 'BORDER','GameFontHighlightLeft')
	l.entry18.text:SetText('entry18')
	l.entry18.text:SetPoint('LEFT')
	l.entry18:SetWidth(200)
	l.entry18:SetHeight(16)
	l.entry18:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	l.entry18:EnableMouse(true)
	l.entry18:SetScript('OnClick', EntryClick)
	l.entry18:SetID(18)

	--confirm import frame
	local c = CreateFrame('Frame', 'DSKConfirmFrame', UIParent);
	c:Hide();

	c:SetWidth(350);
	c:SetHeight(80);
	c:SetPoint("CENTER");
	c:SetBackdrop(DrunkardSK.bg)
	c:EnableMouse(true)
	c:SetToplevel(true)
	c:SetMovable(true)
	c:SetClampedToScreen(true)
	c:SetFrameStrata('DIALOG')
	c:SetScript('OnMouseDown', c.StartMoving)
	c:SetScript('OnMouseUp', c.StopMovingOrSizing)

	--confirmframe title
	c.title = c:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	c.title:SetText('This will delete and replace the existing list.\nAre you sure?')
	c.title:SetPoint('TOP', 0, -15)

	--accept button
	c.accept = CreateFrame('Button', 'AcceptButton', c, "OptionsButtonTemplate")
	c.accept:SetText('Accept')
	c.accept:SetPoint('BOTTOMLEFT', 35, 15)
	c.accept:SetScript('OnClick', AcceptClick)

	--decline button
	c.decline = CreateFrame('Button', nil, c, "OptionsButtonTemplate")
	c.decline:SetText('Decline')
	c.decline:SetPoint('BOTTOMRIGHT', -35, 15)
	c.decline:SetScript('OnClick', DeclineClick)

	--default disable master functions
	DSKListFrame.add:Disable();
	DSKListFrame.del:Disable();
	DSKListFrame.murder:Disable();
	DSKListFrame.up:Disable();
	DSKListFrame.down:Disable();
	DSKListFrame.closeBid:Disable();
	DSKListFrame.import:Disable();
	DSKListFrame.reverse:Disable();
	DSKBidFrame.closeF:Hide();

	DSKListFrame.selectedEntry = 0;

	--setup tabs
	PanelTemplates_SetNumTabs(DSKListFrame, 3);
	PanelTemplates_TabResize(DSKListFrameTab1, 30)
	PanelTemplates_TabResize(DSKListFrameTab2, 30)
	PanelTemplates_TabResize(DSKListFrameTab3, 30)
	PanelTemplates_SetTab(DSKListFrame, 1);

	--hooks
	DrunkardSK:SecureHook("HandleModifiedItemClick", "DSK_HandleModifiedItemClick")


	--comm setup
	DrunkardSK:RegisterComm("DSKOpenBid", "OpenBidding")
	DrunkardSK:RegisterComm("DSKSendBid", "ReceiveBid")
	DrunkardSK:RegisterComm("DSKNewHigh", "HighBidder")
	DrunkardSK:RegisterComm("DSKCloseBid", "CloseBid");
	DrunkardSK:RegisterComm("DSKSendRetract", "RetractBid");
	DrunkardSK:RegisterComm("DSKSyncReq", "ReceiveSyncReq");
	DrunkardSK:RegisterComm("DSKBroadcastList", "ReceiveBroadcast");
	DrunkardSK:RegisterComm("DSKSendList", "ReceiveList");

	--register for events
	DrunkardSK:RegisterEvent("RAID_ROSTER_UPDATE")
end

function DrunkardSK:OnDisable()
    -- Called when the addon is disabled
end

function DrunkardSK:IsOfficer()
	local _,_,playerrank = GetGuildInfo("player");
	GuildControlSetRank(playerrank + 1);
	local _,_,_,officerchat_speak,_,_,_,_,_,_,_,_,_,_,_,_ = GuildControlGetRankFlags();
	if (officerchat_speak == 1) then
		ret = true;
	else
		ret = false;
	end

	return ret;
end

--is masterlooter and guild officer
function DrunkardSK:IsMaster()
	local _, master, _ = GetLootMethod();

	--if (master ~= nil) and (master == 0) and (DrunkardSK:IsOfficer()) then
	if (master ~= nil) and (master == 0) then
		ret = true;
	else
		ret = false;
	end

	return ret;
end

--handle RAID_ROSTER_UPDATE event
function DrunkardSK:RAID_ROSTER_UPDATE()
	if (DrunkardSK:IsMaster()) then
		DSKListFrame.add:Enable();
		DSKListFrame.del:Enable();
		DSKListFrame.murder:Enable();
		DSKListFrame.up:Enable();
		DSKListFrame.down:Enable();
		DSKListFrame.import:Enable();
		DSKBidFrame.closeF:Show();
		Master = true;
	else
		DSKListFrame.add:Disable();
		DSKListFrame.del:Disable();
		DSKListFrame.murder:Disable();
		DSKListFrame.up:Disable();
		DSKListFrame.down:Disable();
		DSKListFrame.closeBid:Disable();
		DSKListFrame.import:Disable();
		DSKListFrame.reverse:Disable();
		DSKBidFrame.closeF:Hide();
		Master = false;
	end

	ScrollList_Update();
end

--create list timestamp
function DrunkardSK:CreateTimeStamp(oldstamp)
	local _, hour, minute = GameTime_GetGameTime(false);
	local _, month, day, year = CalendarGetDate();
	if (hour < 10) then
		hour = "0"..hour;
	end
	if (minute < 10) then
		minute = "0"..minute;
	end
	if (day < 10) then
		day = "0"..day;
	end
	if (month < 10) then
		month = "0"..month;
	end

	local newstr = year..month..day..hour..minute;

	local oldstr = strsub(tostring(oldstamp), 1, -3);
	local oldcount = strsub(tostring(oldstamp), -2)

	if(newstr == oldstr) then
		newstamp = tonumber(oldstr..oldcount);
		newstamp = newstamp + 1;
	else
		newstamp = tonumber(newstr.."00");
	end

	return newstamp;
end

--on dsk slash command
function DrunkardSK:OpenList(input)
--DrunkardSK:Print(HandleModifiedItemClick);
  	ScrollList_Update();
	DSKListFrame:Show();
end

--set item being bid on
function DrunkardSK:SetOpenItem(item)
	local n, l, quality, iL, reqL, t, subT, maxS, equipS, texture = GetItemInfo(item)
	DSKBidFrame.link:AddMessage(item);
	SetItemButtonTexture(DSKBidFrame.item, texture);
	r, g, b, hex = GetItemQualityColor(quality);
	SetItemButtonNormalTextureVertexColor(DSKBidFrame.item, r, g, b);
end

--find persons spot in table
function DrunkardSK:FindInTable(person, list)
	local ret = 0;
	if (list == "nList") then
		for i=1, DrunkardSK.db.realm.nLength, 1 do
			if (DrunkardSK.db.realm.nList[i].name == person) then
				ret = i;
			end
		end
	else
		for i=1, DrunkardSK.db.realm.tLength, 1 do
			if (DrunkardSK.db.realm.tList[i].name == person) then
				ret = i;
			end
		end
	end
	return ret;
end

function DrunkardSK:CheckIfOnBothLists()

	local somoneNotOnTheList = false;
	local names = {}
	local isOnListN;
	local isOnListT;

	for i = 1, GetNumRaidMembers(), 1 do
		names[i] = GetRaidRosterInfo(i)
		isOnListN = DrunkardSK:FindInTable(names[i], "nList");
		isOnListT = DrunkardSK:FindInTable(names[i], "tList");

		if(isOnListN == 0) or (isOnListT == 0) then
			somoneNotOnTheList = true;
			if(Master) then
				if (isOnListN == 0) and (isOnListT == 0) then
					SendChatMessage(names[i].." is not on both lists! Master looter HANDLE IT", "RAID");
				elseif (isOnListN == 0) then
					SendChatMessage(names[i].." is not on the normal list. Master looter HANDLE IT", "RAID");
				elseif (isOnListT == 0) then
					SendChatMessage(names[i].." is not on the token list. Master looter HANDLE IT", "RAID");
				end
			end
		end
	end

	return somoneNotOnTheList;
end

function DrunkardSK:CheckIfAlt()

	local rank = DrunkardSK:FindInTable(UnitName("player"), "nList");

	if (DrunkardSK.db.realm.nList[rank].class == "ALT") then
		return true;
	end

	return false;
end


--open bid frame for everyone
function DrunkardSK:OpenBidding(prefix, message, distribution, sender)
	ItemLink = message;
	DrunkardSK:SetOpenItem(ItemLink);
	DSKBidFrame:Show();

	local somoneNotOnTheList = DrunkardSK:CheckIfOnBothLists();

	if(somoneNotOnTheList) then
		DSKBidFrame.bid:Disable();
		DSKBidFrame.offspec:Disable();
		DSKBidFrame.bidMU:Disable();
		DSKBidFrame.pass:Disable();
	else
		if(DrunkardSK:CheckIfAlt()) then
			DSKBidFrame.bid:Disable();
		end
	end

end

--close bid frame on bid close
function DrunkardSK:CloseBid(prefix, message, distribution, sender)
	DSKBidFrame:Hide();
	DSKBidFrame.offspec:Enable();
	DSKBidFrame.pass:Enable();
	DSKBidFrame.bidMU:Enable();
	DSKBidFrame.bid:Enable();
	DSKBidFrame.retract:Disable();
	DSKBidFrame.text:SetText('<No High Bidder>');
	DSKBidFrame.text:SetTextColor(1, 1, 1);

	for i=1, DrunkardSK.db.realm.nLength, 1 do
		DrunkardSK.db.realm.nList[i].bid = "";
	end

	for i=1, DrunkardSK.db.realm.tLength, 1 do
		DrunkardSK.db.realm.tList[i].bid = "";
	end

	ScrollList_Update();

end


--determine which list to use based on item
function DrunkardSK:WhichList()
	_, _, _, _, _, iType, iSubType, _, _, _ = GetItemInfo(ItemLink);
	if (iType == "Miscellaneous") and (iSubType == "Junk") then
		return "tList";
	else
		return "nList";
	end
end

--find high roller
function DrunkardSK:FindHighRoller()
	local roll = 0;
	local name = "";
	local found = false;
	for i=1, OffspecCount, 1 do
		if (OffspecList[i].roll > roll) and (OffspecList[i].retracted == false) then
			roll = OffspecList[i].roll;
			name = OffspecList[i].name;
			found = true;
		end
	end
	if (found) then
		return name, roll;
	else
		return "", 0;
	end
end

--find high roller
function DrunkardSK:FindHighRollerMU()
	local roll = 0;
	local name = "";
	local found = false;
	for i=1, MUCount, 1 do
		if (MUList[i].roll > roll) and (MUList[i].retracted == false) then
			roll = MUList[i].roll;
			name = MUList[i].name;
			found = true;
		end
	end
	if (found) then
		return name, roll;
	else
		return "", 0;
	end
end

--find roller by name and remove
function DrunkardSK:RemoveRoller(name)
	for i=1, OffspecCount, 1 do
		if (OffspecList[i].name == name) then
			OffspecList[i].retracted = true;
		end
	end
	return name, roll;
end

function DrunkardSK:RemoveRollerMU(name)
	for i=1, MUCount, 1 do
		if (MUList[i].name == name) then
			MUList[i].retracted = true;
		end
	end
	return name, roll;
end

--find bidder by name and remove
function DrunkardSK:RemoveBidder(name)
	local list = DrunkardSK:WhichList();
	local rank = DrunkardSK:FindInTable(name, list);
	local bidrank = 0;
	for index,value in ipairs(BidList) do
		if (value == rank) then
			bidrank = index;
		end
	end
	table.remove(BidList, bidrank);
	table.sort(BidList);
end

--add a roller
function DrunkardSK:AddRoller(name)
	local found = false;
	local roll;
	for i=1, OffspecCount, 1 do
		if (OffspecList[i].name == name) and (OffspecList[i].retracted) then
			OffspecList[i].retracted = false;
			roll = OffspecList[i].roll;
			found = true;
		end
	end
	--add to OffspecList
	if(found == false) then
		roll = math.random(1001, 2000);
		OffspecCount = OffspecCount+1;
		OffspecList[OffspecCount] = {name = name, roll = roll, retracted = false}
	end
	return roll;
end

function DrunkardSK:AddRollerMU(name)
	local found = false;
	local roll;
	for i=1, MUCount, 1 do
		if (MUList[i].name == name) and (MUList[i].retracted) then
			MUList[i].retracted = false;
			roll = MUList[i].roll;
			found = true;
		end
	end

	if(found == false) then
		roll = math.random(1, 1000);
		MUCount = MUCount+1;
		MUList[MUCount] = {name = name, roll = roll, retracted = false}
	end
	return roll;
end

--update bid in list
function DrunkardSK:AddBidToList(bid, list, rank)
	if(list == "nList") then
		DrunkardSK.db.realm.nList[rank].bid = bid;
	elseif(list == "tList") then
		DrunkardSK.db.realm.tList[rank].bid = bid;
	end
	ScrollList_Update();
end

--update winner
function DrunkardSK:UpdateWinner()
	if (HighName ~= "") then
		local list = DrunkardSK:WhichList();
		local rank = DrunkardSK:FindInTable(HighName, list);
		local engClass;

		if (list == "nList") then
			engClass = DrunkardSK.db.realm.nList[rank].class;
		else
			engClass = DrunkardSK.db.realm.tList[rank].class;
		end

		DrunkardSK:SendCommMessage("DSKNewHigh", DrunkardSK:Serialize("Main spec: "..HighRank..". "..HighName, engClass), "RAID");

	elseif (HighRoller ~= "") then
		local list = DrunkardSK:WhichList();
		local rank = DrunkardSK:FindInTable(HighRoller, list);
		local engClass;

		if (list == "nList") then
			engClass = DrunkardSK.db.realm.nList[rank].class;
		else
			engClass = DrunkardSK.db.realm.tList[rank].class;
		end


		if(HighRoll > 1000) then
			DrunkardSK:SendCommMessage("DSKNewHigh", DrunkardSK:Serialize("Offspec: "..HighRoller..": "..HighRoll, engClass), "RAID");
		else
			DrunkardSK:SendCommMessage("DSKNewHigh", DrunkardSK:Serialize("Minor upgrade: "..HighRoller..": "..HighRoll, engClass), "RAID");
		end

	else
		DrunkardSK:SendCommMessage("DSKNewHigh", DrunkardSK:Serialize("<No High Bidder>", "PRIEST"), "RAID");
	end
end

--receive bid
function DrunkardSK:ReceiveBid(prefix, message, distribution, sender)
	if (BidNotOpen == false) then
		local success, bidType, bidder = DrunkardSK:Deserialize(message);
		local list = DrunkardSK:WhichList();
		local rank = DrunkardSK:FindInTable(bidder, list);

		--make sure a bid is open and person is in the list
		if(rank ~= 0) then
			if (Master) then
				BidsReceived = BidsReceived + 1;

				if (bidType == "bid") then
					SendChatMessage(bidder.." bids MS ", "RAID");
					table.insert(BidList, rank);
					table.sort(BidList);
					if (rank < HighRank) then
						HighRank = rank;
						HighName = bidder;
					end
					DrunkardSK:AddBidToList("MS", list, rank);


				elseif (bidType == "MU") then
					local roll = DrunkardSK:AddRollerMU(bidder);
					SendChatMessage(bidder.." rolls for minor upgrade "..roll.." (1-1000)" , "RAID");

					if(OffSpecBids > 0) then
						HighRoller, HighRoll = DrunkardSK:FindHighRoller();
					else
						HighRoller, HighRoll = DrunkardSK:FindHighRollerMU();
					end
					DrunkardSK:AddBidToList("MU ("..roll..")", list, rank);

				elseif (bidType == "offspec") then
					OffSpecBids = OffSpecBids + 1;
					local roll = DrunkardSK:AddRoller(bidder);
					SendChatMessage(bidder.." rolls for offspec "..roll.." (1001-2000)" , "RAID");

					if(OffSpecBids > 0) then
						HighRoller, HighRoll = DrunkardSK:FindHighRoller();
					else
						HighRoller, HighRoll = DrunkardSK:FindHighRollerMU();
					end
					DrunkardSK:AddBidToList("OS ("..roll..")", list, rank);

				elseif (bidType == "pass") then
					DrunkardSK:AddBidToList("Pass", list, rank);
				end


				DrunkardSK:UpdateWinner();

				if (BidsReceived == GetNumRaidMembers()) then
					SendChatMessage("All bids received!" , "RAID");
				end

			end
		end
	end
end

--receive a request to sync
function DrunkardSK:ReceiveSyncReq(prefix, message, distribution, sender)
	if (message == "master") and (DrunkardSK:IsOfficer()) and (Master == false) then
		DrunkardSK:SendCommMessage("DSKSendList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
	elseif (message == "not master") and (Master) then
		DrunkardSK:SendCommMessage("DSKBroadcastList", DrunkardSK:Serialize(DrunkardSK.db.realm.nStamp, DrunkardSK.db.realm.nLength, DrunkardSK.db.realm.nList, DrunkardSK.db.realm.tStamp, DrunkardSK.db.realm.tLength, DrunkardSK.db.realm.tList), "RAID");
	end
end

--receive list broadcast from master
function DrunkardSK:ReceiveBroadcast(prefix, message, distribution, sender)
	local success, nstamp, nlength, nlist, tstamp, tlength, tlist = DrunkardSK:Deserialize(message);
	if (Master == false) then
		if (tonumber(nstamp) > DrunkardSK.db.realm.nStamp) then
			DrunkardSK.db.realm.nStamp = tonumber(nstamp);
			DrunkardSK.db.realm.nLength = tonumber(nlength);
			DrunkardSK.db.realm.nList = nlist;
		end
		if (tonumber(tstamp) > DrunkardSK.db.realm.tStamp) then
			DrunkardSK.db.realm.tStamp = tonumber(tstamp);
			DrunkardSK.db.realm.tLength = tonumber(tlength);
			DrunkardSK.db.realm.tList = tlist;
		end
	end
	ScrollList_Update();
end

--master receive list updates from officers
function DrunkardSK:ReceiveList(prefix, message, distribution, sender)
	local success, nstamp, nlength, nlist, tstamp, tlength, tlist = DrunkardSK:Deserialize(message);
	if (Master) then
		if (tonumber(nstamp) > DrunkardSK.db.realm.nStamp) then
			DrunkardSK.db.realm.nStamp = tonumber(nstamp);
			DrunkardSK.db.realm.nLength = tonumber(nlength);
			DrunkardSK.db.realm.nList = nlist;
		end
		if (tonumber(tstamp) > DrunkardSK.db.realm.tStamp) then
			DrunkardSK.db.realm.tStamp = tonumber(tstamp);
			DrunkardSK.db.realm.tLength = tonumber(tlength);
			DrunkardSK.db.realm.tList = tlist;
		end
	end
	ScrollList_Update();
end

--retract bid
function DrunkardSK:RetractBid(prefix, message, distribution, sender)
	if (BidNotOpen == false) then
		local success, bidType, bidder = DrunkardSK:Deserialize(message);
		local list1 = DrunkardSK:WhichList();
		local rank = DrunkardSK:FindInTable(bidder, list1);

		--make sure a bid is open and person is in the list
		if (rank ~= 0) then
			if (Master) then

				BidsReceived = BidsReceived - 1;

				if(bidType == "bid") then
					DrunkardSK:RemoveBidder(bidder);
					SendChatMessage(bidder.." has retracted their MS bid." , "RAID");

					if(BidList[1] ~= nil) then
						HighRank = BidList[1];
						local list = DrunkardSK:WhichList();
						if(list == "nList") then
							HighName = DrunkardSK.db.realm.nList[HighRank].name;
						else
							HighName = DrunkardSK.db.realm.tList[HighRank].name;
						end
					else
						HighRank = 5000;
						HighName = "";
					end

				elseif (bidType == "MU")  then
					DrunkardSK:RemoveRollerMU(bidder);
					SendChatMessage(bidder.." has retracted their MU bid." , "RAID");

					if(OffSpecBids > 0) then
						HighRoller, HighRoll = DrunkardSK:FindHighRoller();
					else
						HighRoller, HighRoll = DrunkardSK:FindHighRollerMU();
					end

				elseif (bidType == "offspec") then
					OffSpecBids = OffSpecBids - 1;
					DrunkardSK:RemoveRoller(bidder);
					SendChatMessage(bidder.." has retracted their offspec bid." , "RAID");

					if(OffSpecBids > 0) then
						HighRoller, HighRoll = DrunkardSK:FindHighRoller();
					else
						HighRoller, HighRoll = DrunkardSK:FindHighRollerMU();
					end

				end
				DrunkardSK:UpdateWinner();
			end

			local list = DrunkardSK:WhichList();
			local rank = DrunkardSK:FindInTable(bidder, list);

			if(list == "nList") then
				DrunkardSK.db.realm.nList[rank].bid = "";
			elseif(list =="tList") then
				DrunkardSK.db.realm.tList[rank].bid = "";
			end
			ScrollList_Update();
		end
	end
end


--update high bidder
function DrunkardSK:HighBidder(prefix, message, distribution, sender)
	local success, text, class = DrunkardSK:Deserialize(message);

	DSKBidFrame.text:SetText(text);

	if(class == "ALT") then
		DSKBidFrame.text:SetTextColor(255, 0, 255);
	else
		local color = RAID_CLASS_COLORS[class];
		DSKBidFrame.text:SetTextColor(color.r, color.g, color.b);
	end
end

--hook alt clicks to open bid
function DrunkardSK:DSK_HandleModifiedItemClick(item)
	if (Master) then
		if (BidNotOpen) then
			if (IsAltKeyDown() and
				not IsShiftKeyDown() and
					not IsControlKeyDown()) then
				ItemLink = item;
				DrunkardSK:SendCommMessage("DSKOpenBid", ItemLink, "RAID");
				BidNotOpen = false;
				DSKListFrame.closeBid:Enable();
			end
		end
	end
end


