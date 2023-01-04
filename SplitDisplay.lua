ModUtil.RegisterMod("SplitDisplay")
local saveData = SplitDisplay.Data

local config = {
    Enabled = true,
	RecordAspectPBs = true,
	ShowSegments = false,
}
SplitDisplay.config = config

SplitDisplay.Splits = {}

SplitDisplay.RunStartTime = 0

SplitDisplay.BossKillMapping = {
    A_Boss01 = "Megaera",
    A_Boss02 = "Alecto",
    A_Boss03 = "Tisiphone",
    B_Boss01 = "Lernie",
    B_Boss02 = "Lernie",
    C_Boss01 = "Heroes",
}
SplitDisplay.RoomExitMapping = {
	A_PreBoss01 = "Tartarus",
	B_PreBoss01 = "Asphodel",
	C_PreBoss01 = "Elysium",
}
SplitDisplay.FuryChecker = {
	Megaera = true,
	Alecto = true,
	Tisiphone = true,
}


SplitDisplay.SplitDisplayOrder = {
	"Tartarus",
	"Fury",
	"Asphodel",
	"Lernie",
	"Elysium",
	"Heroes",
	"Temple of Styx",
	"Hades"
}
SplitDisplay.CurrentRunFury = nil

-- -- testing mechanics
-- OnControlPressed{ "Assist",
-- 	function(triggerArgs)
-- 		SplitDisplay.CurrentRunFury = "Megaera"
-- 		SplitDisplay.Splits = {
-- 			Tartarus = {
-- 				IGT = 100,
-- 				RTA = 200,
-- 			},
-- 			Megaera = {
-- 				IGT = 150,
-- 				RTA = 300,
-- 			},
-- 			Asphodel = {
-- 				IGT = 350,
-- 				RTA = 700,
-- 			},
-- 			Lernie = {
-- 				IGT = 400,
-- 				RTA = 800
-- 			},
-- 			Elysium = {
-- 				IGT = 500,
-- 				RTA = 1000,
-- 			},
-- 			Heroes = {
-- 				IGT = 550,
-- 				RTA = 1100,
-- 			},
-- 			["Temple of Styx"] = {
-- 				IGT = 600,
-- 				RTA = 1200,
-- 			},
-- 			Hades = {
-- 				IGT = 650,
-- 				RTA = 1300
-- 			}
-- 		}

-- 		ShowRunClearScreen()
-- end}

-- Run Start 
ModUtil.WrapBaseFunction("WindowDropEntrance", function( baseFunc, ... )
    local val = baseFunc( ... )

    if SplitDisplay.config.Enabled then
        SplitDisplay.RunStartTime = GetTime({ })
        SplitDisplay.Splits = {}
		SplitDisplay.CurrentRunFury = nil
    end

    return val
end, SplitDisplay)

-- Split management

function SplitDisplay.Split(splitName)

	local splitRTA = GetTime({ }) -- - SplitDisplay.RunStartTime
	local splitIGT = CurrentRun.GameplayTime

	SplitDisplay.Splits[splitName] = {
		IGT = splitIGT,
		RTA = splitRTA,
	}
end

-- Boss Kill Splits
ModUtil.WrapBaseFunction("HarpyKillPresentation", function( baseFunc, ... )
    if SplitDisplay.config.Enabled then
        local split = SplitDisplay.BossKillMapping[CurrentRun.CurrentRoom.Name]
        if split then
			if SplitDisplay.FuryChecker[split] then
				SplitDisplay.CurrentRunFury =  split
			end
            SplitDisplay.Split(split)
        end
    end
    baseFunc( ... )
end, SplitDisplay)

ModUtil.WrapBaseFunction("HadesKillPresentation", function( baseFunc, ... )
    if SplitDisplay.config.Enabled then
        SplitDisplay.Split("Hades")
    end
    baseFunc( ... )
end, SplitDisplay)

