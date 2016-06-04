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
	Log.logWarning("Starting rail upgrade to " + AIRail.GetName(railType));
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
		allConnectionsToUpgrade = [connection];
	
	//allConnectionsToUpgrade.push(connection);
	
	UpgradeAll(allConnectionsToUpgrade, newRailType);
}

function RailPathUpgradeAction::UpgradeAll(connections, newRailType) {

	Log.logWarning("Upgrade " + connections.len() + " connections!");
	AIRail.SetCurrentRailType(newRailType);
	
	// Check if we need to send the trains back to their depots or if we can update
	// the rails in place.
	local canUpdateInPlace = true;
	foreach (connection in connections) {
		foreach (vehicleId, value in AIVehicleList_Group(connection.vehicleGroupID)) {
			local engineId = AIVehicle.GetEngineType(vehicleId);
			if (!AIEngine.CanRunOnRail(engineId, newRailType) ||
			    !AIEngine.HasPowerOnRail(engineId, newRailType)) {
			    	canUpdateInPlace = false;
			    	break;
			}
		}
	}


	// First order of business is to send every vehicle back to the depots
	// so they don't get in the way while we upgrade the tracks!
	if (!canUpdateInPlace) {
		local vehicleIsNotInDepot = true;
	
		// Send and wait till all vehicles are in their respective depots.
		while (vehicleIsNotInDepot) {
			vehicleIsNotInDepot = false;
			foreach (connection in connections) {

				// Save option as we do not remove connections from the interconnected list once they are removed.
				if (!connection.pathInfo.build || connection.vehicleTypes != AIVehicle.VT_RAIL)
					continue;
		
				foreach (vehicleId, value in AIVehicleList_Group(connection.vehicleGroupID)) {
					if (!AIVehicle.IsStoppedInDepot(vehicleId)) {
						vehicleIsNotInDepot = true;
						
						// Check if the vehicles is actually going to the depot!
						if ((AIOrder.GetOrderFlags(vehicleId, AIOrder.ORDER_CURRENT) & AIOrder.OF_STOP_IN_DEPOT) == 0)
							AIVehicle.SendVehicleToDepot(vehicleId);
					}
				}
			}
		}
		
		foreach (connection in connections) {
			if (!connection.pathInfo.build || connection.vehicleTypes != AIVehicle.VT_RAIL)
				continue;
			// Jeej! All trains are in the depots. SELL THEM!!!!
			foreach (vehicleId, value in AIVehicleList_Group(connection.vehicleGroupID))
				AIVehicle.SellVehicle(vehicleId);
		}
	}
	
	foreach (connection in connections) {
		if (!connection.pathInfo.build || connection.vehicleTypes != AIVehicle.VT_RAIL)
			continue;

		// Convert the rail types.
		if (connection.pathInfo.roadList) {
			Log.logWarning("We have a roadlist!");
			foreach (at in connection.pathInfo.roadList)
				UpgradeTile(at.tile, newRailType);
		}
		
		if (connection.pathInfo.roadListReturn) {
			Log.logWarning("We have a roadListReturn!");
			foreach (at in connection.pathInfo.roadListReturn)
				UpgradeTile(at.tile, newRailType);
		}
		
		if (connection.pathInfo.extraRoadBits) {
			Log.logWarning("We have a extraRoadBits!");
			foreach (extraArray in connection.pathInfo.extraRoadBits)
				foreach (at in extraArray)
					UpgradeTile(at.tile, newRailType);
		}
	
		// Convert the stations too!
		assert (AIStation.IsValidStation(connection.pathInfo.travelFromNodeStationID));
		assert (AIStation.IsValidStation(connection.pathInfo.travelToNodeStationID));
		local beginStationTiles = AITileList_StationType(connection.pathInfo.travelFromNodeStationID, AIStation.STATION_TRAIN);
		local endStationTiles = AITileList_StationType(connection.pathInfo.travelToNodeStationID, AIStation.STATION_TRAIN);
		foreach (tile, value in beginStationTiles)
			AIRail.ConvertRailType(tile, tile, newRailType);
		foreach (tile, value in endStationTiles)
			AIRail.ConvertRailType(tile, tile, newRailType);
			
		// Convert the depots.
		AIRail.ConvertRailType(connection.pathInfo.depot, connection.pathInfo.depot, newRailType);
		if (connection.pathInfo.depotOtherEnd)
			AIRail.ConvertRailType(connection.pathInfo.depotOtherEnd, connection.pathInfo.depotOtherEnd, newRailType);
	}
}

function RailPathUpgradeAction::UpgradeTile(tile, newRailType) {
	if (AIBridge.IsBridgeTile(tile))
		UpgradeBridge(tile, newRailType);
	else
		// @todo: Is there a possibility of an infinite loop here? Maybe add a max loops counter?
		// OTOH We don't want a piece of old rail left leaving the route unusable.
		while (AIRail.GetRailType(tile) != newRailType)
			AIRail.ConvertRailType(tile, tile, newRailType);
}

function RailPathUpgradeAction::UpgradeBridge(bridgeTile, newRailType) {
	local bridgeOtherEnd = AIBridge.GetOtherBridgeEnd(bridgeTile);
	local mapSizeX = AIMap.GetMapSizeX();
	local length = bridgeTile - bridgeOtherEnd;

	
	if (length < -mapSizeX || length > mapSizeX)
		length /= mapSizeX;
	
	if (length < 0)
		length = -length;

	local bridgeTypes = AIBridgeList_Length(length + 1);
	local bestBridgeType = null;
	foreach (bridge, value in bridgeTypes) {
		if (bestBridgeType == null || AIBridge.GetMaxSpeed(bridge) >= AIBridge.GetMaxSpeed(bestBridgeType))
			bestBridgeType = bridge;
	}
	
	local ex = AIExecMode();
	if (bestBridgeType != null) {
		while (!AITile.DemolishTile(bridgeTile));
		while (!AIBridge.BuildBridge(AIVehicle.VT_RAIL, bestBridgeType, bridgeTile, bridgeOtherEnd));
	} else {
		AIRail.ConvertRailType(bridgeTile, bridgeTile, newRailType);
	}
}
