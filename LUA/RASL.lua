--[[



============< general notes >=======================================================================
1)	clean code so that routines are not checking the same value for nil more than once
	if the code can't get to line X without the variable already being tested for nil, don't retest for nil
2)	This is no longer a valid terrain within the terrains table as of the Fall2016 Patch:
		[GameInfo.Terrains["TERRAIN_OUTOFPLAY"].Index] = true

============< resource-placement notes >============================================================
1)	don't remove a resource from a plot just to place a resource there
2)	weight toward placing resources in the 2nd ring from the starting plot
	a)	see if all desired resources can be placed in the 2nd ring from the start point
		before doing anything else
3)	don't place a resource adjacent to the starting plot
4)	don't place a resource on a plot that is adjacent to two or more mountain plots
5)	don't place a resource on a plot that is adjacent to a natural wonder


===================================================================================



]]--

--==================================================================================================================================================
--	Variable and Lua-Table Definitions
--==================================================================================================================================================
local bDebugPrint = false
	-- this controls debug printing

local SpitAIData = true

local iPlotRadius = 3
	--this is the radius from the player's starting plot to look for good plots to place units on

--==================================================================================================================================================
--	Initialize Lua-Table Definitions for later use
--	done here, the rest of code can access them
--	the contents of these table are filled-in by what is in the game's stock rules and by what is specified within RASL_GameSet-Up.xml
--==================================================================================================================================================
local tStartingExtraYields = {}
local tStartingCivics = {}
local tStartingTechs = {}
local tStartingResources = {}
local tResourceMapRequirements = {}
local tNaturalWonders = {}
local tStartingUnits = {}

--==================================================================================================================================================
--	Grab and cache needed info from the game engine or from the database
--==================================================================================================================================================
local tGameSpeedSelected = GameInfo.GameSpeeds[GameConfiguration.GetGameSpeedType()]
local sGameSpeedType = tGameSpeedSelected.GameSpeedType;
local iGameSpeedModifier = tGameSpeedSelected.CostMultiplier / 100;
local tPlayerStartEra = GameInfo.Eras[GameConfiguration.GetStartEra()]
local sPlayerStartEra = tPlayerStartEra.EraType
local sPlayerCivName = PlayerConfigurations[0]:GetCivilizationTypeName()
local tUnitNameLookupsUnitType, tUnitTypeLookupsUnitName = {}, {}

--==================================================================================================================================================
--	Create lua table of Terrains that are no good for unit placements.
--to do:
--(2) all that should be needed really is for land and sea units.
--	Domain="DOMAIN_LAND"
--	Domain="DOMAIN_SEA"
--(3) true air units should always be placed in cities or in the airfield districts/aircraft carriers and nowhere else
--	currently the code is not supporting units of "DOMAIN_AIR"
--	Domain="DOMAIN_AIR"

--==================================================================================================================================================
local tNoGoodTerrainTypes = {
	["DOMAIN_LAND"] = { [GameInfo.Terrains["TERRAIN_GRASS_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_PLAINS_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_DESERT_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_TUNDRA_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_SNOW_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_COAST"].Index] = true,
		[GameInfo.Terrains["TERRAIN_OCEAN"].Index] = true },
	["DOMAIN_SEA"] = { [GameInfo.Terrains["TERRAIN_GRASS_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_PLAINS_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_DESERT_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_TUNDRA_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_SNOW_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_GRASS_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_PLAINS_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_DESERT_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_TUNDRA_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_SNOW_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_GRASS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_PLAINS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_DESERT"].Index] = true,
		[GameInfo.Terrains["TERRAIN_TUNDRA"].Index] = true,
		[GameInfo.Terrains["TERRAIN_SNOW"].Index] = true },
	["DOMAIN_AIR"] = { [GameInfo.Terrains["TERRAIN_GRASS_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_PLAINS_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_DESERT_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_TUNDRA_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_SNOW_MOUNTAIN"].Index] = true,
		[GameInfo.Terrains["TERRAIN_GRASS_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_PLAINS_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_DESERT_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_TUNDRA_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_SNOW_HILLS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_GRASS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_PLAINS"].Index] = true,
		[GameInfo.Terrains["TERRAIN_DESERT"].Index] = true,
		[GameInfo.Terrains["TERRAIN_TUNDRA"].Index] = true,
		[GameInfo.Terrains["TERRAIN_SNOW"].Index] = true ,
		[GameInfo.Terrains["TERRAIN_COAST"].Index] = true,
		[GameInfo.Terrains["TERRAIN_OCEAN"].Index] = true } }

--==================================================================================================================================================
-- ToolkitFunctions
--==================================================================================================================================================
-- ==================================================================================
--	Debug printing routine
--	this needs to be here above everything else to ensure all code that needs
--		it can find it
-- ==================================================================================

function PrintToLog(sMessage)
	if bDebugPrint then
		print(sMessage)
	end
end

--==========================================================================================================================================
function CivicHasPreReq(sCivic)
	for Row in GameInfo.CivicPrereqs() do
		if Row.Civic == sCivic then
			return true
		end
	end
	return false
end
--==========================================================================================================================================
function GetCivicPreReqs(sCivic)
	local tTable = {}
	for Row in GameInfo.CivicPrereqs() do
		if Row.Civic == sCivic then
			table.insert(tTable, Row.PrereqCivic)
		end
	end
	return tTable
end
--==========================================================================================================================================
function SortForValidSettings(tAllowed, tPassed)
	local bIsAnySettingValid, tSettings = false, {}
	for k,Setting in pairs(tPassed) do
		if (Setting ~= nil) and tAllowed[Setting] then
			bIsAnySettingValid = true
			tSettings[Setting]=tAllowed[Setting]
		end
	end
	if not bIsAnySettingValid then
		tSettings = tAllowed
	end
	return bIsAnySettingValid, tSettings
end
--==========================================================================================================================================
function ScanAndGetAdjacentPlotsForTerrrain(pPlot, tDoNotIncludeTerrains, bCannotHaveUnit, sCivilianOrCombat)
	local sForbiddenUnitFormation = ((sCivilianOrCombat == "Civilians") and "FORMATION_CLASS_CIVILIAN" or "FORMATION_CLASS_LAND_COMBAT")
	local tTableOfPlots, iTableLength = {}, 0
	if (pPlot == nil) or (tDoNotIncludeTerrains == nil) then
		PrintToLog("exiting from ScanAndGetAdjacentPlotsForTerrrain with nil data because (pPlot == nil) or (tDoNotIncludeTerrains == nil)")
		return tTableOfPlots, iTableLength
	end
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), direction);
		if (adjacentPlot) then
			if (adjacentPlot:IsWater() == false)  then
				PrintToLog("Current Adjacent plot exists at X" .. adjacentPlot:GetX() .. ", Y" .. adjacentPlot:GetY() .. " and is not water")
				if not tDoNotIncludeTerrains[adjacentPlot:GetTerrainType()] then
					PrintToLog("The plot is not one of the forbidden terrain types")
					local bAddPlot = true
					local unitList:table = Units.GetUnitsInPlotLayerID( adjacentPlot:GetX(), adjacentPlot:GetY(), MapLayers.ANY );
					if unitList ~= nil then
						PrintToLog("table unitList for the plot is not nil")
						if bCannotHaveUnit then
							PrintToLog("the boolean for bCannotHaveUnit is set to true")
							for i, pUnit in ipairs(unitList) do
								tUnitDetails = GameInfo.Units[tUnitNameLookupsUnitType[UnitManager.GetTypeName(pUnit)]]
								if tUnitDetails.FormationClass == sForbiddenUnitFormation then
									bAddPlot = false
								end
							end
							if not bAddPlot then
								PrintToLog("offending unit was found: the plot should not be added to the list")
							else
								PrintToLog("no offending unit was founf: the plot will be added to the list")
							end
						end
					else
						PrintToLog("table unitList for the plot is nil")
					end
					if bAddPlot then
						PrintToLog("the plot was added to the list")
						table.insert(tTableOfPlots, adjacentPlot)
						iTableLength = iTableLength + 1
					end
				end
			end
		end
	end
	return tTableOfPlots, iTableLength
end 
--==========================================================================================================================================
function GetEmptyPlotAndMakeUnit(pPlayerUnits, iUnitType, iPlotX, iPlotY, tBadTerrainsTable, sCivilianOrCombat)
	local pNewUnit
	local pSendplot = Map.GetPlot(iPlotX, iPlotY)
	local tGoodPlots, iTableLength = ScanAndGetAdjacentPlotsForTerrrain(pSendplot, tBadTerrainsTable, true, sCivilianOrCombat)
	if (tGoodPlots ~= nil) and (iTableLength > 0) then
		PrintToLog("GetEmptyPlotAndMakeUnit: Valid series of plots found for unit placement")
		local iSelection = math.random(iTableLength)
		local pPlot = tGoodPlots[iSelection]
		pNewUnit = pPlayerUnits:Create(iUnitType, pPlot:GetX(), pPlot:GetY())
	end
	return pNewUnit