-- Room Exit Splits for boss kill boss entry splits
ModUtil.WrapBaseFunction("LeaveRoomPresentation", function( baseFunc, currentRun, exitDoor)
	if SplitDisplay.config.Enabled then
		local currentRoom = currentRun.CurrentRoom.Name
		SplitDisplay.ExitingRoom = currentRoom
		local split = SplitDisplay.RoomExitMapping[currentRoom]

		if split then
			SplitDisplay.Split(split)
		end
	end
	baseFunc(currentRun, exitDoor)

end, SplitDisplay)

ModUtil.WrapBaseFunction("AsphodelLeaveRoomPresentation", function( baseFunc, currentRun, exitDoor)
	if SplitDisplay.config.Enabled then
		local currentRoom = currentRun.CurrentRoom.Name
		SplitDisplay.ExitingRoom = currentRoom
		local split = SplitDisplay.RoomExitMapping[currentRoom]

		if split then
			SplitDisplay.Split(split)
		end
	end
	baseFunc(currentRun, exitDoor)

end, SplitDisplay)

-- Styx Door Exit Split
ModUtil.WrapBaseFunction("ExitToHadesPresentation", function( baseFunc, ... ) 
    if SplitDisplay.config.Enabled then
       SplitDisplay.Split("Temple of Styx")
    end
    baseFunc( ... )
end, SplitDisplay)

-- Time display formatting
function SplitDisplay.FormatElapsedTime(start_time, current_epoch)
    -- Accept a "start" time and "current" time and output it in the format Xh Xm Xs
    -- Can change the "string.format" line to change the output
    local time_since_launch = current_epoch - start_time
    local minutes = 0
    local hours = 0

    local centiseconds = (time_since_launch % 1) * 100
    local seconds = time_since_launch % 60

    -- If it hasn't been over a minute, no reason to do this calculation
    if time_since_launch > 60 then
        minutes = math.floor((time_since_launch % 3600) / 60)
    end

    -- If it hasn't been over an hour, no reason to do this calculation
    if time_since_launch > 3600 then
        hours = math.floor(time_since_launch / 3600)
    end

    -- If it hasn't been over an hour, only display minutes:seconds.centiseconds
    if hours == 0 then
        return string.format("%02d:%02d.%02d", minutes, seconds, centiseconds)
    end

    return string.format("%02d:%02d:%02d.%02d", hours, minutes, seconds, centiseconds)
end

-- PB Tracking
function SplitDisplay.UpdateSplitPBs()
	if SplitDisplay.config.RecordAspectPBs then
		local aspect = nil
		for traitName, count in pairs(CurrentRun.TraitCache) do
			if PassesTraitFilter("GameStats_Aspects", traitName) then
				aspect = traitName
			end
		end
		if aspect then
			local splitRecords = {}
			if saveData.SplitRecords then
				splitRecords = DeepCopyTable(saveData.SplitRecords)
			end
			if not splitRecords[aspect] then
				splitRecords[aspect] = {}
			end
			local startingTimes = { IGT = 0.0, RTA = SplitDisplay.RunStartTime }
			for i, splitName in ipairs(SplitDisplay.SplitDisplayOrder) do
				local previousSplit = nil
				if splitName == "Tartarus" then
					previousSplit = startingTimes
				else
					local previousSplitName = SplitDisplay.SplitDisplayOrder[i - 1]
					if previousSplitName == "Fury" then
						previousSplitName = SplitDisplay.CurrentRunFury
					end
					previousSplit = SplitDisplay.Splits[previousSplitName]
				end

				if splitName == "Fury" then
					splitName = SplitDisplay.CurrentRunFury
				end

				local IGTSplitTime = SplitDisplay.Splits[splitName].IGT - previousSplit.IGT

				if splitRecords[aspect][splitName] and IGTSplitTime < splitRecords[aspect][splitName].IGT then
					splitRecords[aspect][splitName].IGT = IGTSplitTime
				end

				local RTASplitTime = SplitDisplay.Splits[splitName].RTA - previousSplit.RTA

				if splitRecords[aspect][splitName] and RTASplitTime < splitRecords[aspect][splitName].RTA then
					splitRecords[aspect][splitName].RTA = RTASplitTime
				end
			end
		end
		saveData.SplitRecords = splitRecords
	end
