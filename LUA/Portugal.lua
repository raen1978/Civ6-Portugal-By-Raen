--===================================================================================================================================================
-- Portugal LuA Scripts
--==================================================================================================================================================
-- INCLUDES
--==========================================================================================================================
include("Civ6Common.lua")
include("AdjacencyBonusSupport.lua")
print("POrtugal by raen scripts running I think")
--==========================================================================================================================
-- Variables
--==========================================================================================================================

local MenirBuilding = GameInfo.Buildings["BUILDING_MENIR"].Index;
local CromeBuilding = GameInfo.Buildings["BUILDING_CROMELEQUE"].Index;
local AntaBuilding = GameInfo.Buildings["BUILDING_ANTA"].Index;
local MegaLithBuilding = GameInfo.Buildings["BUILDING_MEGALITH"].Index;



local iFeitoriaImprovementType = GameInfo.Improvements["IMPROVEMENT_FEITORIA"].Index
local iPadraoImprovementType = GameInfo.Improvements["IMPROVEMENT_PADRAO"].Index

local iPortoDistrict = GameInfo.Districts["DISTRICT_PORTO"].Index;
local iCommercHUBDistrict = GameInfo.Districts["DISTRICT_COMMERCIAL_HUB"].Index;
local iBAIRROALTODistrict = GameInfo.Districts["DISTRICT_BAIRRO_ALTO"].Index;


local iPortoMaritimoBuilding = GameInfo.Buildings["BUILDING_PORTOMARITIMO"].Index;
local iEstaleiroBuilding = GameInfo.Buildings["BUILDING_ESTALEIRO"].Index;
local iMosteiroJeronimosBuilding = GameInfo.Buildings["BUILDING_NATIONAL_MOSTEIRO_JERONIMOS"].Index;
local iEcolaSagresBuilding = GameInfo.Buildings["BUILDING_NATIONAL_ESCOLA_SAGRES"].Index;
local iCasaINdiaBuilding = GameInfo.Buildings["BUILDING_NATIONAL_CASA_INDIA"].Index;



local t1 = GameInfo.Terrains["TERRAIN_GRASS"].Index
local t2 = GameInfo.Terrains["TERRAIN_PLAINS"].Index
local t3 = GameInfo.Terrains["TERRAIN_DESERT"].Index
local t4 = GameInfo.Terrains["TERRAIN_TUNDRA"].Index
local t5 = GameInfo.Terrains["TERRAIN_SNOW"].Index

local th1 = GameInfo.Terrains["TERRAIN_DESERT_HILLS"].Index
local th2 = GameInfo.Terrains["TERRAIN_TUNDRA_HILLS"].Index
local th3 = GameInfo.Terrains["TERRAIN_PLAINS_HILLS"].Index
local th4 = GameInfo.Terrains["TERRAIN_GRASS_HILLS"].Index
local th5 = GameInfo.Terrains["TERRAIN_SNOW_HILLS"].Index


--==========================================================================================================================
-- UTILITY FUNCTIONS
--==========================================================================================================================
--HasCivilizationTrait
function HasCivilizationTrait(civilizationType, traitType)
  for row in GameInfo.CivilizationTraits() do
    if (row.CivilizationType == civilizationType and row.TraitType == traitType) then return true end
  end
  return false
end

--==========================================================================================================================
-- Actual Function
--==========================================================================================================================


function BuildImprovement(locX, locY, owner, iImprovementType)
	local pPlot = Map.GetPlot(locX, locY);
	local iImprovementType = pPlot:GetImprovementType()
	if (iImprovementType ~= -1) then
		ImprovementBuilder.SetImprovementType(pPlot, -1)
	end
	if ImprovementBuilder.CanHaveImprovement(pPlot, iImprovementType, -1) then
		ImprovementBuilder.SetImprovementType(pPlot, iImprovementType, owner)
	end
end

function BuildPadrao(locX, locY, owner, iImprovementType)

  print("Build Padrao --------------------------");

  local plot = Map.GetPlot(locX, locY);
  local plotIndex = plot:GetIndex();

  print("    BuildPadrao, plotIndex = " .. plotIndex);

  --local iFortImprovementType = GameInfo.Improvements["IMPROVEMENT_FORT"].Index;
  ImprovementBuilder.SetImprovementType(plot, iImprovementType, owner);

end


