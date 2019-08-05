------------------------------------------------------------------------------
--	FILE:	 CityIslands.lua
--	AUTHOR:  
--	PURPOSE: Modified from Pangea.lua, for creating a map of islands.
------------------------------------------------------------------------------

include "MapEnums"
include "MapUtilities"
include "MountainsCliffs"
include "RiversLakes"
include "FeatureGenerator"
include "TerrainGenerator"
include "NaturalWonderGenerator"
include "ResourceGenerator"
include "CoastalLowlands"
include "AssignStartingPlots"

local g_iW, g_iH;
local g_iFlags = {};
local g_continentsFrac = nil;
local world_age_new = 5;
local world_age_normal = 3;
local world_age_old = 2;

-------------------------------------------------------------------------------
function GenerateMap()
	print("Generating City Islands Map");
	local pPlot;

	-- Set globals
	g_iW, g_iH = Map.GetGridSize();
	g_iFlags = TerrainBuilder.GetFractalFlags();
	local temperature = MapConfiguration.GetValue("temperature"); -- Default setting is Temperate.
	if temperature == 4 then
		temperature  =  1 + TerrainBuilder.GetRandomNumber(3, "Random Temperature- Lua");
	end
	
	--	local world_age
	local world_age = MapConfiguration.GetValue("world_age");
	if (world_age == 1) then
		world_age = world_age_new;
	elseif (world_age == 2) then
		world_age = world_age_normal;
	elseif (world_age == 3) then
		world_age = world_age_old;
	else
		world_age = 2 + TerrainBuilder.GetRandomNumber(4, "Random World Age - Lua");
	end

	local plotTypes = GeneratePlotTypes(world_age);
	local terrainTypes = GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, true, temperature);
	
	for i = 0, (g_iW * g_iH) - 1, 1 do 
		pPlot = Map.GetPlotByIndex(i);
		if (plotTypes[i] == g_PLOT_TYPE_HILLS) then
			terrainTypes[i] = terrainTypes[i] + 1;
		end
		TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
	end	
	
	AreaBuilder.Recalculate();
	local biggest_area = Areas.FindBiggestArea(false);
	print("After Adding Hills: ", biggest_area:GetPlotCount());
	
	AddRivers();
	
	-- Lakes would interfere with rivers, causing them to stop and not reach the ocean, if placed any sooner.
	local numLargeLakes = math.ceil(GameInfo.Maps[Map.GetMapSize()].Continents / 2);
	AddLakes(numLargeLakes);

	AddFeatures();
	
	AddCliffs(plotTypes, terrainTypes);
	
	local args = {numberToPlace = GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders};
	local nwGen = NaturalWonderGenerator.Create(args);

	AreaBuilder.Recalculate();
	TerrainBuilder.AnalyzeChokepoints();
	TerrainBuilder.StampContinents();
	
	local resourcesConfig = MapConfiguration.GetValue("resources");
	local startConfig = MapConfiguration.GetValue("start");-- Get the start config
	local args = {
		iWaterLux = 4,
		resources = resourcesConfig,
		START_CONFIG = startConfig,
	};
	
	local resGen = ResourceGenerator.Create(args);


	print("Creating start plot database.");
	-- START_MIN_Y and START_MAX_Y is the percent of the map ignored for major civs' starting positions.
	local args = {
		MIN_MAJOR_CIV_FERTILITY = 85,
		MIN_MINOR_CIV_FERTILITY = 5, 
		MIN_BARBARIAN_FERTILITY = 1,
		START_MIN_Y = 15,
		START_MAX_Y = 15,
		WATER = true,
		START_CONFIG = startConfig,
	};
	
	local start_plot_database = AssignStartingPlots.Create(args);
	local GoodyGen = AddGoodies(g_iW, g_iH);
end

-------------------------------------------------------------------------------
function GeneratePlotTypes(world_age)
	print("Generating Plot Types");
	local plotTypes = {};
	
	plotTypes = GenerateCityIslands(plotTypes);
	
	local args = {};
	args.iW = g_iW;
	args.iH = g_iH
	args.iFlags = g_iFlags;
	args.blendRidge = 5;
	args.blendFract = 5;
	args.world_age = world_age + 0.25;
	mountainRatio = 2 + world_age * 2;
	plotTypes = ApplyTectonics(args, plotTypes);
	plotTypes = AddLonelyMountains(plotTypes, mountainRatio);
	
	return plotTypes;
end

