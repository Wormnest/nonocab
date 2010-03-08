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

//	AIRail.SetCurrentRailType(newRailType);

	// First order of business is to send every vehicle back to the depots
	// so they don't get in the way while we upgrade the tracks!
	foreach (vehicleGroup in connection.vehiclesOperating) {
		foreach (vehicleId in vehicleGroup.vehicleIDs) {
			AIVehicle.SendVehicleToDepot(vehicleId);
		}
	}
	
	// Next, wait till all vehicles are in their respective depots.
	local vehicleNotInDepot = true;
	while (vehicleNotInDepot) {
		vehicleNotInDepot = false;
		foreach (vehicleGroup in connection.vehiclesOperating) {
			foreach (vehicleId in vehicleGroup.vehicleIDs) {
				if (!AIVehicle.IsStoppedInDepot(vehicleId)) {
					vehicleNotInDepot = true;
					break;
				}
			}
			
			if (vehicleNotInDepot)
				break;
		}
	}
	
	// Jeej! All trains are in the depots. SELL THEM!!!!
	foreach (vehicleGroup in connection.vehiclesOperating) {
		foreach (vehicleId in vehicleGroup.vehicleIDs) {
			AIVehicle.SellVehicle(vehicleId);
		}
	}

	connection.vehiclesOperating = [];
	
	// Sell and rebuild the depots.
	local originalFrontBitDepot = AIRail.GetRailDepotFrontTile(connection.pathInfo.depot);
	AITile.DemolishTile(connection.pathInfo.depot);
	AIRail.BuildRailDepot(connection.pathInfo.depot, originalFrontBitDepot);
	if (connection.pathInfo.depotOtherEnd) {
		local originalFrontBitDepot = AIRail.GetRailDepotFrontTile(connection.pathInfo.depotOtherEnd);
		AITile.DemolishTile(connection.pathInfo.depotOtherEnd);
		AIRail.BuildRailDepot(connection.pathInfo.depotOtherEnd, originalFrontBitDepot);
	}
	
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