function BuildFeitoria(locX, locY, owner, iImprovementType)

  print("Build Feitoria --------------------------");

  local plot = Map.GetPlot(locX, locY);
  local plotIndex = plot:GetIndex();

  print("    BuildFeitoria, plotIndex = " .. plotIndex);

  --local iFortImprovementType = GameInfo.Improvements["IMPROVEMENT_FORT"].Index;
  ImprovementBuilder.SetImprovementType(plot, iImprovementType, owner);

end

function PlaceDistrict(pCity, iDistrict, iDistrictPlotIndex)
  --local iCityPlotIndex = Map.GetPlot(pCity:GetX(), pCity:GetY()):GetIndex()
  if not pCity:GetDistricts():HasDistrict(iDistrict) then
    pCity:GetBuildQueue():CreateIncompleteDistrict(iDistrict, iDistrictPlotIndex, 100);
  else
    if pCity:GetDistricts():IsPillaged(iDistrict) then
      pCity:GetDistricts():SetPillaged(iDistrict, false)
    end
  end
end



function PlaceBuildingInDistrict(pCity, iBuilding, iDistrictPlotIndex)
  --local iCityPlotIndex = Map.GetPlot(pCity:GetX(), pCity:GetY()):GetIndex()
  if not pCity:GetBuildings():HasBuilding(iBuilding) then
    pCity:GetBuildQueue():CreateIncompleteBuilding(iBuilding, iDistrictPlotIndex, 100);
  else
    if pCity:GetBuildings():IsPillaged(iBuilding) then
      pCity:GetBuildings():SetPillaged(iBuilding, false)
    end
  end
end


--Placebuilding from LEEs Building Subsystem
function PlaceBuildingInCityCenter(pCity, iBuilding)
  local iCityPlotIndex = Map.GetPlot(pCity:GetX(), pCity:GetY()):GetIndex()
  if not pCity:GetBuildings():HasBuilding(iBuilding) then
    pCity:GetBuildQueue():CreateIncompleteBuilding(iBuilding, iCityPlotIndex, 100);
  else
    if pCity:GetBuildings():IsPillaged(iBuilding) then
      pCity:GetBuildings():SetPillaged(iBuilding, false)
    end
  end
end


function Is2ConstructBuilding( ePlayer, iBuilding )
	local player = Players[ePlayer];
	local playerConfig:table = PlayerConfigurations[ePlayer]
	local playerCities = player:GetCities()

			--print(0)
			for i, pCity in playerCities:Members() do
				--print(1)
				if pCity ~= nil then
					--print(2)
					local pCityBuildings = pCity:GetBuildings();
					if pCityBuildings ~= nil then
						--print(3)
						if pCityBuildings:HasBuilding(iBuilding) == true then
							return false
						end
					end
				end
			end
	return true
end

function Is2ConstructDistrict( ePlayer, iDistrict )
	local player = Players[ePlayer];
	local playerConfig:table = PlayerConfigurations[ePlayer]
	local playerCities = player:GetCities()

			--print(0)
			for i, pCity in playerCities:Members() do
				--print(1)
				if pCity ~= nil then
					--print(2)
					local pCityBuildings = pCity:GetDistricts();
					if pCityBuildings ~= nil then
						--print(3)
						if pCityBuildings:HasDistrict(iDistrict) == true then
							return false
						end
					end
				end
			end
	return true
end