function GenerateCityIslands(plotTypes)
	math.randomseed(os.time());
	local isleSpawnChance = MapConfiguration.GetValue("isle_spawn_chance");
	for x = 0, ( g_iW ) * ( g_iH ), 1 do
		plotTypes[x] = g_PLOT_TYPE_OCEAN;
	end
	local rows = g_iH / 8;
	local columns = g_iW / 8;
	local isLandFuncs = { };
	
	--Assign IsLand Functions to indices 1-6 based on config settings.
	if MapConfiguration.GetValue("standard_islands" ) then
		isLandFuncs[1] = IsLand_Standard;
	end
	
	if MapConfiguration.GetValue("smaller_islands" ) then
		isLandFuncs[2] = IsLand_Smaller;
	end
	
	if MapConfiguration.GetValue("narrow_islands" ) then
		isLandFuncs[3] = IsLand_Thin;
	end
	
	if MapConfiguration.GetValue("short_islands" ) then
		isLandFuncs[4] = IsLand_Squat;
	end
	
	if MapConfiguration.GetValue("geminislands" ) then
		isLandFuncs[5] = function(y,x)
			return IsLand_Gemini(y,x);
		end
	end
	
	if MapConfiguration.GetValue("spiral_islands" ) then
		isLandFuncs[6] = IsLand_Spiral;
	end

	local isLandFunc = nil;
	local offset = false;
	for row = 0, rows - 1, 1 do
		for column = 0, columns - 1, 1 do
			if math.random(100) <= isleSpawnChance then
				while isLandFunc == nil do
					isLandFunc = isLandFuncs[math.random(6)];
				end
				for subRow = row * 8, 7 + ( row * 8 ), 1 do
					--When we reach the last column in an offset row,
					--we can treat the first 4 subcolumns of the subColumn
					--loop as normal. The LAST 4 subcolumns should ACTUALLY
					--be the FIRST four subcolumns of the entire row.
					for subCol = column * 8, 7 + ( column * 8 ), 1 do
						local yLand = subRow % 8;
						local xLand = subCol % 8;
						local lastFourIndex = subCol % 4;
						local lastFour = 
							offset and ( column == columns - 1 ) and 
							xLand > 3;
						local i;
						
						if lastFour then
							i = lastFourIndex + ( subRow * g_iW );
						elseif offset then 
							i = 4 + subCol + ( subRow * g_iW );
						else
							i = subCol + ( subRow * g_iW );
						end
						if isLandFunc(yLand, xLand) then
							plotTypes[i] = g_PLOT_TYPE_LAND;
						end
					end
				end--Set to nil to for the next one.
				isLandFunc = nil;
			end
		end
		offset = not offset;
	end
	
	return plotTypes;
end

function PrintIfTrue( message, bool )
	if bool then
		print( message );
	end
end

function IsLand_Test(y,x)
	if x == 0 then
		return y > 2 and y < 6;
	elseif x > 0 and x < 5 then
		return y > 0;
	elseif x == 5 then
		return y > 1 and y < 7;
	elseif x == 6 then
		return y == 4;
	else
		return false;
	end
end

--For Standard Islands.
function IsLand_Standard(y,x)
	if x == 0 then
		return y > 2 and y < 6;
	elseif x > 0 and x < 4 then
		return y > 0;
	elseif x == 4 then
		return
			( y > 0 and y < 3 ) or y > 5
	else
		return false;
	end
end

--For smaller islands.
function IsLand_Smaller(y,x)
	if x == 1 then
		return y > 2 and y < 6;
	elseif x > 0 and x < 4 then
		return y > 1 and y < 7;
	elseif x == 4 then
		return
			( y > 1 and y < 4 ) or
			( y > 4 and y < 7 );
	else
		return false;
	end
end

function IsLand_Thin(y,x)
	if x == 1 then
		return y > 2 and y < 6;
	elseif x > 0 and x < 4 then
		return y > 0;
	elseif x == 4 then
		return ( y > 0 and y < 3 ) or y > 5;
	else
		return false;
	end
end

function IsLand_Squat(y,x)
	if x == 0 then
		return y > 2 and y < 6;
	elseif x < 4 then
		return y > 1 and y < 7;
	elseif x == 4 then
		return y == 2 or y == 6;
	else
		return false;
	end
end

function IsLand_Gemini(y,x)
	if x == 0 then
		return y > 2 and y < 6;
	elseif x == 1 then
		return y > 2;
	elseif x  == 2 then
		return y > 3;
	elseif x == 3 then
		return y > 0 and y ~= 5 and y ~= 7;
	elseif x == 4 then
		return y > 0 and y < 6;
	elseif x == 5 then
		return y > 1 and y < 6;
	else
		return x == 6 and y == 4;
	end
end

function IsLand_Spiral(y,x)
	if x == 0 then
		return y > 2 and y < 6;
	elseif x == 1 then
		return ( y > 0 and y < 3 ) or y > 5;
	elseif x == 2 then
		return y == 1 or y == 3 or y == 4 or y == 7;
	elseif x == 3 then
		return y == 1 or ( y > 2 and y < 7 );
	elseif x == 4 then
		return y == 1 or y == 4 or y == 7;
	elseif x == 5 then
		return
			( y > 1 and y < 4 ) or 
			( y > 4 and y < 7 );
	elseif x == 6 then
		return y == 4;
	else
		return false;
	end
end
function AddFeatures()
	print("Adding Features");

	-- Get Rainfall setting input by user.
	local rainfall = MapConfiguration.GetValue("rainfall");
	if rainfall == 4 then
		rainfall = 1 + TerrainBuilder.GetRandomNumber(3, "Random Rainfall - Lua");
	end
	
	local args = {rainfall = rainfall}
	local featuregen = FeatureGenerator.Create(args);
	featuregen:AddFeatures();
end