end
--==========================================================================================================================================
--  pPlacedUnit = SelectEmptyPlotFromTableAndMakeUnit(pPlayerUnits, iUnitType, tAdjCivilianPlots, sCivilianOrCombat)
function SelectEmptyPlotFromTableAndMakeUnit(pPlayerUnits, iUnitType, tPlotsTable, sCivilianOrCombat)
	local sForbiddenUnitFormation = ((sCivilianOrCombat == "Civilians") and "FORMATION_CLASS_CIVILIAN" or "FORMATION_CLASS_LAND_COMBAT")
	local pNewUnit
	local iTableLength = table.count(tPlotsTable)
	local iSelection = math.random(iTableLength)
	local pPlot = tPlotsTable[iSelection]
	local bPlotCanBeUsed = true
	local unitList:table = Units.GetUnitsInPlotLayerID( pPlot:GetX(), pPlot:GetY(), MapLayers.ANY );
	if unitList ~= nil then
		PrintToLog("SelectEmptyPlotFromTableAndMakeUnit: table unitList for the plot is not nil")
		for i, pUnit in ipairs(unitList) do
			tUnitDetails = GameInfo.Units[tUnitNameLookupsUnitType[UnitManager.GetTypeName(pUnit)]]
			if tUnitDetails.FormationClass == sForbiddenUnitFormation then
				bPlotCanBeUsed = false
			end
		end
		if not bPlotCanBeUsed then
			PrintToLog("SelectEmptyPlotFromTableAndMakeUnit: offending unit was found: the plot should not be added to the list")
		else
			PrintToLog("SelectEmptyPlotFromTableAndMakeUnit: no offending unit was found: the plot will be added to the list")
		end
	else
		PrintToLog("SelectEmptyPlotFromTableAndMakeUnit: table unitList for the plot is nil")
	end

	if bPlotCanBeUsed then
		pNewUnit = pPlayerUnits:Create(iUnitType, pPlot:GetX(), pPlot:GetY())
	end
	return pNewUnit
end

--==================================================================================================================================================
-- create and fill lua tables tPlayerCivNames and tPlayerIDsDatas
--==================================================================================================================================================
local tPlayerCivNames = {}
local tPlayerIDsDatas = {}
	--============================================================================
	-- major civ iteration
	--============================================================================
	local iNumMajorCivs = PlayerManager.GetAliveMajorsCount();
	local tMajorsList = PlayerManager.GetAliveMajorIDs();
	for i = 1, iNumMajorCivs do
		local pPlayer = Players[tMajorsList[i]]
		if(pPlayer == nil) then
			--print("THIS PLAYER FAILED");
		else
			--do stuff here
			local pPlayerConfig = PlayerConfigurations[tMajorsList[i]]
			local sPlayerCivName = pPlayerConfig:GetCivilizationTypeName()
			local bIsHuman = pPlayer:IsHuman()
			tPlayerCivNames[sPlayerCivName] = tMajorsList[i]
			tPlayerIDsDatas[tMajorsList[i]] = {Name=sPlayerCivName, Human=bIsHuman, IsMajor=true}
		end
	end

	--============================================================================
	-- minor civ iteration
	--============================================================================
	local iNumMinorCivs = PlayerManager.GetAliveMinorsCount();
	local tMinorsList = PlayerManager.GetAliveMinorIDs();
	for i = 1, iNumMinorCivs do
		local pPlayer = Players[tMinorsList[i]]
		
		if(pPlayer == nil) then
			--print("THIS PLAYER FAILED");
		else
			--do stuff here
			local pPlayerConfig = PlayerConfigurations[tMinorsList[i]]
			local sPlayerCivName = pPlayerConfig:GetCivilizationTypeName()
			tPlayerCivNames[sPlayerCivName] = tMinorsList[i]
			tPlayerIDsDatas[tMinorsList[i]] = {Name=sPlayerCivName, Human=false, IsMajor=false}
		end
	end

--==================================================================================================================================================
-- create and fill lua table tStartEraDatas
--==================================================================================================================================================
local tStartEraDatas = {}
for Era in GameInfo.Eras() do
	tStartEraDatas[Era.EraType] = { Index=Era.Index, Name=Locale.Lookup(Era.Name), StartFreeTechs={}, StartFreeCivics={}, PrimaryCivic="NONE", PrimaryCivicCost=100000000000 }
	if Era.Index > 0 then
		for Technology in GameInfo.Technologies() do
			if GameInfo.Eras[Technology.EraType].Index < tStartEraDatas[Era.EraType].Index then
				tStartEraDatas[Era.EraType]["StartFreeTechs"][Technology.TechnologyType] = Technology.Index
			end
		end
	end
	for Civic in GameInfo.Civics() do
		if GameInfo.Eras[Civic.EraType].Index < tStartEraDatas[Era.EraType].Index then
			tStartEraDatas[Era.EraType]["StartFreeCivics"][Civic.CivicType] = Civic.Index
		end
		if Civic.EraType == Era.EraType then
			if (Era.Index == 0) then
				if not CivicHasPreReq(Civic.CivicType) then
					tStartEraDatas[Era.EraType].PrimaryCivicCost = Civic.Cost
					tStartEraDatas[Era.EraType].PrimaryCivic = Civic.CivicType
				end
			else
				if Civic.Cost < tStartEraDatas[Era.EraType].PrimaryCivicCost then
					tStartEraDatas[Era.EraType].PrimaryCivicCost = Civic.Cost
					tStartEraDatas[Era.EraType].PrimaryCivic = Civic.CivicType
				end
			end
		end
	end
end
--==================================================================================================================================================
-- Misc Debug Print Statements
--==================================================================================================================================================
if bDebugPrint then
	print("===============================================================================================")
	print("sGameSpeedType variable gives " .. sGameSpeedType)
	print("iGameSpeedModifier variable gives " .. iGameSpeedModifier)
	print("===============================================================================================")
	print("PlayerConfigurations[0]:GetCivilizationTypeName() gives " .. tostring(sPlayerCivName))
	print("===============================================================================================")
	print("=============================== Contents of table tStartEraDatas ==============================")
	print("===============================================================================================")
	for sEra,DataTable in pairs(tStartEraDatas) do
		print(sEra .. ": Index = " .. DataTable.Index .. " Name = " .. DataTable.Name)
		if table.count(DataTable.StartFreeTechs) > 0 then
			print("............................................................................")
			print(DataTable.Name .. " gives the following free techs when starting in the Era:")
			for sTech,iTech in pairs(DataTable.StartFreeTechs) do
				print("     " .. sTech .. " with table index # of " .. iTech)
			end
			print("............................................................................")
			print(DataTable.Name .. " gives the following free civics when starting in the Era:")
			for sCivic,iCivic in pairs(DataTable.StartFreeCivics) do
				print("     " .. sCivic .. " with table index # of " .. iCivic)
			end
			print("............................................................................")
		else
			print(DataTable.Name .. " gives no free techs when starting in the Era.")
			print(DataTable.Name .. " gives no free civics when starting in the Era.")
			print("............................................................................")
		end
	end
	print("===============================================================================================")
	print("============================== Contents of table tPlayerCivNames ==============================")
	print("===============================================================================================")
	for sCivilizationName,PlayerID in pairs(tPlayerCivNames) do
		print(sCivilizationName .. " is assigned as Player # " .. PlayerID)
	end
	print("===============================================================================================")
	print("============================== Contents of table tPlayerIDsDatas ==============================")
	print("===============================================================================================")
	for PlayerID,DataTable in pairs(tPlayerIDsDatas) do
		print("Player # " .. PlayerID .. " is assigned as " .. DataTable.Name .. " : Human is " .. tostring(DataTable.Human) .. " and IsMajor is " .. tostring(DataTable.IsMajor))
	end
	print("===============================================================================================")
end

--==================================================================================================================================================
-- data here is not in any way translated from that stated in RASL_GameSet-Up.xml because the number of units desired should not scale for any reason
--==================================================================================================================================================
--tStartingUnits[PlayerID][sCivilianOrCombat][UnitRow.UnitType] = UnitRow.NumberExtraUnits