end

-- Biome Split Display
function SplitDisplay.ShowBiomeSplits( screen, components, offsetY )
    local lineSpacingLarge = 35
	local lineSpacingSmall = 30
    local mainFontSize = 17
	local titleColor = Color.White
	local dataColor = {0.702, 0.620, 0.345, 1.0}
	local newRecordColor = {1.000, 0.894, 0.231, 1.0}
    
    local messageOffsetX = -255

    local columnHeaders =
	{
		{ OffsetX = 0, Text = "Segment", Justification = "Left", },
		{ OffsetX = 315, Text = "Game Time", Justification = "Right", },
		{ OffsetX = 485, Text = "Real Time", Justification = "Right", },
	}

    for k, header in ipairs( columnHeaders ) do
		CreateTextBox({ Id = components.ShopBackground.Id,
				Text = header.Text,
				FontSize = mainFontSize + 1,
				OffsetX = messageOffsetX + header.OffsetX, OffsetY = offsetY,
				Color = Color.White,
				Font = "AlegreyaSansSCExtraBold",
				ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
				Justification = header.Justification })
	end

    offsetY = offsetY + lineSpacingLarge

    local startingTimes = { IGT = 0.0, RTA = SplitDisplay.RunStartTime }

    for i, splitName in ipairs(SplitDisplay.SplitDisplayOrder) do
        -- split names
		if splitName == "Fury" then
			splitName = SplitDisplay.CurrentRunFury
		end
        CreateTextBox({ Id = components.ShopBackground.Id,
                Text = splitName,
                FontSize = mainFontSize,
                OffsetX = messageOffsetX + columnHeaders[1].OffsetX, OffsetY = offsetY,
                Color = {0.569, 0.557, 0.533, 1.0},
                Font = "AlegreyaSansSCExtraBold",
                ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
                Justification = columnHeaders[1].Justification })

        local igtSplit = "00:00:00"
        local rtaSplit = "00:00:00"

		local offsetMultiplier = 0
		if SplitDisplay.config.ShowSegments then
			offsetMultiplier = 1
		end

        if splitName == "Tartarus" then
            if SplitDisplay.Splits[splitName] and SplitDisplay.Splits[splitName].IGT then
                igtSplit = GetTimerString(SplitDisplay.Splits[splitName].IGT - startingTimes.IGT, 2)
            end
            if SplitDisplay.Splits[splitName] and SplitDisplay.Splits[splitName].RTA then
                rtaSplit = SplitDisplay.FormatElapsedTime(startingTimes.RTA, SplitDisplay.Splits[splitName].RTA)
            end
        else
            local previousSplit = SplitDisplay.SplitDisplayOrder[i - 1]
			if previousSplit == "Fury" then
				previousSplit = SplitDisplay.CurrentRunFury
			end
			if SplitDisplay.Splits[splitName] and SplitDisplay.Splits[splitName].IGT and previousSplit and  SplitDisplay.Splits[previousSplit] and SplitDisplay.Splits[previousSplit].IGT then
                igtSplit = GetTimerString(SplitDisplay.Splits[splitName].IGT - offsetMultiplier*SplitDisplay.Splits[previousSplit].IGT, 2)
            end
            if SplitDisplay.Splits[splitName] and SplitDisplay.Splits[splitName].RTA and previousSplit and  SplitDisplay.Splits[previousSplit] and SplitDisplay.Splits[previousSplit].RTA then
                rtaSplit = SplitDisplay.FormatElapsedTime(
					offsetMultiplier*SplitDisplay.Splits[previousSplit].RTA + (1-offsetMultiplier)*startingTimes.RTA,
					SplitDisplay.Splits[splitName].RTA
				)
            end
        end


        -- split IGT
        CreateTextBox({ Id = components.ShopBackground.Id,
                Text = igtSplit,
                FontSize = mainFontSize,
                OffsetX = messageOffsetX + columnHeaders[2].OffsetX, OffsetY = offsetY,
                Color = dataColor,
                Font = "AlegreyaSansSCExtraBold",
                ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
                Justification = columnHeaders[2].Justification })

        -- split RTA
        CreateTextBox({ Id = components.ShopBackground.Id,
                Text = rtaSplit,
                FontSize = mainFontSize,
                OffsetX = messageOffsetX + columnHeaders[3].OffsetX, OffsetY = offsetY,
                Color = dataColor,
                Font = "AlegreyaSansSCExtraBold",
                ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
                Justification = columnHeaders[3].Justification })

        offsetY = offsetY + ( lineSpacingSmall * 1.1 )
        wait(0.03)
    end
     
    return offsetY - ( lineSpacingSmall * 0.6 )
