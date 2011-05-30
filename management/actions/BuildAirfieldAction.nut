/**
 * Action class for the creation of airfields.
 */
class BuildAirfieldAction extends Action {
	connection = null;			// Connection object of the road to build.
	world = null;				// The world.

	constructor(connection, world) {
		Action.constructor();
		this.connection = connection;
		this.world = world;
	}
}

function BuildAirfieldAction::GetLargestAirport(checkMoney, location) {
	// List all possible airports, big to small.
	local airportList = [
		AIAirport.AT_INTERCON,
		AIAirport.AT_INTERNATIONAL,
		AIAirport.AT_METROPOLITAN,
		AIAirport.AT_LARGE,
		AIAirport.AT_COMMUTER,
		AIAirport.AT_SMALL,
	];

	// List all possible airports, big to small.
	/*local heliportList = [
		AIAirport.AT_HELISTATION,
		AIAirport.AT_HELIDEPOT,
	];*/
	

	// Try to build the biggest airport possible, but don't try to build small ones if we can build big ones!
	local airportType = null;
	local bigAirportAvailable = false;

	foreach (at in airportList) {
		local closestTown = AIAirport.GetNearestTown(location, at);
		if (AIAirport.IsValidAirportType(at)) {
			if (at != AIAirport.AT_SMALL && at != AIAirport.AT_COMMUTER)
				bigAirportAvailable = true;

			// Don't build small airports if larger ones are available!
			if (bigAirportAvailable && (at == AIAirport.AT_SMALL || at == AIAirport.AT_COMMUTER))
				return null;

			if ((!checkMoney || Finance.GetMaxMoneyToSpend() > AIAirport.GetPrice(at) * 2) &&
			    AITown.GetAllowedNoise(closestTown) >= AIAirport.GetNoiseLevelIncrease(location, at)
			    ) {
				airportType = at;
				break;
			}
		}
	}
	
	return airportType;
}