for UnitRow in GameInfo.RASL_Units() do
	--PrintToLog("A Row in Table RASL_Units detected with UnitType of " .. UnitRow.UnitType .. ", NumberExtraUnits of " .. UnitRow.NumberExtraUnits .. ", AIMajPlayer of " .. tostring(UnitRow.AIMajPlayer) .. ", and EraType of " .. UnitRow.EraType)
	local tUnitData = GameInfo.Units[UnitRow.UnitType]
	if tUnitData ~= nil then
		local sHumanOrAI = ((UnitRow.AIMajPlayer == false) and "HumanUnits" or "AIUnits")
		local sCivilianOrCombat = ((tUnitData.FormationClass == "FORMATION_CLASS_CIVILIAN") and "Civilians" or "Combat")
		local sRequiredCiv = ((UnitRow.CivilizationType ~= nil) and UnitRow.CivilizationType or "NONE")
		local sStartEraRequired = ((UnitRow.EraType ~= nil) and UnitRow.EraType or "NONE")
		local bUnitIsLandUnit = (tUnitData.Domain == "DOMAIN_LAND")
		local bAddUnit = (sPlayerStartEra == sStartEraRequired)
		if bAddUnit then
			if (sRequiredCiv ~= "NONE") then
				if (sHumanOrAI == "HumanUnits") then
					bAddUnit = (sPlayerCivName == sRequiredCiv)
				else
					bAddUnit = ((tPlayerCivNames[sRequiredCiv] ~= nil) and (tPlayerIDsDatas[tPlayerCivNames[sRequiredCiv]].Human == false))
				end
			end
		end
		if bAddUnit then
			for PlayerID,PlayerData in pairs(tPlayerIDsDatas) do
				if (sHumanOrAI == "HumanUnits") then
					if (PlayerData.Human == true) then
						if not tStartingUnits[PlayerID] then
							tStartingUnits[PlayerID] = {Civilians={},Combat={}}
						end
						tStartingUnits[PlayerID][sCivilianOrCombat][UnitRow.UnitType] = {Qty = UnitRow.NumberExtraUnits, Domain = tUnitData.Domain}
					end
				else
					if (PlayerData.Human == false) and (PlayerData.IsMajor == true) then
						if (sRequiredCiv == "NONE") or (tPlayerCivNames[sRequiredCiv] == PlayerID) then
							if not tStartingUnits[PlayerID] then
								tStartingUnits[PlayerID] = {Civilians={},Combat={}}
							end
							tStartingUnits[PlayerID][sCivilianOrCombat][UnitRow.UnitType] = {Qty = UnitRow.NumberExtraUnits, Domain = tUnitData.Domain}
						end
					end
				end
			end
		end
	else
		PrintToLog("GameInfo.RASL_Units: UnitType is invalid")
	end
end
PrintToLog("===============================================================================================")
PrintToLog("=============================== Contents of table tStartingUnits ==============================")
PrintToLog("===============================================================================================")
if bDebugPrint then
	for PlayerID,UnitsDataTable in pairs(tStartingUnits) do
		local sCivilizationName = tPlayerIDsDatas[PlayerID].Name
		for sCivilianOrCombat,DataTable in pairs(UnitsDataTable) do
			for sUnitName,UnitData in pairs(DataTable) do
				print(sCivilizationName .. ": " .. sUnitName .. " Qty = " .. UnitData.Qty .. " and the unit's domain is " .. UnitData.Domain)
			end
		end
		print("..............................................................................")
	end
end

--==========================================================================================================================================
-- data here is translated from a % stated in RASL_GameSet-Up.xml into an integer as needed by the game's methods
--==========================================================================================================================================

for CivicRow in GameInfo.RASL_CivicsStatus() do
	local tCivicData = GameInfo.Civics[CivicRow.CivicType]
	if tCivicData ~= nil then
		--PrintToLog("A Row in Table RASL_CivicsStatus detected with CivicType of " .. CivicRow.CivicType .. " and a Value of " .. CivicRow.Value .. " and a Finish boolean of " .. tostring(CivicRow.Finish))
		local sStartEraRequired = ((CivicRow.EraType ~= nil) and CivicRow.EraType or "NONE")
		local sHumanOrAI = ((CivicRow.AIMajPlayer == false) and "Human" or "AI")
		local sRequiredCiv = ((CivicRow.CivilizationType ~= nil) and CivicRow.CivilizationType or "NONE")
		local bAddCivic = (sPlayerStartEra == sStartEraRequired)
		if bAddCivic then
			if tStartEraDatas[sStartEraRequired]["StartFreeCivics"][CivicRow.CivicType] then
				bAddCivic = false
			end
		end
		if bAddCivic then
			if not ((CivicRow.Value > 0) or (CivicRow.Finish == true)) then
				bAddCivic = false
			end
		end
		if bAddCivic then
			if (sRequiredCiv ~= "NONE") then
				if (sHumanOrAI == "Human") then
					bAddCivic = (sPlayerCivName == sRequiredCiv)
				else
					bAddCivic = ((tPlayerCivNames[sRequiredCiv] ~= nil) and (tPlayerIDsDatas[tPlayerCivNames[sRequiredCiv]].Human == false))
				end
			end
		end
		if bAddCivic then
			for PlayerID,PlayerData in pairs(tPlayerIDsDatas) do
				bAddCivic = (PlayerData.IsMajor == true)
				if bAddCivic and tStartingCivics[PlayerID] then
					bAddCivic = not tStartingCivics[PlayerID][CivicRow.CivicType]
				end
				if bAddCivic then
					local bFinishBoolean = CivicRow.Finish
					local iIntegerValue = CivicRow.Value
					if bFinishBoolean then
						iIntegerValue = 0
					end
					if iIntegerValue > 0 then
						if iIntegerValue >= 100 then
							bFinishBoolean = true
							iIntegerValue = 0
						else
							local iCivicCost = 0
							local pCulture = Players[PlayerID]:GetCulture()
							if pCulture ~= nil then
								iCivicCost = pCulture:GetCultureCost(tCivicData.Index)
							end
							iIntegerValue = math.floor((iIntegerValue/100) * iCivicCost) - 1
						end
					end
					if iIntegerValue <= 0 then
						bFinishBoolean = true
						iIntegerValue = 0
					end
					if (sHumanOrAI == "Human") then
						if (PlayerData.Human == true) then
							if not tStartingCivics[PlayerID] then
								tStartingCivics[PlayerID] = {[CivicRow.CivicType] = {Integer=iIntegerValue, Finish=bFinishBoolean}}
							else
								tStartingCivics[PlayerID][CivicRow.CivicType] = {Integer=iIntegerValue, Finish=bFinishBoolean}
							end
						end
					else
						if (PlayerData.Human == false) and (PlayerData.IsMajor == true) then
							if (sRequiredCiv == "NONE") or (tPlayerCivNames[sRequiredCiv] == PlayerID) then
								if not tStartingCivics[PlayerID] then
									tStartingCivics[PlayerID] = {[CivicRow.CivicType] = {Integer=iIntegerValue, Finish=bFinishBoolean}}
								else
									tStartingCivics[PlayerID][CivicRow.CivicType] = {Integer=iIntegerValue, Finish=bFinishBoolean}
								end
							end
						end
					end
					if bFinishBoolean then
						if (sPlayerStartEra == "ERA_ANCIENT") then
							local sPrimaryCivic = tStartEraDatas[sPlayerStartEra].PrimaryCivic
							if tStartingCivics[PlayerID] then
								if not tStartingCivics[PlayerID][sPrimaryCivic] then
									tStartingCivics[PlayerID][sPrimaryCivic] = {Integer=0, Finish=true}
								else
									if (tStartingCivics[PlayerID][sPrimaryCivic].Finish ~= true) then
										tStartingCivics[PlayerID][sPrimaryCivic] = {Integer=0, Finish=true}
									end
								end
							end
						end
					end
				end
			end
		end
	else
		PrintToLog("GameInfo.RASL_CivicsStatus: CivicType is invalid")
	end
end
--==================================================================================================================================================
-- data here is translated from the integer stated in RASL_GameSet-Up.xml into an integer as needed by the game's methods based on game speed
--==================================================================================================================================================
--	tStartEraDatas[Era.EraType] = { Index=Era.Index, Name=Locale.Lookup(Era.Name), StartFreeTechs={}, StartFreeCivics={}, PrimaryCivic="NONE", PrimaryCivicCost=100000000000 }
--				tStartEraDatas[Era.EraType]["StartFreeTechs"][Technology.TechnologyType] = Technology.Index
--				tStartEraDatas[Era.EraType]["StartFreeCivics"][Civic.CivicType] = Civic.Index
--	local bAddUnit = (sPlayerStartEra == sStartEraRequired)