end

-- function SplitDisplay.HideBiomeSplits( screen )

-- end

-- function SplitDisplay.ShowBossSplits( screen )
--     SplitDisplay.SplitsShown = "BossSplits"
-- end

-- function SplitDisplay.HideBossSplits( screen )

-- end

-- function SplitDisplay.ToggleSplits( screen )
--     if SplitDisplay.SplitsShown == "BiomeSplits" then
--         SplitDisplay.HideBiomeSplits(screen)
--         SplitDisplay.ShowBossSplits(screen)
--     elseif SplitDisplay.SplitsShown == "BossSplits" then
--         SplitDisplay.HideBossSplits(screen)
--         SplitDisplay.ShowBiomeSplits(screen)
--     end
-- end

-- Split Display on Victory Screen
ModUtil.WrapBaseFunction("ShowRunClearScreen", function(baseFunc, ...)
    if not SplitDisplay.config.Enabled then
        baseFunc( ... )
        return
    end

	PlaySound({ Name = "/Leftovers/Menu Sounds/AscensionConfirm" })

	RecordRunCleared()

	thread( PlayVoiceLines, HeroVoiceLines.RunClearedVoiceLines )

	ScreenAnchors.RunClear = { Components = {} }
	local screen = ScreenAnchors.RunClear
	screen.Name = "RunClear"

	if IsScreenOpen( screen.Name ) then
		return
	end
	OnScreenOpened({ Flag = screen.Name, PersistCombatUI = true })
	FreezePlayerUnit()
	EnableShopGamepadCursor()

	ToggleControl({ Names = { "AdvancedTooltip" }, Enabled = false })
	thread( ShowAdvancedTooltip, { DontDuckAudio = true, DisableTooltips = true, HideCloseButton = true, AutoPin = true, } )

	PlaySound({ Name = "/SFX/Menu Sounds/DialoguePanelIn" })

	CreateGroup({ Name = "Combat_Menu_Overlay2" })
	InsertGroupInFront({ Name = "Combat_Menu_Overlay2", DestinationName = "Combat_Menu_Overlay" })

	local components = screen.Components

	components.Blackout = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_UI_Backing", X = ScreenCenterX, Y = ScreenCenterY })
	SetScale({ Id = components.Blackout.Id, Fraction = 10 })
	SetColor({ Id = components.Blackout.Id, Color = Color.Black })
	SetAlpha({ Id = components.Blackout.Id, Fraction = 0 })
	SetAlpha({ Id = components.Blackout.Id, Fraction = 0.6, Duration = 0.5 })

	components.ShopBackground = CreateScreenComponent({ Name = "EndPanelBox", Group = "Combat_Menu_Overlay2", X = ScreenCenterX + 637, Y = ScreenCenterY - 30 })
	for cosmeticName, status in pairs( GameState.Cosmetics ) do
		local cosmeticData = ConditionalItemData[cosmeticName]
		if cosmeticData ~= nil and cosmeticData.RunClearScreenBacking ~= nil then
			SetAnimation({ DestinationId = components.ShopBackground.Id, Name = cosmeticData.RunClearScreenBacking })
			break
		end
	end
	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Combat_Menu_TraitTray", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackground.Id, OffsetX = 3, OffsetY = 480 })
	components.CloseButton.OnPressedFunctionName = "CloseRunClearScreen"
	components.CloseButton.ControlHotkey = "Cancel"

	-- Title
	CreateTextBox(MergeTables({ Id = components.ShopBackground.Id,
		Text = "RunClearScreen_Title",
		FontSize = 32,
		Font = "SpectralSCLightTitling",
		OffsetX = -4, OffsetY = -370,
		Color = Color.White,
		ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3}, Justification = "Center",
		}, LocalizationData.RunClearScreen.TitleText))

	local messageOffsetX = -255
	local statOffsetX = 100

	local recordTime = GetFastestRunClearTime( CurrentRun )
	local prevRecordShrinePoints = GetHighestShrinePointRunClear()

	local offsetY = -325

	local lineSpacingLarge = 55
	local lineSpacingSmall = 35

	local mainFontSize = 19
	local titleColor = Color.White
	local dataColor = {0.702, 0.620, 0.345, 1.0}
	local newRecordColor = {1.000, 0.894, 0.231, 1.0}

	-- ClearTime (IGT)
	offsetY = offsetY + lineSpacingLarge
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = "Game Time",
		FontSize = mainFontSize,
		OffsetX = messageOffsetX, OffsetY = offsetY,
		Color = titleColor,
		Font = "AlegreyaSansSCRegular",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Left" })
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = GetTimerString( CurrentRun.GameplayTime, 2 ),
		FontSize = mainFontSize,
		OffsetX = statOffsetX, OffsetY = offsetY,
		Color = dataColor,
		Font = "AlegreyaSansSCExtraBold",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Right" })
	if CurrentRun.GameplayTime <= recordTime then
		wait(0.03)
		CreateTextBox(MergeTables({ Id = components.ShopBackground.Id,
			Text = "RunClearScreen_NewRecord",
			FontSize = mainFontSize,
			OffsetX = statOffsetX + 20, OffsetY = offsetY,
			Color = newRecordColor,
			Font = "AlegreyaSansSCExtraBold",
			ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
			Justification = "Left" }, LocalizationData.RunClearScreen.NewRecordText))
	end

	wait(0.05)

	-- Clear Time (RTA)
	local rtaClearTime = "00:00.00"
	if SplitDisplay.RunStartTime and SplitDisplay.Splits.Hades and SplitDisplay.Splits.Hades.RTA then
		rtaClearTime = SplitDisplay.FormatElapsedTime(SplitDisplay.RunStartTime, SplitDisplay.Splits.Hades.RTA)
	end
	offsetY = offsetY + lineSpacingSmall
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = "Real Time",
		FontSize = mainFontSize,
		OffsetX = messageOffsetX, OffsetY = offsetY,
		Color = titleColor,
		Font = "AlegreyaSansSCRegular",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Left" })
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = rtaClearTime,
		FontSize = mainFontSize,
		OffsetX = statOffsetX, OffsetY = offsetY,
		Color = dataColor,
		Font = "AlegreyaSansSCExtraBold",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Right" })

	-- ShrinePoints
	offsetY = offsetY + lineSpacingLarge
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = "RunClearScreen_ShrinePoints",
		FontSize = mainFontSize,
		OffsetX = messageOffsetX, OffsetY = offsetY,
		Color = titleColor,
		Font = "AlegreyaSansSCRegular",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Left" })
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = CurrentRun.ShrinePointsCache,
		FontSize = mainFontSize,
		OffsetX = statOffsetX, OffsetY = offsetY,
		Color = dataColor,
		Font = "AlegreyaSansSCExtraBold",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Right" })
	if CurrentRun.ShrinePointsCache > prevRecordShrinePoints then
		wait(0.03)
		CreateTextBox(MergeTables({ Id = components.ShopBackground.Id,
			Text = "RunClearScreen_NewRecord",
			FontSize = mainFontSize,
			OffsetX = statOffsetX + 20, OffsetY = offsetY,
			Color = newRecordColor,
			Font = "AlegreyaSansSCExtraBold",
			ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
			Justification = "Left" }, LocalizationData.RunClearScreen.NewRecordText))
	end

	wait(0.05)

	-- Record ShrinePoints
	offsetY = offsetY + lineSpacingSmall
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = "RunClearScreen_ShrinePointsRecord",
		FontSize = mainFontSize,
		OffsetX = messageOffsetX, OffsetY = offsetY,
		Color = titleColor,
		Font = "AlegreyaSansSCRegular",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Left" })
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = math.max( CurrentRun.ShrinePointsCache, prevRecordShrinePoints ),
		FontSize = mainFontSize,
		OffsetX = statOffsetX, OffsetY = offsetY,
		Color = dataColor,
		Font = "AlegreyaSansSCExtraBold",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Right" })

	wait(0.03)

	-- Splits
	offsetY = offsetY + 90

    offsetY = SplitDisplay.ShowBiomeSplits(screen, components, offsetY)
	
    wait(0.05)

	-- Total Clears
	offsetY = offsetY + 67
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = "RunClearScreen_TotalClears",
		FontSize = mainFontSize,
		OffsetX = messageOffsetX, OffsetY = offsetY,
		Color = titleColor,
		Font = "AlegreyaSansSCRegular",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Left" })
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = GameState.TimesCleared,
		FontSize = mainFontSize,
		OffsetX = statOffsetX, OffsetY = offsetY,
		Color = dataColor,
		Font = "AlegreyaSansSCExtraBold",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Right" })

	-- Consecutive Clears
	offsetY = offsetY + lineSpacingSmall
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = "RunClearScreen_ClearStreak",
		FontSize = mainFontSize,
		OffsetX = messageOffsetX, OffsetY = offsetY,
		Color = titleColor,
		Font = "AlegreyaSansSCRegular",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Left" })
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = GameState.ConsecutiveClears,
		FontSize = mainFontSize,
		OffsetX = statOffsetX, OffsetY = offsetY,
		Color = dataColor,
		Font = "AlegreyaSansSCExtraBold",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Right" })
	if GameState.ConsecutiveClears >= GameState.ConsecutiveClearsRecord then
		wait(0.03)
		CreateTextBox(MergeTables({ Id = components.ShopBackground.Id,
			Text = "RunClearScreen_NewRecord",
			FontSize = mainFontSize,
			OffsetX = statOffsetX + 20, OffsetY = offsetY,
			Color = newRecordColor,
			Font = "AlegreyaSansSCExtraBold",
			ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
			Justification = "Left" }, LocalizationData.RunClearScreen.NewRecordText))
	end

	wait(0.05)

	-- Consecutive Clears Record
	offsetY = offsetY + lineSpacingSmall
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = "RunClearScreen_ClearStreakRecord",
		FontSize = mainFontSize,
		OffsetX = messageOffsetX, OffsetY = offsetY,
		Color = titleColor,
		Font = "AlegreyaSansSCRegular",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Left" })
	CreateTextBox({ Id = components.ShopBackground.Id,
		Text = GameState.ConsecutiveClearsRecord,
		FontSize = mainFontSize,
		OffsetX = statOffsetX, OffsetY = offsetY,
		Color = dataColor,
		Font = "AlegreyaSansSCExtraBold",
		ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
		Justification = "Right" })

	-- Clear Message
	local priorityEligibleMessages = {}
	local eligibleMessages = {}
	for name, message in pairs( GameData.RunClearMessageData ) do
		if IsGameStateEligible( CurrentRun, message.GameStateRequirements ) then
			if message.Priority then
				table.insert( priorityEligibleMessages, message )
			else
				table.insert( eligibleMessages, message )
			end
		end
	end
	local message = nil
	if not IsEmpty( priorityEligibleMessages ) then
		message = GetRandomValue( priorityEligibleMessages )
	else
		message = GetRandomValue( eligibleMessages )
	end
	if message ~= nil then
		CurrentRun.RunClearMessage = message
		RunClearMessagePresentation( screen, message )
	end
	SplitDisplay.UpdateSplitPBs()
	HandleScreenInput( screen )

end, SplitDisplay)