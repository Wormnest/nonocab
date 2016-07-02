/**
 * Action class for the creation of ship yards.
 */
class BuildShipYardAction extends BuildConnectionAction {
	
	constructor(connection) {
		BuildConnectionAction.constructor(connection);
	}
}


function BuildShipYardAction::Execute() {	

	local accounter = AIAccounting();
	local pathFindingHelper = WaterPathFinderHelper();
	local pathFinder = RoadPathFinding(pathFindingHelper);

	local stationType = AIStation.STATION_DOCK;
	local stationRadius = AIStation.GetCoverageRadius(stationType);
	local fromNode = connection.travelFromNode;
	local toNode = connection.travelToNode;
	local producingTiles = fromNode.GetAllProducingTiles(connection.cargoID, stationRadius, 1, 1);
	local acceptingTiles = toNode.GetAllAcceptingTiles(connection.cargoID, stationRadius, 1, 1);


	if (!(fromNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(fromNode.id))) {
		producingTiles.Valuate(AITile.IsCoastTile);
		producingTiles.KeepValue(1);

		if (fromNode.nodeType == ConnectionNode.TOWN_NODE) {
			producingTiles.Valuate(AITile.GetCargoAcceptance, connection.cargoID, 1, 1, stationRadius);
			producingTiles.Sort(AIList.SORT_BY_VALUE, false);
		}
	} else {
		producingTiles.Valuate(AITile.IsWaterTile);
		producingTiles.KeepValue(1);
		pathFinder.pathFinderHelper.startLocationIsBuildOnWater = true;
	}

	if (!(toNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(toNode.id))) {
		acceptingTiles.Valuate(AITile.IsCoastTile);
		acceptingTiles.KeepValue(1);

		if (toNode.nodeType == ConnectionNode.TOWN_NODE) {
			acceptingTiles.Valuate(AITile.GetCargoAcceptance, connection.cargoID, 1, 1, stationRadius);
			acceptingTiles.Sort(AIList.SORT_BY_VALUE, false);
		}
	} else {
		acceptingTiles.Valuate(AITile.IsWaterTile);
		acceptingTiles.KeepValue(1);	
		pathFinder.pathFinderHelper.endLocationIsBuildOnWater = true;
	}

	if (producingTiles.Count() == 0 || acceptingTiles.Count() == 0) {
		FailedToExecute("No point found to build the docks");
		return false;
	}
	
	// Check if we have enough permission to build here.
	if (AITown.GetRating(AITile.GetClosestTown(producingTiles.Begin()), AICompany.COMPANY_SELF) < -200) {
		FailedToExecute("No point found to build the docks");
		return false;
	}
		
	// Check if we have enough permission to build here.
	if (AITown.GetRating(AITile.GetClosestTown(acceptingTiles.Begin()), AICompany.COMPANY_SELF) < -200) {
		FailedToExecute("No point found to build the docks");
		return false;
	}	
	
	local pathInfo = pathFinder.FindFastestRoad(producingTiles, acceptingTiles, true, true, stationType, AIMap.DistanceManhattan(fromNode.GetLocation(), toNode.GetLocation()) * 3, null);

	if (pathInfo == null) {
		FailedToExecute("No point found to build the docks");
		return false;
	}
	connection.pathInfo = pathInfo;
	local roadList = connection.pathInfo.roadList;
	local toTile = roadList[0].tile;
	local fromTile = roadList[roadList.len() - 1].tile;

	/* Build the shipYards for real */
	if (!(connection.travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(connection.travelFromNode.id)) && !AIMarine.BuildDock(fromTile, AIStation.STATION_NEW)) {
		FailedToExecute("Although the testing told us we could build 2 shipYards, it still failed on the first shipYard at tile " + AIError.GetLastErrorString());
		return false;
	}

	if (!(connection.travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(connection.travelToNode.id)) && !AIMarine.BuildDock(toTile, AIStation.STATION_NEW)) {
		FailedToExecute("Although the testing told us we could build 2 shipYards, it still failed on the second shipYard at tile." + AIError.GetLastErrorString());
		AIMarine.RemoveDock(fromTile);
		return false;
	}

	local start = AnnotatedTile();
	start.tile = fromTile;
	local end = AnnotatedTile();
	end.tile = toTile;

	/* Now build some depots... */
	connection.pathInfo.depot = BuildDepot(roadList, true);
	if (connection.pathInfo.depot == null) {
		AIMarine.RemoveDock(fromTile);
		AIMarine.RemoveDock(toTile);
		FailedToExecute("Could not build the first depot.");
		// Do not replan since it most likely will fail again
		//connection.forceReplan = true;
		return false;
	}

	if (connection.bilateralConnection) {
		connection.pathInfo.depotOtherEnd = BuildDepot(roadList, false);
		if (connection.pathInfo.depotOtherEnd == null) {
			AIMarine.RemoveDock(fromTile);
			AIMarine.RemoveDock(toTile);
			AIMarine.RemoveWaterDepot(connection.pathInfo.depot);
			FailedToExecute("Could not build the second depot.");
			// Do not replan since it most likely will fail again
			//connection.forceReplan = true;
			return false;
		}
	}
	
	// Build buoys last to make it easier to find a spot for the water depots
	local waterBuilder = WaterPathBuilder(connection.pathInfo.roadList);
	if (!waterBuilder.RealiseConnection()) {
		FailedToExecute("Couldn't build the water way!");
		RemoveBuoys();
		AIMarine.RemoveDock(fromTile);
		AIMarine.RemoveDock(toTile);
		AIMarine.RemoveWaterDepot(connection.pathInfo.depot);
		if (connection.pathInfo.depotOtherEnd != null)
			AIMarine.RemoveWaterDepot(connection.pathInfo.depotOtherEnd);
		// Do not replan since it most likely will fail again
		//connection.forceReplan = true;
		return false;
	}

	// Reconstruct road list.
	local newRoadList = [end];
	if (connection.travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(connection.travelToNode.id))
		end.tile = connection.travelToNode.GetLocation();
	
	foreach (at in connection.pathInfo.roadList)
		if (AIMarine.IsBuoyTile(at.tile) || AIMarine.IsWaterDepotTile(at.tile))
			newRoadList.push(at);
	newRoadList.push(start);
	if (connection.travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE && AIIndustry.IsBuiltOnWater(connection.travelFromNode.id))
		start.tile = connection.travelFromNode.GetLocation();
	connection.pathInfo.roadList = newRoadList;
	connection.UpdateAfterBuild(AIVehicle.VT_WATER, start.tile, end.tile, AIStation.GetCoverageRadius(AIStation.STATION_DOCK))

	CallActionHandlers();
	totalCosts = accounter.GetCosts();
	return true;
}