--tPlayerCivNames["CIVILIZATION_X"] = PlayerID#
--tPlayerIDsDatas[PlayerID#] = {Name="CIVILIZATION_X", Human=boolean, IsMajor=boolean}
--  tStartingCivics[PlayerID][CivicRow.CivicType] = {Integer=iIntegerValue, Finish=bFinishBoolean}


for YieldRow in GameInfo.RASL_Yields() do
	--PrintToLog("A Row in Table RASL_Yields detected with YieldType of " .. YieldRow.YieldType .. " and a StartingExtraValue of " .. YieldRow.StartingExtraValue)
	local sStartEraRequired = ((YieldRow.EraType ~= nil) and YieldRow.EraType or "NONE")
	local sHumanOrAI = ((YieldRow.AIMajPlayer == false) and "Human" or "AI")
	local sRequiredCiv = ((YieldRow.CivilizationType ~= nil) and YieldRow.CivilizationType or "NONE")
	local bAddYield = (sPlayerStartEra == sStartEraRequired)
	if bAddYield then
		if (sRequiredCiv ~= "NONE") then
			if (sHumanOrAI == "Human") then
				bAddYield = (sPlayerCivName == sRequiredCiv)
			else
				bAddYield = ((tPlayerCivNames[sRequiredCiv] ~= nil) and (tPlayerIDsDatas[tPlayerCivNames[sRequiredCiv]].Human == false))
			end
		end
	end
	if bAddYield then
		local iValue = math.floor(YieldRow.StartingExtraValue * iGameSpeedModifier)
		for PlayerID,PlayerData in pairs(tPlayerIDsDatas) do
			bAddYield = (PlayerData.IsMajor == true)
			if bAddYield then
				if (sHumanOrAI == "Human") then
					bAddYield = (PlayerData.Human == true)
				else
					bAddYield = (PlayerData.Human == false)
				end
			end
			if bAddYield and tStartingExtraYields[PlayerID] then
				bAddYield = not tStartingExtraYields[PlayerID][YieldRow.YieldType]
			end
			if bAddYield then
				if YieldRow.YieldType == "YIELD_CULTURE" then
					local sPrimaryCivic = tStartEraDatas[sStartEraRequired].PrimaryCivic
					local iCivicCost = 0
					local pCulture = Players[PlayerID]:GetCulture()
					if pCulture ~= nil then
						iCivicCost = pCulture:GetCultureCost(GameInfo.Civics[sPrimaryCivic].Index)
					end
					local bFinish = (iValue >= iCivicCost)
					local iIntegerValue = (bFinish and 0 or iValue)
					if not tStartingCivics[PlayerID] then
						tStartingCivics[PlayerID] = {}
					end
					if not tStartingCivics[PlayerID][sPrimaryCivic] then
						tStartingCivics[PlayerID][sPrimaryCivic] = {Integer=iIntegerValue, Finish=bFinish}
					else
						if (tStartingCivics[PlayerID][sPrimaryCivic].Finish ~= true) then
							if bFinish then
								tStartingCivics[PlayerID][sPrimaryCivic] = {Integer=0, Finish=true}
							else
								if tStartingCivics[PlayerID][sPrimaryCivic].Integer < iIntegerValue then
									tStartingCivics[PlayerID][sPrimaryCivic].Integer = iIntegerValue
								end
							end
						end
					end
				else
					if not tStartingExtraYields[PlayerID] then
						tStartingExtraYields[PlayerID]= {[YieldRow.YieldType] = iValue}
					else
						tStartingExtraYields[PlayerID][YieldRow.YieldType] = iValue
					end
				end
			end
		end
	end
end
--  tStartingExtraYields[PlayerID][YieldRow.YieldType] = iValue
PrintToLog("===============================================================================================")
PrintToLog("============================ Contents of table tStartingExtraYields ===========================")
PrintToLog("===============================================================================================")
if bDebugPrint and (table.count(tStartingExtraYields) > 0) then
	for PlayerID,DataTable in pairs(tStartingExtraYields) do
		local sCivilizationName = tPlayerIDsDatas[PlayerID].Name
		for sYieldType,iValue in pairs(DataTable) do
			print(sCivilizationName .. ": " .. sYieldType .. " has a value of " .. iValue)
		end
		print("..............................................................................")
	end
end
--  tStartingCivics[PlayerID][CivicRow.CivicType] = {Integer=iIntegerValue, Finish=bFinishBoolean}
if bDebugPrint and (table.count(tStartingCivics) > 0) then
	print("===============================================================================================")
	print("=============================== Contents of table tStartingCivics =============================")
	print("===============================================================================================")
	print("Contents of table tStartingCivics is:")
	for PlayerID,CivicsDataTable in pairs(tStartingCivics) do
		local sCivilizationName = tPlayerIDsDatas[PlayerID].Name
		for sCivicType,DataTable in pairs(CivicsDataTable) do
			print(sCivilizationName .. ": " .. sCivicType .. " has values of Integer = " .. DataTable.Integer .. ", Finish = " .. tostring(DataTable.Finish))
		end
		print("..............................................................................")
	end
end

--==========================================================================================================================================
-- data here is translated from a % stated in RASL_GameSet-Up.xml into an integer as needed by the game's methods
--==========================================================================================================================================
-- local tStartingTechs = {}

for TechRow in GameInfo.RASL_TechnologiesStatus() do
	--PrintToLog("A Row in Table RASL_TechnologiesStatus detected with TechnologyType of " .. TechRow.TechnologyType .. " and a Value of " .. TechRow.Value .. " and a Finish boolean of " .. tostring(TechRow.Finish))
	local tTechData = GameInfo.Technologies[TechRow.TechnologyType]
	if tTechData ~= nil then
		local sStartEraRequired = ((TechRow.EraType ~= nil) and TechRow.EraType or "NONE")
		local sHumanOrAI = ((TechRow.AIMajPlayer == false) and "Human" or "AI")
		local sStartEraRequired = ((TechRow.EraType ~= nil) and TechRow.EraType or "NONE")
		local sHumanOrAI = ((TechRow.AIMajPlayer == false) and "Human" or "AI")
		local sRequiredCiv = ((TechRow.CivilizationType ~= nil) and TechRow.CivilizationType or "NONE")
		local bAddTech = (sPlayerStartEra == sStartEraRequired)
		if bAddTech then
			if tStartEraDatas[sStartEraRequired]["StartFreeCivics"][TechRow.TechnologyType] then
				bAddTech = false
			end
		end
		if bAddTech then
			if not ((TechRow.Value > 0) or (TechRow.Finish == true)) then
				bAddTech = false
			end
		end
		if bAddTech then
			if (sRequiredCiv ~= "NONE") then
				if (sHumanOrAI == "Human") then
					bAddTech = (sPlayerCivName == sRequiredCiv)
				else
					bAddTech = ((tPlayerCivNames[sRequiredCiv] ~= nil) and (tPlayerIDsDatas[tPlayerCivNames[sRequiredCiv]].Human == false))
				end
			end
		end
		if bAddTech then
			for PlayerID,PlayerData in pairs(tPlayerIDsDatas) do
				bAddTech = (PlayerData.IsMajor == true)
				if bAddTech and tStartingTechs[PlayerID] then
					bAddTech = not tStartingTechs[PlayerID][TechRow.TechnologyType]
				end
				if bAddTech then
					local bFinishBoolean = TechRow.Finish
					local iIntegerValue = TechRow.Value
					if bFinishBoolean then
						iIntegerValue = 0
					end
					if iIntegerValue > 0 then
						if iIntegerValue >= 100 then
							bFinishBoolean = true
							iIntegerValue = 0
						else
							local iTechCost = 0
							local pTechs = Players[PlayerID]:GetTechs()
							if pTechs ~= nil then
								iTechCost = pTechs:GetResearchCost(tTechData.Index)
							end
							iIntegerValue = math.floor((iIntegerValue/100) * iTechCost) - 1
						end
					end
					if iIntegerValue <= 0 then
						bFinishBoolean = true
						iIntegerValue = 0
					end
					if (sHumanOrAI == "Human") then
						if (PlayerData.Human == true) then
							if not tStartingTechs[PlayerID] then
								tStartingTechs[PlayerID] = {[TechRow.TechnologyType] = {Integer=iIntegerValue, Finish=bFinishBoolean}}
							else
								tStartingTechs[PlayerID][TechRow.TechnologyType] = {Integer=iIntegerValue, Finish=bFinishBoolean}
							end
						end
					else
						if (PlayerData.Human == false) and (PlayerData.IsMajor == true) then
							if (sRequiredCiv == "NONE") or (tPlayerCivNames[sRequiredCiv] == PlayerID) then
								if not tStartingTechs[PlayerID] then
									tStartingTechs[PlayerID] = {[TechRow.TechnologyType] = {Integer=iIntegerValue, Finish=bFinishBoolean}}
								else
									tStartingTechs[PlayerID][TechRow.TechnologyType] = {Integer=iIntegerValue, Finish=bFinishBoolean}
								end
							end
						end
					end
				end
			end
		end
	else
		PrintToLog("GameInfo.RASL_TechnologiesStatus: TechnologyType is invalid")
	end
end
--  tStartingTechs[PlayerID][TechRow.TechnologyType] = {Integer=iIntegerValue, Finish=bFinishBoolean}
if bDebugPrint and (table.count(tStartingTechs) > 0) then
	print("===============================================================================================")
	print("=============================== Contents of table tStartingTechs ==============================")
	print("===============================================================================================")
	print("Contents of table tStartingTechs is:")
	for PlayerID,TechsDataTable in pairs(tStartingTechs) do
		local sCivilizationName = tPlayerIDsDatas[PlayerID].Name
		for sTechType,DataTable in pairs(TechsDataTable) do
			print(sCivilizationName .. ": " .. sTechType .. " has values of Integer = " .. DataTable.Integer .. ", Finish = " .. tostring(DataTable.Finish))
		end
		print("..............................................................................")
	end
end

--==========================================================================================================================================
-- data here is from a resource stated in RASL_GameSet-Up.xml and should be for a qty of resource tiles rather than a civ5 resource-amount
--==========================================================================================================================================
--  tStartingResources[PlayerID][ResourceRow.ResourceType] = {NumberResources=ResourceRow.NumberResources, PlaceWithinX_Tiles=ResourceRow.PlaceWithinX_Tiles}

for ResourceRow in GameInfo.RASL_ExtraStartingResources() do
	--PrintToLog("A Row in Table RASL_ExtraStartingResources detected with ResourceType of " .. ResourceRow.ResourceType .. " and a NumberResources of " .. ResourceRow.NumberResources .. " and a AIMajPlayer boolean of " .. tostring(ResourceRow.AIMajPlayer))
	local tResourceData = GameInfo.Resources[ResourceRow.ResourceType]
	if tResourceData ~= nil then
		local sStartEraRequired = ((ResourceRow.EraType ~= nil) and ResourceRow.EraType or "NONE")
		local sHumanOrAI = ((ResourceRow.AIMajPlayer == false) and "Human" or "AI")
		local sStartEraRequired = ((ResourceRow.EraType ~= nil) and ResourceRow.EraType or "NONE")
		local sHumanOrAI = ((ResourceRow.AIMajPlayer == false) and "Human" or "AI")
		local sRequiredCiv = ((ResourceRow.CivilizationType ~= nil) and ResourceRow.CivilizationType or "NONE")
		local bAddResource = (sPlayerStartEra == sStartEraRequired)
		if bAddResource then
			if ((ResourceRow.NumberResources <= 0) or (ResourceRow.PlaceWithinX_Tiles == 0)) then
				bAddResource = false
			end
		end
		if bAddResource then
			if (sRequiredCiv ~= "NONE") then
				if (sHumanOrAI == "Human") then
					bAddResource = (sPlayerCivName == sRequiredCiv)
				else
					bAddResource = ((tPlayerCivNames[sRequiredCiv] ~= nil) and (tPlayerIDsDatas[tPlayerCivNames[sRequiredCiv]].Human == false))
				end
			end
		end
		if bAddResource then
			for PlayerID,PlayerData in pairs(tPlayerIDsDatas) do
				bAddResource = (PlayerData.IsMajor == true)
				if bAddResource and tStartingResources[PlayerID] then
					bAddResource = not tStartingResources[PlayerID][ResourceRow.ResourceType]
				end
				if bAddResource then
					--  tStartingResources[PlayerID][ResourceRow.ResourceType] = {NumberResources=ResourceRow.NumberResources, PlaceWithinX_Tiles=ResourceRow.PlaceWithinX_Tiles}
					if (sHumanOrAI == "Human") then
						bAddResource = (PlayerData.Human == true)
					else
						if (PlayerData.Human == false) and (PlayerData.IsMajor == true) then
							if (sRequiredCiv == "NONE") or (tPlayerCivNames[sRequiredCiv] == PlayerID) then
								bAddResource = true
							else
								bAddResource = false
							end
						else
							bAddResource = false
						end
					end
					if bAddResource then
						if not tStartingResources[PlayerID] then
							tStartingResources[PlayerID] = {[ResourceRow.ResourceType] = {NumberResources=ResourceRow.NumberResources, PlaceWithinX_Tiles=ResourceRow.PlaceWithinX_Tiles}}
						else
							tStartingResources[PlayerID][ResourceRow.ResourceType] = {NumberResources=ResourceRow.NumberResources, PlaceWithinX_Tiles=ResourceRow.PlaceWithinX_Tiles}
						end
						-- ======================================================================================================================
						--BUILD RSOURCE PLACEMENTS REQUIREMENTS TABLE HERE RATHER THAN LATER
						--  tResourceMapRequirements[ResourceRow.ResourceType]["Terrains"][iTerrainType] = true
						--  tResourceMapRequirements[ResourceRow.ResourceType]["Features"][iFeatureType] = true
						-- ======================================================================================================================
						if not tResourceMapRequirements[ResourceRow.ResourceType] then
							tResourceMapRequirements[ResourceRow.ResourceType] = {}
						end
						for row in GameInfo.Resource_ValidTerrains() do
							if row.ResourceType == ResourceRow.ResourceType then
								if GameInfo.Terrains[row.TerrainType] ~= nil then
									local iTerrainType = GameInfo.Terrains[row.TerrainType].Index
									if not tResourceMapRequirements[ResourceRow.ResourceType]["Terrains"] then
										tResourceMapRequirements[ResourceRow.ResourceType]["Terrains"] = {[iTerrainType] = true}
									else
										tResourceMapRequirements[ResourceRow.ResourceType]["Terrains"][iTerrainType] = true
									end
								end
							end
						end 
						for row in GameInfo.Resource_ValidFeatures() do
							if row.ResourceType == ResourceRow.ResourceType then
								if GameInfo.Features[row.FeatureType] ~= nil then
									local iFeatureType = GameInfo.Features[row.FeatureType].Index
									if not tResourceMapRequirements[ResourceRow.ResourceType]["Features"] then
										tResourceMapRequirements[ResourceRow.ResourceType]["Features"] = {[iFeatureType] = true}
									else
										tResourceMapRequirements[ResourceRow.ResourceType]["Features"][iFeatureType] = true
									end
								end
							end
						end 
					end
				end
			end
		end
	else
		PrintToLog("GameInfo.RASL_ExtraStartingResources: ResourceType is invalid")
	end
end
--  tStartingResources[PlayerID][ResourceRow.ResourceType] = {NumberResources=ResourceRow.NumberResources, PlaceWithinX_Tiles=ResourceRow.PlaceWithinX_Tiles}
if bDebugPrint and (table.count(tStartingResources) > 0) then
	print("===============================================================================================")
	print("=========================== Contents of table tStartingResources ==============================")
	print("===============================================================================================")
	print("Contents of table tStartingResources is:")
	for PlayerID,ResourcesDataTable in pairs(tStartingResources) do
		local sCivilizationName = tPlayerIDsDatas[PlayerID].Name
		for sResourceType,DataTable in pairs(ResourcesDataTable) do
			print(sCivilizationName .. ": " .. sResourceType .. " has values of NumberResources = " .. DataTable.NumberResources .. ", PlaceWithinX_Tiles = " .. DataTable.PlaceWithinX_Tiles)
		end
		print("..............................................................................")
	end
end

--==========================================================================================================================================

for UnitRow in GameInfo.Units() do
	tUnitNameLookupsUnitType[UnitRow.Name] = UnitRow.UnitType
	tUnitTypeLookupsUnitName[UnitRow.UnitType] = UnitRow.Name
end
if bDebugPrint then
	print("===============================================================================================")
	print("============================ Contents of table tUnitNameLookupsUnitType =======================")
	print("===============================================================================================")
	for k,v in pairs(tUnitNameLookupsUnitType) do print(k .. " = " .. v) end
	print("===============================================================================================")
	print("============================ Contents of table tUnitTypeLookupsUnitName =======================")
	print("===============================================================================================")
	for k,v in pairs(tUnitTypeLookupsUnitName) do print(k .. " = " .. v) end
	print("===============================================================================================")
end

--====================================================================================================================
--	Get the ID of the Technology
--sTech must be passed in the form of "TECH_HAMBURGERS"
--====================================================================================================================
function GetTechID(sTech)
	local tTechData = GameInfo.Technologies[sTech]
	if tTechData == nil then
		print("GetTechID: invalid sTech, returning -1")
		return -1
	end
	return tTechData.Index
end
--====================================================================================================================
--	Get the Cost of the Technology for the Player
--sTech must be passed in the form of "TECH_HAMBURGERS"
--the function returns a Research Cost in 'beakers' or nil depending on success
--====================================================================================================================
function GetPlayersTechCost(sTech, pPlayer, iPlayer)
	local pPlayerTechs = pPlayer:GetTechs()
	if pPlayerTechs ~= nil then
		local iTech = GetTechID(sTech)
		if iTech >= 0 then
			return pPlayerTechs:GetResearchCost(iTech)
		end
	else
		PrintToLog("GetPlayersTechCost: invalid player techs table for player # " .. iPlayer .. ", returning nil")
	end
	return nil
end
--====================================================================================================================
--	Finish the progress on the current Technology the Player is Researching
--the function returns true or nil depending on success
--====================================================================================================================
function FinishCurrentTechResearch(pPlayer, iPlayer)
	local pPlayerTechs = pPlayer:GetTechs()
	if pPlayerTechs ~= nil then
		local iTech = pPlayerTechs:GetResearchingTech()
		local iTechCost = pPlayerTechs:GetResearchCost(iTech)
		if (iTechCost ~= nil) and (iTechCost > 0) then
			pPlayerTechs:SetResearchProgress(iTech, iTechCost)
			return true
		end
	else
		PrintToLog("FinishCurrentTechResearch: invalid player techs table for player # " .. iPlayer .. ", returning nil")
	end
	return nil
end


--====================================================================================================================
--	Give the player the tech
--sTech must be passed in the form of "TECH_HAMBURGERS"
--the function returns true or nil depending on success
--====================================================================================================================
function FinishTech(sTech, pPlayer, iPlayer)
	local iTech = GetTechID(sTech)
	if iTech >= 0 then
		local pPlayerTechs = pPlayer:GetTechs()
		if pPlayerTechs ~= nil then
			local iTechCost = pPlayerTechs:GetResearchCost(iTech)
			if (iTechCost ~= nil) and (iTechCost > 0) then
				pPlayerTechs:SetResearchProgress(iTech, iTechCost)
				return true
			end
		else
			PrintToLog("FinishTech: invalid player techs table for player # " .. iPlayer .. ", returning nil")
		end
	end
	return nil
end

--====================================================================================================================
--	Set the player progress for the given technology
--sTech must be passed in the form of "TECH_HAMBURGERS"
--iValue must be passed as an integer whole amount
--the function returns true or nil depending on success
--====================================================================================================================
function SetTechResearchProgress(sTech, iValue, pPlayer, iPlayer)
	local iTech = GetTechID(sTech)
	if iTech >= 0 then
		local pPlayerTechs = pPlayer:GetTechs()
		if pPlayerTechs ~= nil then
			pPlayerTechs:SetResearchProgress(iTech, iValue)
			return true
		else
			PrintToLog("SetTechResearchProgress: invalid player techs table for player # " .. iPlayer .. ", returning nil")
		end
	end
	return nil
end
--====================================================================================================================
--	Change the progress on the current Technology the Player is 'Researching'
--iChange must be passed as an integer whole percentage amount: assumed to be a percentage
--the function returns true or nil depending on success
--====================================================================================================================
function ChangeCurrentTechProgress(iChange, pPlayer, iPlayer)
	local pPlayerTechs = pPlayer:GetTechs()
	if pPlayerTechs ~= nil then
		pPlayerTechs:ChangeCurrentResearchProgress(iChange)
		return true
	else
		PrintToLog("ChangeCurrentTechProgress: invalid player culture table for player # " .. iPlayer .. ", returning nil")
	end
	return nil
end
--====================================================================================================================
--	Set the Technology the Player is 'Researching'
--sTech must be passed in the form of "TECH_HAMBURGERS"
--the function returns true or nil depending on success
--====================================================================================================================
function SetCurrentlyResearchingTech(sTech, pPlayer, iPlayer)
	local iTech = GetTechID(sTech)
	if iTech >= 0 then
		local pPlayerTechs = pPlayer:GetTechs()
		if pPlayerTechs ~= nil then
			pPlayerTechs:SetResearchingTech(iTech)
			return true
		else
			PrintToLog("SetCurrentlyResearchingTech: invalid player techs table for player # " .. iPlayer .. ", returning nil")
		end
	end
	return nil
end
--====================================================================================================================
--	Get the Tech the player is currently researching
--sTech must be passed in the form of "TECH_HAMBURGERS"
--the function returns a tech ID# or nil depending on success
--====================================================================================================================
function GetCurrentlyResearchingTech(pPlayer, iPlayer)
	local pPlayerTechs = pPlayer:GetTechs()
	if pPlayerTechs ~= nil then
		return pPlayerTechs:GetResearchingTech()
	else
		PrintToLog("GetCurrentlyResearchingTech: invalid player techs table for player # " .. iPlayer .. ", returning nil")
	end
	return nil
end
--====================================================================================================================
--	Get the Progress the Player has toward the specified technology
--sTech must be passed in the form of "TECH_HAMBURGERS"
--the function returns a tech ID# or nil depending on success
--====================================================================================================================
function GetPlayersTechProgress(sTech, pPlayer, iPlayer)
	local iTech = GetTechID(sTech)
	if iTech >= 0 then
		local pPlayerTechs = pPlayer:GetTechs()
		if pPlayerTechs ~= nil then
			return pPlayerTechs:GetResearchProgress(iTech)
		else
			PrintToLog("GetPlayersTechProgress: invalid player techs table for player # " .. iPlayer .. ", returning nil")
		end
	end
	return nil
end
--====================================================================================================================
--	Give the player the civic
--sCivic must be passed in the form of "CIVIC_HAMBURGERS"
--the function returns true or nil depending on success
--====================================================================================================================
function FinishCivic(sCivic, pPlayer, iPlayer)
	local iCivic = DB.MakeHash(sCivic)
	if iCivic ~= nil then
		local pCulture = pPlayer:GetCulture()
		if pCulture ~= nil then
			local iCivicCost = pCulture:GetCultureCost(iCivic)
			pCulture:SetCulturalProgress(iCivic, iCivicCost)
			return true
		else
			PrintToLog("FinishCivic: invalid player civics table for player # " .. iPlayer .. ", returning nil")
		end
	else
		PrintToLog("FinishCivic: invalid civic hash")
	end
	return nil
end
--====================================================================================================================
--	Set the Civic the Player is 'Researching'
--sCivic must be passed in the form of "CIVIC_HAMBURGERS"
--the function returns true or nil depending on success
--====================================================================================================================
function SetResearchingCivic(sCivic, pPlayer, iPlayer)
	local pCulture = pPlayer:GetCulture()
	if pCulture ~= nil then
		local iCivic = DB.MakeHash(sCivic)
		if iCivic ~= nil then
			pCulture:SetCivic(iCivic)
			return true
		else
			PrintToLog("SetResearchingCivic: invalid civic hash, returning nil")
		end
	else
		PrintToLog("SetResearchingCivic: invalid player civics table for player # " .. iPlayer .. ", returning nil")
	end
	return nil
end
--====================================================================================================================
--	Set the player progress for the given civic
--sCivic must be passed in the form of "CIVIC_HAMBURGERS"
--iPercent must be passed as an integer whole percentage amount
--the function returns true or nil depending on success
--====================================================================================================================
function SetCivicProgress(sCivic, iIntChange, pPlayer, iPlayer)
	local pCulture = pPlayer:GetCulture()
	if pCulture ~= nil then
		local iCivic = DB.MakeHash(sCivic)
		if iCivic ~= nil then
			pCulture:SetCulturalProgress(iCivic, iIntChange)
			return true
		else
			PrintToLog("SetCivicProgress: invalid civic hash, returning nil")
		end
	else
		PrintToLog("SetCivicProgress: invalid player civics table for player # " .. iPlayer .. ", returning nil")
	end
	return nil
end
--====================================================================================================================
--	Change the progress on the current Civic the Player is 'Researching'
--iIntChange must be passed as an integer whole percentage amount
--the function returns true or nil depending on success
--====================================================================================================================
function ChangeCurrentCivicProgress(iIntChange, pPlayer, iPlayer)
	local pCulture = pPlayer:GetCulture()
	if pCulture ~= nil then
		pCulture:ChangeCurrentCulturalProgress(iIntChange)
		return true
	else
		PrintToLog("ChangeCurrentCivicProgress: invalid player culture table for player # " .. iPlayer .. ", returning nil")
	end
	return nil
end
--====================================================================================================================
--	Finish the progress on the current Civic the Player is 'Researching'
--the function returns true or nil depending on success
--====================================================================================================================

function FinishCurrentCivicProgress(pPlayer, iPlayer)
	local pCulture = pPlayer:GetCulture()
	if pCulture ~= nil then
		local iCurrentCivicID = pCulture:GetProgressingCivic();
		if (iCurrentCivicID ~= nil) and (iCurrentCivicID >= 0) then
			local iCivicCost = pCulture:GetCultureCost(iCurrentCivicID)
			pCulture:SetCulturalProgress(iCurrentCivicID, iCivicCost)
			return true
		else
			PrintToLog("FinishCurrentCivicProgress: cannot access the current civic research item, returning nil")
		end
	else
		PrintToLog("FinishCurrentCivicProgress: invalid player culture table for player # " .. iPlayer .. ", returning nil")
	end
	return nil
end
--====================================================================================================================
--	Give out assigned player techs
--	code placed here as a subroutine function to simplify moving around during tests
--====================================================================================================================
--  tStartingTechs[PlayerID][TechRow.TechnologyType] = {Integer=iIntegerValue, Finish=bFinishBoolean}
function GiveSpecifiedTechs(iPlayer, tTechsTable)
	local pPlayer = Players[iPlayer]
	for sTechType,DataTable in pairs(tTechsTable) do
		if DataTable.Finish == true then
			FinishTech(sTechType, pPlayer, iPlayer)
		elseif DataTable.Integer > 0 then
			SetTechResearchProgress(sTechType, DataTable.Integer, pPlayer, iPlayer)
		end
	end
end
--====================================================================================================================
--	Get All Plots within range 'X' of a given plot
--	Give the central plot as 'pPlot'
--	Give the range as 'iRadius'
--====================================================================================================================


local AdjacentPlotDirectionCalcs = { NW = (function(X, Y) if (Y % 2 ~= 0) then return (X + 1), (Y + 1) else return X, (Y + 1) end end),
	W = (function(X, Y) return (X + 1), Y end),
	SW = (function(X, Y) if (Y % 2 ~= 0) then return (X + 1), (Y - 1) else return X, (Y - 1) end end),
	SE = (function(X, Y) if (Y % 2 == 0) then return (X - 1), (Y - 1) else return X, (Y - 1) end end),
	E = (function(X, Y) return (X - 1), Y end),
	NE = (function(X, Y) if (Y % 2 == 0) then return (X - 1), (Y + 1) else return X, (Y + 1) end end) }

function GetPlotCoordsInCardinalDirectionAtRadiusR(X, Y, R, sDirection)
	if (R < 1) or (sDirection == nil) or (AdjacentPlotDirectionCalcs[sDirection] == nil) then
		return X, Y
	end
	local iX, iY = AdjacentPlotDirectionCalcs[sDirection](X, Y)
	if R > 1 then
		local iStartRadius = 1
		while iStartRadius < R do
			iX, iY = AdjacentPlotDirectionCalcs[sDirection](iX, iY)
			iStartRadius = iStartRadius + 1
		end
	end
	return iX, iY
end
function GetAllPlotsInRadiusR(pPlot, iRadius, sExcludeCenterPlot)
	local tTemporaryTable = {}
	if (pPlot ==  nil) or (iRadius == nil) or (iRadius < 1) then
		return tTemporaryTable
	end
	local bExcludeCenter = ((sExcludeCenterPlot ~= nil) and (sExcludeCenterPlot == "ExcludeCenterPlot"))
	local iCenterX, iCenterY = pPlot:GetX(), pPlot:GetY()
	local iStartX, iStartY = GetPlotCoordsInCardinalDirectionAtRadiusR(iCenterX, iCenterY, iRadius, "NE")
	local iEndX, iEndY = GetPlotCoordsInCardinalDirectionAtRadiusR(iCenterX, iCenterY, iRadius, "SW")
	local iRowEndX, iRowEndY = GetPlotCoordsInCardinalDirectionAtRadiusR(iCenterX, iCenterY, iRadius, "NW")
	local iRowStartX, iRowStartY = iStartX, iStartY

	for iPlotY = iStartY, iEndY, -1 do
		local pLoopPlot = nil
		for iPlotX = iRowStartX, iRowEndX do
			local pLoopPlot = Map.GetPlot(iPlotX, iPlotY)
			if (pLoopPlot ~= nil) then
				if (pLoopPlot ~= pPlot) then
					table.insert(tTemporaryTable,pLoopPlot)
				else
					if not bExcludeCenter then
						table.insert(tTemporaryTable,pLoopPlot)
					end
				end
			end
		end
		if ((iPlotY - 1) >= iCenterY) then
			iRowStartX = AdjacentPlotDirectionCalcs.SE(iRowStartX, iPlotY)
			iRowEndX = AdjacentPlotDirectionCalcs.SW(iRowEndX, iPlotY)
		else
			iRowStartX = AdjacentPlotDirectionCalcs.SW(iRowStartX, iPlotY)
			iRowEndX = AdjacentPlotDirectionCalcs.SE(iRowEndX, iPlotY)
		end
		PrintToLog("GetAllPlotsInRadiusR: After calc for a new Y-row, iRowStartX is now " .. tostring(iRowStartX) .. " and iRowEndX is now " .. tostring(iRowEndX))
	end
	return tTemporaryTable
end

--====================================================================================================================
--	Game Loading Actions
--====================================================================================================================

function Initialize(iPlayer)
	local pPlayer = Players[iPlayer]
	local tPlayerYields = tStartingExtraYields[iPlayer]

	--====================================================================
	--	Starting Extra Yields for the Player
	--====================================================================

	if tPlayerYields ~= nil then
		if tPlayerYields["YIELD_FAITH"] then
			local playerReligion = pPlayer:GetReligion();
			playerReligion:ChangeFaithBalance(tPlayerYields["YIELD_FAITH"])
		end
		if tPlayerYields["YIELD_GOLD"] then
			local pTreasury = pPlayer:GetTreasury();
			pTreasury:ChangeGoldBalance(tPlayerYields["YIELD_GOLD"])
		end
	end

	--====================================================================
	--	Starting Extra Civics for the Player
	--====================================================================

	if tStartingCivics[iPlayer] ~= nil then
		for sCivicType,DataTable in pairs(tStartingCivics[iPlayer]) do
			if DataTable.Finish == true then
				FinishCivic(sCivicType, pPlayer, iPlayer)
			elseif DataTable.Integer > 0 then
				SetCivicProgress(sCivicType, DataTable.Integer, pPlayer, iPlayer)
			end
		end
	end

	--====================================================================
	--	Starting Extra Techs for the Player
	--====================================================================

	if tStartingTechs[iPlayer] ~= nil then
		local pPlayerTechs = pPlayer:GetTechs()
		if pPlayer:GetTechs() == nil then
			PrintToLog("GameLoading: pPlayer:GetTechs() returns nil before player 0 has founded a capital city")
		else
			PrintToLog("GameLoading: pPlayer:GetTechs() returns a usable lua object before player 0 has founded a capital city")
			GiveSpecifiedTechs(iPlayer, tStartingTechs[iPlayer])
			local iAnimalHusbandry = GetTechID("TECH_ANIMAL_HUSBANDRY")
			if (GetCurrentlyResearchingTech(pPlayer, iPlayer) == nil) and not (pPlayer:GetTechs():HasTech(iAnimalHusbandry)) then
				SetCurrentlyResearchingTech("TECH_ANIMAL_HUSBANDRY", pPlayer, iPlayer)
			else
				PrintToLog("GetCurrentlyResearchingTech(pPlayer, iPlayer) returns " .. tostring(GetCurrentlyResearchingTech(pPlayer, iPlayer)))
				PrintToLog("pPlayer:GetTechs():HasTech(iAnimalHusbandry) returns " .. tostring(pPlayer:GetTechs():HasTech(iAnimalHusbandry)))
			end
		end
	end
	--====================================================================
	--	Starting Extra Resources for the Player
	--====================================================================

	if tStartingResources[iPlayer] ~= nil then


		--resource code stuff here

	end

	--====================================================================
	--	Starting Extra Units for the Player
	--====================================================================

	if tStartingUnits[iPlayer] ~= nil then
		local iStartingX, iStartingY = -1,-1
		local pPlayerUnits = pPlayer:GetUnits()
		for i, pUnit in pPlayerUnits:Members() do
        	       if "LOC_UNIT_SETTLER_NAME" == UnitManager.GetTypeName(pUnit) then
				PrintToLog("Settler found by the UnitManager.GetTypeName(pUnit) method")
				iStartingX, iStartingY = pUnit:GetX(), pUnit:GetY()
				break
			end
		end
		if (iStartingX ~= nil) and (iStartingY ~= nil) and (iStartingX > 0) and (iStartingY > 0) then
			PrintToLog("Game Loading Actions: iStartingX, iStartingY is X" .. iStartingX .. ", Y" .. iStartingY)
			local tPickPlots = { ["DOMAIN_LAND"] = {}, ["DOMAIN_SEA"] = {} }

			PrintToLog("======================================================================================================================================")
			PrintToLog("Game Loading Actions: Processing GetAllPlotsInRadiusR")
			PrintToLog("======================================================================================================================================")
			for k,pPickPlot in pairs(GetAllPlotsInRadiusR(Map.GetPlot(iStartingX, iStartingY), iPlotRadius, "ExcludeCenterPlot")) do
				PrintToLog("Game Loading Actions: Processing GetAllPlotsInRadiusR plot: the plot X,Y is X" .. pPickPlot:GetX() .. ", Y" .. pPickPlot:GetY())
				local bAddLandPlot = (Map.GetPlotDistance(iStartingX, iStartingY, pPickPlot:GetX(), pPickPlot:GetY()) <= iPlotRadius)
				local bAddSeaPlot = bAddLandPlot
				PrintToLog("Game Loading Actions: <= iPlotRadius has returned " .. tostring(bAddLandPlot))
				if bAddLandPlot then
					bAddLandPlot = (tNoGoodTerrainTypes["DOMAIN_LAND"][pPickPlot:GetTerrainType()] == nil)
					PrintToLog("Game Loading Actions: tNoGoodTerrainTypes['DOMAIN_LAND'][pPickPlot:GetTerrainType()] == nil has returned " .. tostring(bAddLandPlot))
				end
				if bAddSeaPlot then
					bAddSeaPlot = (tNoGoodTerrainTypes["DOMAIN_SEA"][pPickPlot:GetTerrainType()] == nil)
					PrintToLog("Game Loading Actions: tNoGoodTerrainTypes['DOMAIN_SEA'][pPickPlot:GetTerrainType()] == nil has returned " .. tostring(bAddSeaPlot))
				end
				PrintToLog("Game Loading Actions: pPickPlot:GetTerrainType() has returned " .. tostring(GameInfo.Terrains[pPickPlot:GetTerrainType()].TerrainType))
				if bAddLandPlot and (pPickPlot:IsWater() or pPickPlot:IsLake()) then
					PrintToLog("Game Loading Actions: (pPickPlot:IsWater() or pPickPlot:IsLake()) has returned " .. tostring(pPickPlot:IsWater() or pPickPlot:IsLake()))
					bAddLandPlot = false
				end
				if bAddSeaPlot then
					if pPickPlot:IsLake() then
						PrintToLog("Game Loading Actions: pPickPlot:IsLake() has returned true: the plot cannot be used for a sea unit.")
						bAddSeaPlot = false
					elseif not pPickPlot:IsWater() then
						PrintToLog("Game Loading Actions: pPickPlot:IsWater() has returned false: the plot cannot be used for a sea unit.")
						bAddSeaPlot = false
					end
				end
				if bAddLandPlot then
					PrintToLog("Game Loading Actions: the plot was added to the tPickPlots['DOMAIN_LAND'] table")
					table.insert(tPickPlots["DOMAIN_LAND"], pPickPlot)
				else
					PrintToLog("Game Loading Actions: the plot was NOT added to the tPickPlots['DOMAIN_LAND'] table")
				end
				if bAddSeaPlot then
					PrintToLog("Game Loading Actions: the plot was added to the tPickPlots['DOMAIN_SEA'] table")
					table.insert(tPickPlots["DOMAIN_SEA"], pPickPlot)
				else
					PrintToLog("Game Loading Actions: the plot was NOT added to the tPickPlots['DOMAIN_SEA'] table")
				end
				PrintToLog("======================================================================================================================================")
			end
			if (table.count(tPickPlots["DOMAIN_LAND"]) > 0) or (table.count(tPickPlots["DOMAIN_SEA"]) > 0) then
				PrintToLog("(table.count(tPickPlots['DOMAIN_LAND']) > 0) or (table.count(tPickPlots['DOMAIN_SEA']) > 0) from the GetAllPlotsInRadiusR(Map.GetPlot(iStartingX, iStartingY), " .. iPlotRadius .. ", 'ExcludeCenterPlot')")
				local tAdjCivilianPlots = {}
				local iAdjCivilianLandLength, iAdjCivilianSeaLength = 0,0
				tAdjCivilianPlots["DOMAIN_LAND"], iAdjCivilianLandLength = ScanAndGetAdjacentPlotsForTerrrain(Map.GetPlot(iStartingX, iStartingY), tNoGoodTerrainTypes["DOMAIN_LAND"], true, "Civilians")
				tAdjCivilianPlots["DOMAIN_SEA"], iAdjCivilianSeaLength = ScanAndGetAdjacentPlotsForTerrrain(Map.GetPlot(iStartingX, iStartingY), tNoGoodTerrainTypes["DOMAIN_SEA"], true, "Civilians")
				--  tStartingUnits[PlayerID][sCivilianOrCombat][UnitRow.UnitType] = {Qty = UnitRow.NumberExtraUnits, Domain = tUnitData.Domain}
				for sCivilianOrCombat,DataTable in pairs(tStartingUnits[iPlayer]) do
					for sUnitName,UnitData in pairs(DataTable) do
						PrintToLog("Processing a sUnitName,UnitQty pair for table tStartingUnits to place the desired units")
						local iUnitType = GameInfo.Units[sUnitName].Index
						local iUnitQty = UnitData.Qty
						if UnitData.Domain == "DOMAIN_AIR" then
							--don't spawn air units at this point
							iUnitQty = 0
						end
						if iUnitQty >= 1 then
							PrintToLog("the number of needed units is greater than 1: UnitData.Qty = " .. UnitData.Qty)
							local iNumPlacedUnits = 0
							local iPlacementAttempts = 0
							local iAdjCivilianLength = iAdjCivilianLandLength
							if UnitData.Domain == "DOMAIN_SEA" then
								iAdjCivilianLength = iAdjCivilianSeaLength
							end
							while (iNumPlacedUnits < iUnitQty) do
								local pPlacedUnit
								if (sCivilianOrCombat == "Civilians") and (iPlacementAttempts < iAdjCivilianLength) then
									pPlacedUnit = SelectEmptyPlotFromTableAndMakeUnit(pPlayerUnits, iUnitType, tAdjCivilianPlots[UnitData.Domain], sCivilianOrCombat)
									iPlacementAttempts = iPlacementAttempts + 1
								else
									pPlacedUnit = SelectEmptyPlotFromTableAndMakeUnit(pPlayerUnits, iUnitType, tPickPlots[UnitData.Domain], sCivilianOrCombat)
								end
								if pPlacedUnit ~= nil then
									iNumPlacedUnits = iNumPlacedUnits + 1
								end
							end
						end
					end
				end
			else
				PrintToLog("(table.count(tPickPlots['DOMAIN_LAND']) = 0) and (table.count(tPickPlots['DOMAIN_SEA']) = 0) from the GetAllPlotsInRadiusR(Map.GetPlot(iStartingX, iStartingY), " .. iPlotRadius .. ", 'ExcludeCenterPlot')")
			end
		end
	end
end


local tTechsWeAreInterestedIn = { "TECH_MINING", "TECH_ANIMAL_HUSBANDRY", "TECH_POTTERY", "TECH_IRRIGATION" }
local tCivicsWeAreInterestedIn = { "CIVIC_FOREIGN_TRADE", "CIVIC_MYSTICISM", "CIVIC_CRAFTSMANSHIP", "CIVIC_CODE_OF_LAWS" }
local tProcessedTechsAndCivics = { [0] = "true", [63] = "true" }
function Spit_AI_Data( iPlayer, bIsFirstTime )
	if not tProcessedTechsAndCivics[iPlayer] then
		local tMajorsList = PlayerManager.GetAliveMajorIDs();
		print("[Spit_AI_Data] iPlayer is " .. tostring(iPlayer))
		print("[Spit_AI_Data] bIsFirstTime is " .. tostring(bIsFirstTime))
		local pPlayer = Players[iPlayer]
		if not pPlayer:IsHuman() and (pPlayer:GetCities():GetCapitalCity() ~= nil) then
			local iNumProcessings = 0
			local pPlayerConfig = PlayerConfigurations[iPlayer]
			local sPlayerCivName = pPlayerConfig:GetCivilizationTypeName()
			if tMajorsList[iPlayer + 1] then
				print("[Spit_AI_Data] Player is " .. sPlayerCivName)
				local pPlayerTechs = pPlayer:GetTechs()
				if pPlayerTechs ~= nil then
					for k,sTech in pairs(tTechsWeAreInterestedIn) do
						local iTech = GetTechID(sTech)
						if iTech >= 0 then
							if pPlayerTechs:HasTech(iTech) then
								print("[Spit_AI_Data] " .. sPlayerCivName .. " has " .. sTech)
							else
								print("[Spit_AI_Data] " .. sPlayerCivName .. " does not have " .. sTech)
							end
						end
					end
					iNumProcessings = iNumProcessings + 1
				else
					print("[Spit_AI_Data] invalid player techs table for player # " .. iPlayer)
				end
				local pPlayerCivics = pPlayer:GetCulture()
				if pPlayerCivics ~= nil then
					for k,sCivic in pairs(tCivicsWeAreInterestedIn) do
						local iCivic = DB.MakeHash(sCivic)
						if pPlayerCivics:HasCivic(iCivic) then
							print("[Spit_AI_Data] " .. sPlayerCivName .. " has " .. sCivic)
						else
							print("[Spit_AI_Data] " .. sPlayerCivName .. " does not have " .. sCivic)
						end
					end
					iNumProcessings = iNumProcessings + 1
				else
					print("[Spit_AI_Data] invalid player civics table for player # " .. iPlayer)
				end
				local pTreasury = pPlayer:GetTreasury();
				if pTreasury ~= nil then
					local iCurrentGold = math.floor(pTreasury:GetGoldBalance())
					print("[Spit_AI_Data] player # " .. iPlayer .. " (" .. sPlayerCivName .. ") has a treasury of " .. iCurrentGold .. " gold")
					iNumProcessings = iNumProcessings + 1
				else
					print("[Spit_AI_Data] invalid player treasury table for player # " .. iPlayer .. " (" .. sPlayerCivName .. ")")
				end
			else
				print("[Spit_AI_Data] Player " .. sPlayerCivName .. " is not a major player")
				tProcessedTechsAndCivics[iPlayer] = "true"
			end
			if iNumProcessings == 3 then
				tProcessedTechsAndCivics[iPlayer] = "true"
			end
		else
			if not pPlayer:IsHuman() then
				print("[Spit_AI_Data] Player " .. iPlayer .. " has not yet founded a capital city")
				if not tMajorsList[iPlayer + 1] then
					tProcessedTechsAndCivics[iPlayer] = "true"
				end
			end
		end
	end
end
if SpitAIData then
	Events.PlayerTurnActivated.Add(Spit_AI_Data)
end

--==============================================================================================
--RASL Initialize Players and Successful load confirmation
--==============================================================================================

if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then
	print("Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn()")
	for PlayerID,PlayerData in pairs(tPlayerIDsDatas) do
		if (tStartingUnits[PlayerID] ~= nil) or (tStartingExtraYields[PlayerID] ~= nil) or (tStartingCivics[PlayerID] ~= nil) or (tStartingTechs[PlayerID] ~= nil) or (tStartingResources[PlayerID] ~= nil) then
			Initialize(PlayerID)
		end
	end
else
	print("Game.GetCurrentGameTurn() != GameConfiguration.GetStartTurn()")
end





--==============================================================================================
--deprecated bits of code
--==============================================================================================
--[[

			local iTotalNumPossiblePlots = 0
			local iValue = 0
			while iValue < iPlotRadius do
				iValue = iValue + 1
				iTotalNumPossiblePlots = iTotalNumPossiblePlots + iValue
			end
			iTotalNumPossiblePlots = 1 + (iTotalNumPossiblePlots * 6)
			PrintToLog("Game Loading Actions: iTotalNumPossiblePlots = " .. iTotalNumPossiblePlots)
			local iNumProcessedPlots = 0
				iNumProcessedPlots = iNumProcessedPlots + 1
				if iNumProcessedPlots >= iTotalNumPossiblePlots then
					break
				end

]]--