function OnPortugueseShipMoved(PlayerID, UnitID, x, y, locallyVisible, stateChange)
  local localPlayer = Game.GetLocalPlayer()

  local plot = Map.GetPlot(x, y)
  local eDistrictType = plot:GetDistrictType()
  local nearPlot = plot:GetNearestLandPlot()
  local unitOwner = localPlayer
  local pPlayer = Players[PlayerID]


  local playerConfig:table = PlayerConfigurations[PlayerID]
  local sLeaderName = playerConfig:GetLeaderTypeName()


  if PlayerID == localPlayer then
    --local unitType = unit:GetUnitType()


    --local unitsInPlot = Units.GetUnitsInPlot(plot)


    local punit = ((pPlayer:GetUnits():FindID(UnitID) == nil) and -1 or pPlayer:GetUnits():FindID(UnitID))


    if punit:GetType() == GameInfo.Units["UNIT_NAU"].Index then


      if ( eDistrictType ~= -1 and (GameInfo.Districts[eDistrictType].DistrictType == "DISTRICT_FOREIGN_PORTO" or  GameInfo.Districts[eDistrictType].DistrictType == "DISTRICT_PORTO")) then

        print("NAU IS IN PORTO --------------------------");

        local pDistrict = CityManager.GetDistrictAt(plot);
        local pCity = pDistrict:GetCity();

        ---cPlot:GetOwner() == nil and
        --print("get owner!"  +  cPlot:GetOwner());

        for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
          local pAdjacentPlot = Map.GetAdjacentPlot(x, y, direction)

          local eDistrictTypeIn = pAdjacentPlot:GetDistrictType();
          ----- Do stuff
          if ( eDistrictTypeIn ~= -1 and  GameInfo.Districts[eDistrictTypeIn].DistrictType == "DISTRICT_COMMERCIAL_HUB"  and pCity:GetBuildings():HasBuilding(iPortoMaritimoBuilding)) then

            print("Porto Has adjacent commercial HUB!!");


            for direction1 = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
              local pAdjacentPlot1 = Map.GetAdjacentPlot(pAdjacentPlot:GetX(), pAdjacentPlot:GetY(), direction1)

              local eDistrictTypeIn1  = pAdjacentPlot1:GetDistrictType();
              ----- Do stuff
              if ( eDistrictTypeIn1 ~= -1 and  GameInfo.Districts[eDistrictTypeIn1].DistrictType == "DISTRICT_CITY_CENTER" ) then

                print("COMMERCIAL HUB  Has adjacent CITY CENTER!!");

				 if sLeaderName == "LEADER_ALBUQUERQUE" and Is2ConstructBuilding( PlayerID, iCasaINdiaBuilding ) == true then
                PlaceBuildingInDistrict(pCity, iCasaINdiaBuilding, pAdjacentPlot:GetIndex())
				end



                for direction2 = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
                  local pAdjacentPlot2 = Map.GetAdjacentPlot(pAdjacentPlot1:GetX(), pAdjacentPlot1:GetY(), direction2)

                  print("CITY CENTER HAS Has adjacent HILLL!!");

                  if (pAdjacentPlot2:GetTerrainType() == th1 or pAdjacentPlot2:GetTerrainType() == th2 or pAdjacentPlot2:GetTerrainType() == th3 or pAdjacentPlot2:GetTerrainType() == th4 or pAdjacentPlot2:GetTerrainType() == th5) then

                    print("BUILD BAIRRO ALTO!!!!!");

                    local iPlotDistrict = Map.GetPlot(pAdjacentPlot2:GetX(), pAdjacentPlot2:GetY()):GetIndex();


                    if pCity:GetBuildings():HasBuilding(iPortoMaritimoBuilding) then

                      print("CITY HAS PORTO MARITIMOOOO!!!!!");

					   if Is2ConstructDistrict( PlayerID, iBAIRROALTODistrict ) == true then
                      PlaceDistrict(pCity, iBAIRROALTODistrict, iPlotDistrict)
					  end


                    else


                      print("CITY HAS NOT PORTO MARITIMOOOO!!!!!");
                    end
                  end
                end
              end
            end

          elseif ( eDistrictTypeIn ~= -1 and  GameInfo.Districts[eDistrictTypeIn].DistrictType == "DISTRICT_HOLY_SITE" and pCity:GetBuildings():HasBuilding(iPortoMaritimoBuilding)) then

            print("Porto Has adjacent HOLY SITE!!");


            for direction1 = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
              local pAdjacentPlot1 = Map.GetAdjacentPlot(pAdjacentPlot:GetX(), pAdjacentPlot:GetY(), direction1)

              local eDistrictTypeIn1 = pAdjacentPlot1:GetDistrictType();
              ----- Do stuff
              if (  eDistrictTypeIn1 ~= -1 and GameInfo.Districts[eDistrictTypeIn1].DistrictType == "DISTRICT_CITY_CENTER" ) then

                print("Holy SITE  Has adjacent CITY CENTER!!");

				 if sLeaderName == "LEADER_MANUEL_I" and Is2ConstructBuilding( PlayerID, iMosteiroJeronimosBuilding ) == true then
                PlaceBuildingInDistrict(pCity, iMosteiroJeronimosBuilding, pAdjacentPlot:GetIndex())
				end
              end

            end
          end
        end
      else

        print("NAU IS NOOOOTTTT IN PORTO --------------------------");

        if (nearPlot ~= -1 and (nearPlot:GetTerrainType() == t1 or nearPlot:GetTerrainType() == t2 or nearPlot:GetTerrainType() == t3 or nearPlot:GetTerrainType() == t4 or nearPlot:GetTerrainType() == t5)) then

          print("Construct Feitoria!!");


		  local pPlayerInfluence = Players[nearPlot:GetOwner()]:GetInfluence();
		  if pPlayerInfluence ~= -1 and pPlayerInfluence:CanReceiveInfluence() then
			BuildFeitoria(nearPlot:GetX(), nearPlot:GetY(), unitOwner, iFeitoriaImprovementType)
			return
          end


        end
      end
    elseif punit:GetType() == GameInfo.Units["UNIT_CARAVELA_EXPLORADORA"].Index then

      if ( eDistrictType ~= -1 and  GameInfo.Districts[eDistrictType].DistrictType == "DISTRICT_PORTO" ) then

        print("CARAVELA LATINA IS IN PORTO --------------------------");


        local pDistrict = CityManager.GetDistrictAt(plot);
        local pCity = pDistrict:GetCity();

        ---cPlot:GetOwner() == nil and
        --print("get owner!"  +  cPlot:GetOwner());

        for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
          local pAdjacentPlot = Map.GetAdjacentPlot(x, y, direction)

          local eDistrictTypeIn  = pAdjacentPlot:GetDistrictType();
          ----- Do stuff
          if (  eDistrictTypeIn ~= -1 and GameInfo.Districts[eDistrictTypeIn].DistrictType == "DISTRICT_CAMPUS" and pCity:GetBuildings():HasBuilding(iEstaleiroBuilding) ) then

            print("Porto Has adjacent CAMPUS!!");


            for direction1 = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
              local pAdjacentPlot1 = Map.GetAdjacentPlot(pAdjacentPlot:GetX(), pAdjacentPlot:GetY(), direction1)

              if pAdjacentPlot1:IsNEOfCliff() or pAdjacentPlot1:IsWOfCliff() or pAdjacentPlot1:IsNWOfCliff() or pAdjacentPlot:IsNEOfCliff() or pAdjacentPlot:IsWOfCliff() or pAdjacentPlot:IsNWOfCliff() then

                print("CAMPUS  Has adjacent CLIFFFF!!");

				 if sLeaderName == "LEADER_JOAO_II" and Is2ConstructBuilding( PlayerID, iEcolaSagresBuilding ) == true then
                PlaceBuildingInDistrict(pCity, iEcolaSagresBuilding, pAdjacentPlot:GetIndex())

				return
				end



              end
            end
          end
        end
      else

        print("CARAVELA LATINA IS NOOOOTTTT IN PORTO --------------------------");

        if (nearPlot ~= -1 and (nearPlot:GetTerrainType() == th1 or nearPlot:GetTerrainType() == th2 or nearPlot:GetTerrainType() == th3 or nearPlot:GetTerrainType() == th4 or nearPlot:GetTerrainType() == th5)) then

		print("Construct PADRAo00000??");
		
			for directionP = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
				local pAdjacentPlotP = Map.GetAdjacentPlot(nearPlot:GetX(), nearPlot:GetY(), directionP)
					print("Construct PADRAO111??");
				local eDistrictTypeInP = pAdjacentPlotP:GetResourceType();
			print(eDistrictTypeInP);
			print("Construct PADRAO??");
			
				if ( eDistrictTypeInP ~= -1 and nearPlot:GetOwner() == -1) then

				print("Construct PADRAO!!");


				
		

				BuildPadrao(nearPlot:GetX(), nearPlot:GetY(), unitOwner, iPadraoImprovementType)

				return

			

