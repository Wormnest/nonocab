/**
 * This class is responsible of maintaining already build connections by
 * advising to sell or buy vehicles.
 */
class VehiclesAdvisor extends Advisor {

	connectionManager = null;
	reports = null;
	
	constructor(connectionManager) {
		Advisor.constructor();
		this.connectionManager = connectionManager;
		reports = [];
	}
}

/**
 * Get the number of vehicles waiting in front of road stations, in the road stations
 * and if a connection has any vehicles at all.
 * @param stationLocation The station to check out.
 * @param connection The connection this station is part of.
 * @return A tuple containing: 
 * - The number of vehicles waiting in or in front of the station multiplied by -1.
 * - The number of vehicles which are waiting and in the road station or depot; this > -nrVehicles.
 * - A boolean which denotes if any vehicles are detected for this connection.
 */
function VehiclesAdvisor::GetVehiclesWaiting(stationLocation, connection) {

		local nrVehicles = 0;
		local nrVehiclesInStation = 0;
		local hasVehicles = false;
		local isAir = false;
		local isRail = false;

		// Check if there are any vehicles waiting on this tile.
		foreach (vehicleID, value in AIVehicleList_Group(connection.vehicleGroupID)) {
			hasVehicles = true;

			if (!isAir && AIVehicle.GetVehicleType(vehicleID) == AIVehicle.VT_AIR)
				isAir = true;
					
			if (!isRail && AIVehicle.GetVehicleType(vehicleID) == AIVehicle.VT_RAIL)
				isRail = true;

			if (AIMap().DistanceManhattan(AIVehicle().GetLocation(vehicleID), stationLocation) > 0 && 
				(AIMap().DistanceManhattan(AIVehicle().GetLocation(vehicleID), stationLocation) < (isAir ? 30 : 7) || isRail) &&
				(AIVehicle().GetCurrentSpeed(vehicleID) < 10 || isAir) &&
				(AIVehicle.GetState(vehicleID) == AIVehicle.VS_RUNNING || AIVehicle.GetState(vehicleID) == AIVehicle.VS_BROKEN) &&
				AIOrder().GetOrderDestination(vehicleID, AIOrder.ORDER_CURRENT) == stationLocation) {

				nrVehicles--;
					
				if (AITile.IsStationTile(AIVehicle.GetLocation(vehicleID)))
					nrVehiclesInStation++;
			}
		}
		Log.logDebug("Vehicles waiting: " + nrVehicles + ", " + nrVehiclesInStation);
		return [nrVehicles, nrVehiclesInStation, hasVehicles];
}

