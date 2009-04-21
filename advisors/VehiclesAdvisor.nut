/**
 * This class is responsible of maintaining already build connections by
 * advising to sell or buy vehicles.
 */
class VehiclesAdvisor extends Advisor { //, ConnectionListener

	connections = null;					// The table of connections to manage.
	reports = null;
	
	constructor(world) {
		Advisor.constructor(world);
		connections = [];
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

		// Check if there are any vehicles waiting on this tile and if so, sell them!
		foreach (vehicleGroup in connection.vehiclesOperating) {
			foreach (vehicleID in vehicleGroup.vehicleIDs) {
				hasVehicles = true;

				if (!isAir && AIVehicle.GetVehicleType(vehicleID) == AIVehicle.VT_AIR)
					isAir = true;

				if (AIMap().DistanceManhattan(AIVehicle().GetLocation(vehicleID), stationLocation) > 0 && 
					AIMap().DistanceManhattan(AIVehicle().GetLocation(vehicleID), stationLocation) < (isAir ? 30 : 7) &&
					(AIVehicle().GetCurrentSpeed(vehicleID) < 10 || isAir) &&
					(AIVehicle.GetState(vehicleID) == AIVehicle.VS_RUNNING ||
					AIVehicle.GetState(vehicleID) == AIVehicle.VS_BROKEN) &&
					AIOrder().GetOrderDestination(vehicleID, AIOrder.ORDER_CURRENT) == stationLocation) {

					nrVehicles--;
					
					if (AITile.IsStationTile(AIVehicle.GetLocation(vehicleID)))
						nrVehiclesInStation++;
				}
			}
		}

		return [nrVehicles, nrVehiclesInStation, hasVehicles];
}

function VehiclesAdvisor::Update(loopCounter) {
	
	reports = [];

	foreach (connection in connections) {

		// If the road isn't build we can't micro manage, move on!
		if (!connection.pathInfo.build) {
			Log.logWarning(connection.travelToNode.GetName());
			Log.logWarning(connection.travelFromNode.GetName());
			assert(false);
		}

		// Make sure we don't update a connection to often!
		local currentDate = AIDate.GetCurrentDate();
		if (Date().GetDaysBetween(connection.lastChecked, currentDate) < 15)
			continue;
		
		connection.lastChecked = currentDate;
		local report = connection.CompileReport(world, world.cargoTransportEngineIds[connection.vehicleTypes][connection.cargoID]);
		report.nrVehicles = 0;
		
		local stationDetails = GetVehiclesWaiting(AIStation().GetLocation(connection.travelFromNodeStationID), connection);
		report.nrVehicles = stationDetails[0];
		local nrVehiclesInStation = stationDetails[1];
		local hasVehicles = stationDetails[2];

		local stationOtherDetails = GetVehiclesWaiting(AIStation().GetLocation(connection.travelToNodeStationID), connection);
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
		local production = AIStation.GetCargoWaiting(connection.travelFromNodeStationID, connection.cargoID);
		local rating = AIStation().GetCargoRating(connection.travelFromNodeStationID, connection.cargoID);
		
		// Check if the connection is actually being served by any vehiles.
		local nrVehicles = connection.GetNumberOfVehicles();

		if (connection.bilateralConnection) {
			local productionOtherEnd = AIStation.GetCargoWaiting(connection.travelToNodeStationID, connection.cargoID);
			local ratingOtherEnd = AIStation().GetCargoRating(connection.travelToNodeStationID, connection.cargoID);

			if (productionOtherEnd < production)
				production = productionOtherEnd;
			if (ratingOtherEnd > rating)
				rating = ratingOtherEnd;
		}
		
		// If we want to sell 1 aircraft or ship: don't. We allow for a little slack in airlines :).
		local isAir = AIEngine.GetVehicleType(report.engineID) == AIVehicle.VT_AIR;
		local isShip = AIEngine.GetVehicleType(report.engineID) == AIVehicle.VT_WATER;

		Log.logWarning(report.nrVehicles);
			
		// If we have multiple stations we want to take this into account. Each station
		// is allowed to have 1 vehicle waiting in them. So we subtract the number of
		// road stations from the number of vehicles waiting.
		report.nrVehicles += connection.pathInfo.nrRoadStations;

		if (report.nrVehicles > 0)
			report.nrVehicles = 0;

		if (!hasVehicles || rating < 60 || production > 100 || nrVehicles == 0) {

			// We only want to buy new vehicles if the producion is at least twice the amount of
			// cargo a vehicle can carry.
			if (nrVehicles > 0 && AIEngine.GetCapacity(report.engineID) * 1.5 > production && rating > 35)
				continue;

			// If we have a line of vehicles waiting we also want to buy another station to spread the load.
			if (report.nrVehicles < 0) {
				// We don't build an extra airport if more aircrafts are needed!
				if (isAir)
					continue;
				report.nrRoadStations = 2;
			}

			if (production < 200 || isAir || isShip || nrVehicles == 0) 
				report.nrVehicles = 1;
			else if (production < 300)
				report.nrVehicles = 2;
			else if (production < 400)
				report.nrVehicles = 3;
			else
				report.nrVehicles = 4;
		} 
		
		// If we want to sell vehicle but the road isn't old enough, don't!
		else if (report.nrVehicles < 0 && (Date.GetDaysBetween(AIDate.GetCurrentDate(), connection.pathInfo.buildDate) < 30 || dropoffOverload))
			continue;

		// If we want to build vehicles make sure we can actually build them!
		if (report.nrVehicles > 0 && !GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(report.engineID)))
			continue;

		if (report.nrVehicles != 0)
			reports.push(report);
	}
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function VehiclesAdvisor::GetReports() {
	
	local reportsToReturn = [];
	local report;
	
	foreach (report in reports) {
	
		// The industryConnectionNode gives us the actual connection.
		local connection = report.fromConnectionNode.GetConnection(report.toConnectionNode, report.cargoID);
		
		// If the connection was termintated in the mean time, drop the report.
		if (!connection.pathInfo.build)
			continue;
		
		Log.logDebug("Report an update from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName() + " with " + report.nrVehicles + " vehicles! Utility: " + report.Utility());
		local actionList = [];
						
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();

		if (report.nrRoadStations > 1) {
			if (connection.vehicleTypes == AIVehicle.VT_ROAD)
				actionList.push(BuildRoadAction(report.connection, false, true, world));

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
				AIEngine.GetPlaneType(report.engineID) == AIAirport.PT_BIG_PLANE &&
				(AIAirport.GetAirportType(connection.pathInfo.roadList[0].tile) == AIAirport.AT_SMALL ||
				AIAirport.GetAirportType(connection.pathInfo.roadList[0].tile) == AIAirport.AT_COMMUTER))
					continue;

			vehicleAction.BuyVehicles(report.engineID, report.nrVehicles, connection);
		}
		else if(report.nrVehicles < 0)
			vehicleAction.SellVehicles(report.engineID, -report.nrVehicles, connection);

		actionList.push(vehicleAction);

		report.actions = actionList;

		// Create a report and store it!
		reportsToReturn.push(report);
	}
	
	return reportsToReturn;
}

// Functions related to the interface ConnectionListener.
function VehiclesAdvisor::ConnectionRealised(connection) {
	connections.push(connection);
}

function VehiclesAdvisor::ConnectionDemolished(connection) {
	for (local i = 0; i < connections.len(); i++) {
		if (connections[i] == connection) {
			connections.remove(i);
			break;
		}
	}
}

function VehiclesAdvisor::HaltPlanner() {
	local money = Finance.GetMaxMoneyToSpend();
	foreach (report in reports) {
		if (report.UtilityForMoney(money) > 0)
			return true;
	}
	return false;
} 