function BuildShipYardAction::RemoveBuoys() {
	if (connection.pathInfo == null || connection.pathInfo.roadList == null)
		return;
	waterRoute = connection.pathInfo.roadList;
	for (local i = 0; i < waterRoute.len(); i++) {
		if (AIMarine.IsBuoyTile(roadList[i].tile)) {
			/// @todo It would be better to first check if there are any ships that have orders to go via this buoy
			/// @todo but currently there is no API to access all vehicles with orders via a specific waypoint
			// Since we are currently not reusing buoys on purpose the only way this could happen is when we
			// try to build a buoy on a tile that already has a buoy which will probably be a rare case which we will accept for now.
			AIMarine.RemoveBuoy(roadList[i].tile);
		}
	}
}

function BuildShipYardAction::BuildDepot(roadList, fromTile) {

	local depotLoc = null;
	local tilesAround = [1, AIMap.GetMapSizeX()];
	local tilesAroundReversed = [-AIMap.GetMapSizeX(), -1];
	local docktile = (fromTile ? roadList[roadList.len()-1].tile : roadList[0].tile);
	for (local i = (fromTile ? roadList.len() - 3 : 3); i > 2 && i < roadList.len() - 2; i += (fromTile ? -1 : 1)) {
		
		local pos = roadList[i].tile;		// First tile of depot
		local pos2 = pos + tilesAround[1];	// Second tile of depot

		// A water depot should be able to be reached through water from either the top or bottom short side.
		// Besides that we need to make sure that it does not block on any side a water depot or dock
		// Check first possible layout
		if (/*AITile.IsWaterTile(pos + tilesAround[0] * 2) &&*/ AITile.IsWaterTile(pos + tilesAround[0]) &&
			/*AITile.IsWaterTile(pos - tilesAround[0] * 2) &&*/ AITile.IsWaterTile(pos - tilesAround[0]) &&
			/*AITile.IsWaterTile(pos2 + tilesAround[0] * 2) &&*/ AITile.IsWaterTile(pos2 + tilesAround[0]) &&
			/*AITile.IsWaterTile(pos2 - tilesAround[0] * 2) &&*/ AITile.IsWaterTile(pos2 - tilesAround[0]) &&
			/*!AIMarine.IsDockTile(pos + tilesAround[0] * 2) &&*/ !AIMarine.IsDockTile(pos + tilesAround[0]) &&
			/*!AIMarine.IsDockTile(pos - tilesAround[0] * 2) &&*/ !AIMarine.IsDockTile(pos - tilesAround[0]) &&
			/*!AIMarine.IsDockTile(pos2 + tilesAround[0] * 2) &&*/ !AIMarine.IsDockTile(pos2 + tilesAround[0]) &&
			/*!AIMarine.IsDockTile(pos2 - tilesAround[0] * 2) &&*/ !AIMarine.IsDockTile(pos2 - tilesAround[0]) &&
			/*!AIMarine.IsWaterDepotTile(pos + tilesAround[0] * 2) &&*/ !AIMarine.IsWaterDepotTile(pos + tilesAround[0]) &&
			/*!AIMarine.IsWaterDepotTile(pos - tilesAround[0] * 2) &&*/ !AIMarine.IsWaterDepotTile(pos - tilesAround[0]) &&
			/*!AIMarine.IsWaterDepotTile(pos2 + tilesAround[0] * 2) &&*/ !AIMarine.IsWaterDepotTile(pos2 + tilesAround[0]) &&
			/*!AIMarine.IsWaterDepotTile(pos2 - tilesAround[0] * 2) &&*/ !AIMarine.IsWaterDepotTile(pos2 - tilesAround[0]) &&
			AITile.IsWaterTile(pos - tilesAround[1]) &&
			AITile.IsWaterTile(pos + tilesAround[1]  * 2) && /*AITile.IsWaterTile(pos + tilesAround[1] * 3) &&*/
			!AIMarine.IsDockTile(pos - tilesAround[1]) &&
			!AIMarine.IsDockTile(pos + tilesAround[1] * 2) && /*!AIMarine.IsDockTile(pos + tilesAround[1] * 3) &&*/
			!AIMarine.IsWaterDepotTile(pos - tilesAround[1]) &&
			!AIMarine.IsWaterDepotTile(pos + tilesAround[1] * 2) && /*!AIMarine.IsWaterDepotTile(pos + tilesAround[1] * 3) &&*/
			AIMap.DistanceManhattan(docktile, pos) <= 15 &&
			AIMarine.BuildWaterDepot(pos, pos + tilesAroundReversed[0])) {
				depotLoc = pos;
				break;
		}

		pos2 = pos + tilesAround[0];	// Second tile of depot
		// Check second possible layout
		if (/*AITile.IsWaterTile(pos + tilesAround[1] * 2) &&*/ AITile.IsWaterTile(pos + tilesAround[1]) &&
			/*AITile.IsWaterTile(pos - tilesAround[1] * 2) &&*/ AITile.IsWaterTile(pos - tilesAround[1]) &&
			/*AITile.IsWaterTile(pos2 + tilesAround[1] * 2) &&*/ AITile.IsWaterTile(pos2 + tilesAround[1]) &&
			/*AITile.IsWaterTile(pos2 - tilesAround[1] * 2) &&*/ AITile.IsWaterTile(pos2 - tilesAround[1]) &&
			/*!AIMarine.IsDockTile(pos + tilesAround[1] * 2) &&*/ !AIMarine.IsDockTile(pos + tilesAround[1]) &&
			/*!AIMarine.IsDockTile(pos - tilesAround[1] * 2) &&*/ !AIMarine.IsDockTile(pos - tilesAround[1]) &&
			/*!AIMarine.IsDockTile(pos2 + tilesAround[1] * 2) &&*/ !AIMarine.IsDockTile(pos2 + tilesAround[1]) &&
			/*!AIMarine.IsDockTile(pos2 - tilesAround[1] * 2) &&*/ !AIMarine.IsDockTile(pos2 - tilesAround[1]) &&
			/*!AIMarine.IsWaterDepotTile(pos + tilesAround[1] * 2) &&*/ !AIMarine.IsWaterDepotTile(pos + tilesAround[1]) &&
			/*!AIMarine.IsWaterDepotTile(pos - tilesAround[1] * 2) &&*/ !AIMarine.IsWaterDepotTile(pos - tilesAround[1]) &&
			/*!AIMarine.IsWaterDepotTile(pos2 + tilesAround[1] * 2) &&*/ !AIMarine.IsWaterDepotTile(pos2 + tilesAround[1]) &&
			/*!AIMarine.IsWaterDepotTile(pos2 - tilesAround[1] * 2) &&*/ !AIMarine.IsWaterDepotTile(pos2 - tilesAround[1]) &&
			AITile.IsWaterTile(pos - tilesAround[0]) &&
			AITile.IsWaterTile(pos + tilesAround[0] * 2) && /*AITile.IsWaterTile(pos + tilesAround[0] * 3) &&*/
			!AIMarine.IsDockTile(pos - tilesAround[0]) &&
			!AIMarine.IsDockTile(pos + tilesAround[0] * 2) && /*!AIMarine.IsDockTile(pos + tilesAround[0] * 3) &&*/
			!AIMarine.IsWaterDepotTile(pos - tilesAround[0]) &&
			!AIMarine.IsWaterDepotTile(pos + tilesAround[0] * 2) && /*!AIMarine.IsWaterDepotTile(pos + tilesAround[0] * 3) &&*/
			AIMap.DistanceManhattan(docktile, pos) <= 15 &&
			AIMarine.BuildWaterDepot(pos, pos + tilesAroundReversed[1])) {
				depotLoc = pos;
				break;
		}
	}

	if (!depotLoc) {
		Log.logWarning("Couldn't find a suitable location for the waterdepot!");
		return null;
	}
	return depotLoc;
}

/**
 * Get the costs of building a ship connection
 */
function BuildShipYardAction::GetCosts() {
	return 2 * AIMarine.GetBuildCost(AIMarine.BT_DOCK) + AIMarine.GetBuildCost(AIMarine.BT_DEPOT) + 10 * AIMarine.GetBuildCost(AIMarine.BT_BUOY);
}