function VehiclesAdvisor::Update(loopCounter) {
	Log.logInfo("Evaluate existing connections.");
	reports = [];

	foreach (connection in connectionManager.allConnections) {

		// If the road isn't build we can't micro manage, move on!
		if (!connection.pathInfo.build) {
			assert (false);
			continue;
		}

		// Make sure we don't update a connection to often!
		local currentDate = AIDate.GetCurrentDate();
		if (Date().GetDaysBetween(connection.lastChecked, currentDate) < 30) {
			continue;
		}
		
		local connectionString = connection.ToString();
		Log.logDebug("Check connection: " + connectionString);

		connection.lastChecked = currentDate;
		local report = connection.CompileReport(connection.vehicleTypes);
		if ((report == null) || (report.isInvalid)) {
			//Log.logWarning("Invalid report for connection " + connection.ToString());
			continue;
		}
		local reportedVehiclesNeeded = report.nrVehicles;
		report.nrVehicles = 0;
		
		local stationDetails = GetVehiclesWaiting(AIStation.GetLocation(connection.pathInfo.travelFromNodeStationID), connection);
		report.nrVehicles = stationDetails[0];
		local nrVehiclesInStation = stationDetails[1];
		local hasVehicles = stationDetails[2];

		local stationOtherDetails = GetVehiclesWaiting(AIStation.GetLocation(connection.pathInfo.travelToNodeStationID), connection);
		local dropoffOverload = false;
			
		// If the other station has more vehicles, check that station.
		if (stationOtherDetails[0] < report.nrVehicles) {
			report.nrVehicles = stationOtherDetails[0];
			nrVehiclesInStation = stationOtherDetails[1];
			hasVehicles = stationOtherDetails[2];
			if (!connection.bilateralConnection)
				dropoffOverload = true;
		}

		// Now we check whether we need more vehicles
		local production = AIStation.GetCargoWaiting(connection.pathInfo.travelFromNodeStationID, connection.cargoID);
		local rating = AIStation.GetCargoRating(connection.pathInfo.travelFromNodeStationID, connection.cargoID);
		
		// Check if the connection is actually being served by any vehicles.
		local nrVehicles = connection.GetNumberOfVehicles();

		if (connection.bilateralConnection) {
			local productionOtherEnd = AIStation.GetCargoWaiting(connection.pathInfo.travelToNodeStationID, connection.cargoID);
			local ratingOtherEnd = AIStation.GetCargoRating(connection.pathInfo.travelToNodeStationID, connection.cargoID);

			if (productionOtherEnd < production)
				production = productionOtherEnd;
			if (ratingOtherEnd > rating)
				rating = ratingOtherEnd;
		}
		
		// If we want to sell 1 aircraft or ship: don't. We allow for a little slack in airlines :).
		local isAir = AIEngine.GetVehicleType(report.transportEngineID) == AIVehicle.VT_AIR;
		local isShip = AIEngine.GetVehicleType(report.transportEngineID) == AIVehicle.VT_WATER;
		local isTrain = AIEngine.GetVehicleType(report.transportEngineID) == AIVehicle.VT_RAIL;
		local isRoad = AIEngine.GetVehicleType(report.transportEngineID) == AIVehicle.VT_ROAD;
	
		// If we have multiple stations we want to take this into account. Each station
		// is allowed to have 1 vehicle waiting in them. So we subtract the number of
		// road stations from the number of vehicles waiting.
		report.nrVehicles += connection.pathInfo.nrRoadStations;

		if (report.nrVehicles > 0)
			report.nrVehicles = 0;
		
		Log.logDebug("Rating = " + rating + ", production = " + production + ", vehicle count = " + nrVehicles);

		/// @todo I'm not sure if limiting rating to less than 60 here is usefull.
		if (!hasVehicles || rating < 60 || production > 100 || nrVehicles == 0) {

			// We only want to buy new vehicles if the producion is at least twice the amount of
			// cargo a vehicle can carry.
			if (nrVehicles > 0 && AIEngine.GetCapacity(report.holdingEngineID) * ( isTrain ? 6 : 1.5 ) > production && rating > 35)
				continue;

			// If we have a line of vehicles waiting we also want to buy another station to spread the load.
			if (report.nrVehicles < 0) {
				// We don't build an extra airport if more aircrafts are needed!
				if (isAir || isTrain)
					continue;
				report.nrRoadStations = 2;
			}

			if (nrVehicles == 0) {
				// Only add vehicles if it's a new connection or still has a reasonable production.
				if (Date.GetDaysBetween(AIDate.GetCurrentDate(), connection.pathInfo.buildDate) < 300 || production > 100)
					report.nrVehicles = 1;
				else
					report.nrVehicles = 0;
			}
			else if (production < 200 || isTrain || isAir || isShip || nrVehicles == 0) 
				report.nrVehicles = 1;
			else if (production < 300)
				report.nrVehicles = 2;
			else if (production < 400)
				report.nrVehicles = 3;
			else
				report.nrVehicles = 4;
		} 
		
		// If we want to sell vehicle but the road isn't old enough, don't!
		else if (report.nrVehicles < 0 && (Date.GetDaysBetween(AIDate.GetCurrentDate(), connection.pathInfo.buildDate) < 100 || dropoffOverload))
			continue;

		// If this connection has just one vehicle make sure it is profitable otherwise remove it.
		// High rating means we probably are waiting too long to get filled. Low production means we are probably not getting a lot of cargo at any time.
		else if (nrVehicles == 1 && rating > 70 && production < 10 && reportedVehiclesNeeded < -10 && Date.GetDaysBetween(AIDate.GetCurrentDate(), connection.pathInfo.buildDate) > 1000) {
			Log.logDebug("The only vehicle on this route is performing bad.");
			report.nrVehicles = -1; // Remove the last vehicle.
		}

		// If we want to build vehicles make sure we can actually build them!
		if (report.nrVehicles > 0) {
			if (!GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(report.transportEngineID)))
				continue;
			// Don't add any vehicles if the actual earnings are a lot lower than we expected.
			else if (connection.expectedAvgEarnings != null && connection.actualAvgEarnings != null &&
				connection.actualAvgEarnings * 3 < connection.expectedAvgEarnings) {
				// If earnings are negative and this is not a new connection then even decrease the amount of vehicles until we have 1 left.
				if (connection.actualAvgEarnings < 0 && nrVehicles > 1 && Date.GetDaysBetween(AIDate.GetCurrentDate(), connection.pathInfo.buildDate) > 1000) {
					Log.logDebug("Decreasing number of vehicles since we have negative earnings.");
					report.nrVehicles = -1;
				}
				else {
					Log.logDebug("Not adding vehicles since the average earnings are a lot worse than expected earnings.");
					continue;
				}
			}
			// Make sure we don't build more vehicles than the line can handle. Except for road and water vehicles since we currently don't compute maxVehicles there.
			else if (!isRoad && !isShip && report.nrVehicles + nrVehicles > report.maxVehicles) {
				local wanted = report.nrVehicles;
				report.nrVehicles = report.maxVehicles - nrVehicles;
				Log.logDebug("Reduced vehicles to add from " + wanted + " to " + report.nrVehicles + " since it was more than this route can handle.");
			}
		}

		if (report.nrVehicles != 0) {
			if (report.nrVehicles > 0)
				Log.logInfo("We advise to add " + report.nrVehicles + " vehicles to connection " + connectionString);
			else
				Log.logInfo("We advise to sell " + (-report.nrVehicles) + " vehicles of connection " + connectionString);
			reports.push(report);
		}
		else if (nrVehicles == 0) {
			// If the connection doesn't have vehicles and we don't want to add any the push the report.
			// That way we can decide to remove the whole connection in GetReports().
			Log.logInfo("We advise to remove the connection " + connectionString);
			reports.push(report);
		}
		else if (report.upgradeToRailType != null) {
			Log.logInfo("We advise to upgrade the rails of connection " + connectionString);
			reports.push(report);
		}
		else
			Log.logDebug("No changes needed.");
	}
	Log.logInfo("Done evaluating existing connections. We added " + reports.len() + " reports.");
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function VehiclesAdvisor::GetReports() {
	local reportsToReturn = [];
	local report;
	
	Log.logDebug("VehiclesAdvisor: Get " + reports.len() + " reports.");
	
	foreach (report in reports) {
	
		// The industryConnectionNode gives us the actual connection.
		local connection = report.connection.travelFromNode.GetConnection(report.connection.travelToNode, report.connection.cargoID);
		
		// If the connection was termintated in the mean time, drop the report.
		if (!connection.pathInfo.build) {
			Log.logWarning("Connection wasn't built!");
			continue;
		}
		
		Log.logDebug("Report an update from: " + report.ToString());
		local actionList = [];
						
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();

		// Check if we need to build more road stations. This is necessary if
		// we detect large jams before either the drop-off or pick-up places
		// or if we want to introduce an articulated vehicle whils using 'normal'
		// stations and not drive-through stations.
		if (report.nrRoadStations > 1 ||
			connection.vehicleTypes == AIVehicle.VT_ROAD &&
			!connection.pathInfo.refittedForArticulatedVehicles &&
			AIEngine.IsArticulated(report.transportEngineID)) {
			
			if (connection.vehicleTypes == AIVehicle.VT_ROAD)
				actionList.push(BuildRoadAction(report.connection, false, true));

			// Don't build extra airfields (yet).
			else if (connection.vehicleTypes == AIVehicle.VT_AIR)
				continue;
		}
		
		// Buy only half of the vehicles needed, build the rest gradualy.
		if (report.nrVehicles > 0)  {

			// If we want to buy aircrafts, make sure the airports are of the correct type!
			// Big airplanes have a 5% chance to crash, so we want to avoid that! Also we
			// check if an extra airport can actually be build! If not we simple obmit building
			// more aircrafts. This will be handled better in the future.
			if (connection.vehicleTypes == AIVehicle.VT_AIR && 
				AIEngine.GetPlaneType(report.transportEngineID) == AIAirport.PT_BIG_PLANE &&
				(AIAirport.GetAirportType(connection.pathInfo.roadList[0].tile) == AIAirport.AT_SMALL ||
				AIAirport.GetAirportType(connection.pathInfo.roadList[0].tile) == AIAirport.AT_COMMUTER)) {
					
					// Check if there are still aircrafts serving this connection. If it is a small airfield
					// and we are not allowed to build new aircraft, we may as wel demolish it.
					if (AIVehicleList_Group(connection.vehicleGroupID).Count() == 0)
						connection.Demolish(true, true, true);
					
					continue;
				}

			vehicleAction.BuyVehicles(report.transportEngineID, report.nrVehicles, report.holdingEngineID, report.nrWagonsPerVehicle, connection);
		}
		else if(report.nrVehicles < 0)
			vehicleAction.SellVehicles(report.transportEngineID, -report.nrVehicles, connection);
		else // report.nrVehicles == 0: Remove the connection if there are no vehicles left.
			if (AIVehicleList_Group(connection.vehicleGroupID).Count() == 0) {
				connection.Demolish(true, true, true);
				continue;
			}

 		if (report.upgradeToRailType != null)
 			actionList.push(RailPathUpgradeAction(connection, report.upgradeToRailType));

		actionList.push(vehicleAction);

		report.actions = actionList;

		// Create a report and store it!
		reportsToReturn.push(report);
	}
	
	return reportsToReturn;
}

function VehiclesAdvisor::HaltPlanner() {
	local money = Finance.GetMaxMoneyToSpend();
	foreach (report in reports) {
		if (report.UtilityForMoney(money) > 0)
			return true;
	}
	return false;
} 