end 
end
        end
      end
    end
  end

end







-- Place dummy builgings on city init, for each Portuguese leader
function OnCityInit(iPlayer, iCity, iX, iY)
  dPlayer = Players[iPlayer]
  dCity = dPlayer:GetCities():FindID(iCity)
  local playerConfig:table = PlayerConfigurations[iPlayer]
  local sLeaderName = playerConfig:GetLeaderTypeName()

  if (sLeaderName == "LEADER_JOAO_II") then PlaceBuildingInCityCenter(dCity, MenirBuilding) end
  if (sLeaderName == "LEADER_MANUEL_I") then PlaceBuildingInCityCenter(dCity, CromeBuilding) end
  if (sLeaderName == "LEADER_ALBUQUERQUE") then PlaceBuildingInCityCenter(dCity, AntaBuilding) end

  if( sLeaderName ~= "LEADER_JOAO_II" and sLeaderName ~= "LEADER_MANUEL_I" and sLeaderName ~= "LEADER_ALBUQUERQUE") then
	PlaceBuildingInCityCenter(dCity, MegaLithBuilding)
  end

  --------FOR DEBUG 4 districts--------dCity:ChangePopulation(12)

end


--LAUNCH HERE
Events.CityInitialized.Add(OnCityInit);
Events.UnitMoveComplete.Add(OnPortugueseShipMoved);
--==============================================================================================================================
--==============================================================================================================================