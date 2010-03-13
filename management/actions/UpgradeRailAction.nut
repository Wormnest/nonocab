class RailPathUpgradeAction extends Action {

	connection = 0;     // The connection to upgrade.
	railType = 0;       // The rail type to upgrade to.

	constructor(connectionToUpgrade, upgradeToRailType) {
		connection = connectionToUpgrade;
		railType = upgradeToRailType;
	}
	
	function Execute();

	function Upgrade(connection, newRailType);

	function GetCostForUpgrade(connection, newRailType);
}

function RailPathUpgradeAction::Execute() {
	local accounter = AIAccounting();
	Log.logWarning("STARTING UPGRADE!!! " + railType);
	local exec = AIExecMode();
	Upgrade(connection, railType);
	totalCosts = accounter.GetCosts();
	return true;
}

function RailPathUpgradeAction::GetCostForUpgrade(connection, newRailType) {
	local accounter = AIAccounting();
	local test = AITestMode();
	RailPathUpgradeAction(connection, newRailType);
	return accounter.GetCosts();
}

function RailPathUpgradeAction::Upgrade(connection, newRailType) {
	
	// Get all the connections which must be upgraded with this connection.
	local allConnectionsToUpgrade = connection.connectionManager.GetInterconnectedConnections(connection);
	if (allConnectionsToUpgrade == null)
		allConnectionsToUpgrade = [];
	
	allConnectionsToUpgrade.push(connection);
	
	UpgradeAll(allConnectionsToUpgrade, newRailType);
}

function RailPathUpgradeAction::UpgradeAll(connections, newRailType) {

	Log.logWarning("Upgrade " + connections.len() + " connections!");

	// First order of business is to send every vehicle back to the depots
	// so they don't get in the way while we upgrade the tracks!
	local vehicleIsNotInDepot = true;

	// First send all vehicles to their depots.
	foreach (connection in connections) {
		foreach (vehicleId, value in AIVehicleList_Group(connection.vehicleGroupID)) {
			while (!AIVehicle.SendVehicleToDepot(vehicleId));
		}
	}

	// Next, wait till all vehicles are in their respective depots.
	while (vehicleIsNotInDepot) {
		vehicleIsNotInDepot = false;
		foreach (connection in connections) {
	
			foreach (vehicleId, value in AIVehicleList_Group(connection.vehicleGroupID)) {
				if (!AIVehicle.IsStoppedInDepot(vehicleId)) {
					vehicleIsNotInDepot = true;
				}
			}
		}
	}
	
	foreach (connection in connections) {
		// Jeej! All trains are in the depots. SELL THEM!!!!
		foreach (vehicleId, value in AIVehicleList_Group(connection.vehicleGroupID))
				AIVehicle.SellVehicle(vehicleId);
	
		// Convert the depots.
		AIRail.ConvertRailType(connection.pathInfo.depot, connection.pathInfo.depot, newRailType);
		if (connection.pathInfo.depotOtherEnd)
			AIRail.ConvertRailType(connection.pathInfo.depotOtherEnd, connection.pathInfo.depotOtherEnd, newRailType);
		
		// Convert the rail types.
		if (connection.pathInfo.roadList) {
			Log.logWarning("We have a roadlist!");
			foreach (at in connection.pathInfo.roadList) {
				AIRail.ConvertRailType(at.tile, at.tile, newRailType);
			}
		}
		
		if (connection.pathInfo.roadListReturn) {
			Log.logWarning("We have a roadListReturn!");
			foreach (at in connection.pathInfo.roadListReturn) {
				AIRail.ConvertRailType(at.tile, at.tile, newRailType);
			}
		}
		
		if (connection.pathInfo.extraRoadBits) {
			Log.logWarning("We have a extraRoadBits!");
			foreach (extraArray in connection.pathInfo.extraRoadBits) {
				foreach (at in extraArray) {
					AIRail.ConvertRailType(at.tile, at.tile, newRailType);
				}
			}
		}
	
		// Convert the stations too!
		assert (AIStation.IsValidStation(connection.travelFromNodeStationID));
		assert (AIStation.IsValidStation(connection.travelToNodeStationID));
		local beginStationTiles = AITileList_StationType(connection.travelFromNodeStationID, AIStation.STATION_TRAIN);
		local endStationTiles = AITileList_StationType(connection.travelToNodeStationID, AIStation.STATION_TRAIN);
		foreach (tile, value in beginStationTiles)
			AIRail.ConvertRailType(tile, tile, newRailType);
		foreach (tile, value in endStationTiles)
			AIRail.ConvertRailType(tile, tile, newRailType);
	}
}