function BuildAirfieldAction::Execute() {

/*	local airportType = GetLargestAirport(true);
	if (airportType == null) {
		Log.logWarning("Not enough money to build any airport!");
		return false;
	}
*/

/*
	local heliportType = null;
	foreach (at in heliportList) {
		if (AIAirport.IsValidAirportType(at)) {
			heliportType = at;
			Log.logInfo("helipad found!");
			break;
		}
	}
*/

//	local useHelipadAtFromNode = false;
//	local useHelipadAtToNode = false;
	local townToTown = connection.travelFromNode.nodeType == ConnectionNode.TOWN_NODE && connection.travelToNode.nodeType == ConnectionNode.TOWN_NODE;
	local fromTileAndAirportType = FindSuitableAirportSpot(/*airportType, */connection.travelFromNode, connection.cargoID, false, false, townToTown);
	if (fromTileAndAirportType == null) {
/*
		// If no tile was found, check if the industry has a helipad to land on.
		if (connection.travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE &&
			AIIndustry.HasHeliport(connection.travelFromNode.id) &&
			heliportType != null) {
			useHelipadAtFromNode = true;
			airportType = heliportType;
		} else {
*/
			Log.logWarning("No spot found for the first airfield!");
			connection.forceReplan = true;
			return false;
//		}
	}
	local toTileAndAirportType = FindSuitableAirportSpot(/*airportType, */connection.travelToNode, connection.cargoID, true, false, townToTown);
	if (toTileAndAirportType == null) {
/*
		if (connection.travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE &&
			AIIndustry.HasHeliport(connection.travelToNode.id) &&
			heliportType != null) {
			useHelipadAtToNode = true;
			airportType = heliportType;
		} else {
*/
			Log.logWarning("No spot found for the second airfield!");
			connection.forceReplan = true;
			return false;
//		}
	}

	local fromTile = fromTileAndAirportType[0];
	local fromAirportType = fromTileAndAirportType[1];
	local toTile = toTileAndAirportType[0];
	local toAirportType = toTileAndAirportType[1];
	
	local a = AITestMode();
	local cost = AIAccounting();
	local fromAirportX = AIAirport.GetAirportWidth(fromAirportType);
	local fromAirportY = AIAirport.GetAirportHeight(fromAirportType);
	if (!AIAirport.BuildAirport(fromTile, fromAirportType, AIStation.STATION_NEW) && 
	!Terraform.Terraform(fromTile, fromAirportX, fromAirportY, -1)) {
	    AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + fromTile + " [" + fromAirportType + "].");
	    AILog.Error(AIError.GetLastErrorString());
		connection.forceReplan = true;
	    return false;
	}

	local toAirportX = AIAirport.GetAirportWidth(fromAirportType);
	local toAirportY = AIAirport.GetAirportHeight(fromAirportType);
	if (!AIAirport.BuildAirport(toTile, toAirportType, AIStation.STATION_NEW) && 
	!Terraform.Terraform(toTile, toAirportX, toAirportY, -1)) {
	    AILog.Error("Although the testing told us we could build 2 airports, it still failed on the second airport at tile " + toTile + " [" + toAirportType + "].");
	    AILog.Error(AIError.GetLastErrorString());
		connection.forceReplan = true;
	    AIAirport.RemoveAirport(fromTile);
	    return false;
	}
	if (cost.GetCosts() > Finance.GetMaxMoneyToSpend())
		return false;
	
	/* Build the airports for real */
	local test = AIExecMode();
	if (!AIAirport.BuildAirport(fromTile, fromAirportType, AIStation.STATION_NEW) && 
	!(Terraform.Terraform(fromTile, fromAirportX, fromAirportY, -1) && AIAirport.BuildAirport(fromTile, fromAirportType, AIStation.STATION_NEW))) {
	    AILog.Error("Although the testing told us we could build 2 airports, it still failed on the first airport at tile " + fromTile + " [" + fromAirportType + "].");
	    AILog.Error(AIError.GetLastErrorString());
		connection.forceReplan = true;
	    return false;
	}
	if (!AIAirport.BuildAirport(toTile, toAirportType, AIStation.STATION_NEW) && 
	!(Terraform.Terraform(toTile, toAirportX, toAirportY, -1) && AIAirport.BuildAirport(toTile, toAirportType, AIStation.STATION_NEW))) {
	    AILog.Error("Although the testing told us we could build 2 airports, it still failed on the second airport at tile " + toTile + " [" + toAirportType + "].");
	    AILog.Error(AIError.GetLastErrorString());
		connection.forceReplan = true;
	    AIAirport.RemoveAirport(fromTile);
	    return false;
	}
	
	local start = AnnotatedTile();
	start.tile = fromTile;
	local end = AnnotatedTile();
	end.tile = toTile;
	connection.pathInfo.depot = AIAirport.GetHangarOfAirport(fromTile);
	connection.pathInfo.depotOtherEnd = AIAirport.GetHangarOfAirport(toTile);
	connection.pathInfo.roadList = [end, start];
	
	local maxAirportCoverage = (AIAirport.GetAirportCoverageRadius(fromAirportType) < AIAirport.GetAirportCoverageRadius(toAirportType) ? AIAirport.GetAirportCoverageRadius(toAirportType) : AIAirport.GetAirportCoverageRadius(fromAirportType));
	connection.UpdateAfterBuild(AIVehicle.VT_AIR, fromTile, toTile, maxAirportCoverage);

	CallActionHandlers();
	totalCosts = AIAirport.GetPrice(toAirportType) + AIAirport.GetPrice(fromAirportType);
	return true;
}

/**
 * Find a good location to build an airfield and return it.
 * @param airportType The type of airport which needs to be build.
 * @param node The connection node where the airport needs to be build.
 * @param cargoID The cargo that needs to be transported.
 * @param acceptingSide If true this side is considered as begin the accepting side of the connection.
 * @param getFirst If true ignores the exclude list and gets the first suitable spot to build an airfield
 * ignoring terraforming (it's only used to determine the cost of building an airport).
 * @param townToTown True if this airfield is part of a town to town connection. In that case we enforce
 * stricter rules on placement of these airfields.
 * @return The tile where the airport can be build.
 */
function BuildAirfieldAction::FindSuitableAirportSpot(/*airportType,*/ node, cargoID, acceptingSide, getFirst, townToTown) {
	local tile = node.GetLocation();
	local excludeList;
	
	if (getFirst && node.nodeType == ConnectionNode.TOWN_NODE) {
		excludeList = clone node.excludeList;
		node.excludeList = {};
	}

	local baseLineAirportType = BuildAirfieldAction.GetLargestAirport(!getFirst, tile);
	// This means we can build no airport what so ever!
	if (baseLineAirportType == null)
		return null;

	local airportX = AIAirport.GetAirportWidth(baseLineAirportType);
	local airportY = AIAirport.GetAirportHeight(baseLineAirportType);
	local airportRadius = AIAirport.GetAirportCoverageRadius(baseLineAirportType);

	local list = (acceptingSide ? node.GetAllAcceptingTiles(cargoID, airportRadius, airportX, airportY) : node.GetAllProducingTiles(cargoID, airportRadius, airportX, airportY));
	list.Valuate(AITile.IsBuildableRectangle, airportX, airportY);
	list.KeepValue(1);
	AIController.Sleep(1);

	if (getFirst) {
		if (node.nodeType == ConnectionNode.TOWN_NODE)
			node.excludeList = excludeList;
	} else {
		if (node.nodeType == ConnectionNode.TOWN_NODE || acceptingSide) {
			list.Valuate(AITile.GetCargoAcceptance, cargoID, airportX, airportY, airportRadius);
			if (townToTown)
				list.KeepAboveValue(30);
			else
				list.KeepAboveValue(7);
		} else {
			list.Valuate(AITile.GetCargoProduction, cargoID, airportX, airportY, airportRadius);
			list.KeepAboveValue(0);
		}
	}
    
	/* Couldn't find a suitable place for this town, skip to the next */
	if (list.Count() == 0) {
		Log.logDebug("NO spots found :(");
		return null;
	}
	list.Sort(AIAbstractList.SORT_BY_VALUE, false);
    
	local good_tile = -1;
	local airport_type = -1;
	/* Walk all the tiles and see if we can build the airport at all */
	{
    	local test = AITestMode();
		foreach (tile, value in list) {
			local airportType = BuildAirfieldAction.GetLargestAirport(!getFirst, tile);
			if (airportType == null)
				continue;
        		local nearestTown = AIAirport.GetNearestTown(tile, airportType);
			// Check if we can build an airport here, either directly or by terraforming.
			if (!AIAirport.BuildAirport(tile, airportType, AIStation.STATION_NEW) ||
			    AITown.GetRating(nearestTown, AICompany.COMPANY_SELF) <= -200)
				continue

// || AITown.GetAllowedNoise(nearestTown) < AIAirport.GetNoiseLevelIncrease(tile, airportType)) continue;
			good_tile = tile;
			airport_type = airportType;
			break;
		}

		if (good_tile == -1) {
			foreach (tile, value in list) {
				local airportType = BuildAirfieldAction.GetLargestAirport(!getFirst, tile);
				if (airportType == null)
					continue;
        			local nearestTown = AIAirport.GetNearestTown(tile, airportType);
				airportX = AIAirport.GetAirportWidth(airportType);
				airportY = AIAirport.GetAirportHeight(airportType);
				// Check if we can build an airport here, either directly or by terraforming.
				if (!AIAirport.BuildAirport(tile, airportType, AIStation.STATION_NEW) &&
				   (getFirst || !Terraform.CheckTownRatings(tile, airportX, airportY) ||
				   !Terraform.Terraform(tile, airportX, airportY, -1)))
					continue;

// || AITown.GetAllowedNoise(nearestTown) < AIAirport.GetNoiseLevelIncrease(tile, airportType))) continue;
				good_tile = tile;
				airport_type = airportType;
				break;
			}
		}
	}
	if (good_tile == -1)
		return null;
	return [good_tile, airport_type];
}

/**
 * Return the cost to build an airport at the given node. Once the cost for one type
 * of airport is calculated it is cached for little less then a year after which it
 * is reevaluated.
 * @param node The connection node where the airport needs to be build.
 * @param cargoID The cargo the connection should transport.
 * @param acceptingSide If true it means that the node will be evaluated as the accepting side.
 * @return The total cost of building the airport.
 */
function BuildAirfieldAction::GetAirportCost(node, cargoID, acceptingSide) {

	local airportType = (AIAirport.IsValidAirportType(AIAirport.AT_LARGE) ? AIAirport.AT_LARGE : AIAirport.AT_SMALL);
	return AIAirport.GetPrice(airportType);
}
