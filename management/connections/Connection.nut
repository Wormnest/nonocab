/**
 * A connection is a link between two nodes (industries or towns) and holds all information that is
 * relevant to maintain / build such a connection. Connection are build up from ConnectionNodes. 
 * Because multiple advisors can reason over connection and create reports for them, we store the
 * best report produced by an advisor in the bestReport variable which can only be overwritten if
 * it becomes invalidated (i.e. it can't be build) or an advisor comes with a better report.
 */
class Connection {

	// Type of connection.
	static INDUSTRY_TO_INDUSTRY = 1;
	static INDUSTRY_TO_TOWN = 2;
	static TOWN_TO_TOWN = 3;
	static TOWN_TO_SELF = 4;
	
	// Vehicle types in this connection.
	vehicleTypes = null;
	
	lastChecked = null;             // The latest date this connection was inspected.
	connectionType = null;          // The type of connection (one of above).
	cargoID = null;	                // The type of cargo carried from one node to another.
	travelFromNode = null;          // The node the cargo is carried from.
	travelToNode = null;            // The node the cargo is carried to.
	vehicleGroupID = null;            // The AIGroup of all vehicles serving this connection.
	timeToTravelFrom = null;        // List containing the travel times for various enigneIDs.
	timeToTravelTo = null;        // List containing the travel times for various enigneIDs.
	pathInfo = null;                // PathInfo class which contains all information about the path.
	bilateralConnection = null;     // If this is true, cargo is carried in both directions.
	travelFromNodeStationID = null; // The station ID which is build at the producing side.
	travelToNodeStationID = null;   // The station ID which is build at the accepting side.
	connectionManager = null;       // Updates are send to all listeners when connection is realised, demolished or updated.

	forceReplan = null;		// Force this connection to be replanned.
	refittedForArticulatedVehicles = null; // It this connection able to support articulated vehicles?
	
	constructor(cargo_id, travel_from_node, travel_to_node, path_info, connection_manager) {
		cargoID = cargo_id;
		travelFromNode = travel_from_node;
		travelToNode = travel_to_node;
		pathInfo = path_info;
		connectionManager = connection_manager;
		forceReplan = false;
		bilateralConnection = travel_from_node.GetProduction(cargo_id) != -1 && travel_to_node.GetProduction(cargo_id) != -1;
		refittedForArticulatedVehicles = false;
		travelFromNodeStationID = null;
		travelToNodeStationID = null;
		
		timeToTravelFrom = {};
		timeToTravelTo = {};
		
		if (travelFromNode.nodeType == ConnectionNode.INDUSTRY_NODE) {
			if (travelToNode.nodeType == ConnectionNode.INDUSTRY_NODE) {
				connectionType = INDUSTRY_TO_INDUSTRY;
			} else {
				connectionType = INDUSTRY_TO_TOWN;
			}
		}
		else {
			if(travelFromNode == travelToNode) {
				connectionType = TOWN_TO_SELF;	
			}
			else{
				connectionType = TOWN_TO_TOWN;
			}
		}
		vehicleGroupID = -1;
	}
	
	function LoadData(data) {
		pathInfo = PathInfo(null, null, null, null);
		vehicleTypes = data["vehicleTypes"];
		refittedForArticulatedVehicles = data["refittedForArticulatedVehicles"];
		pathInfo.LoadData(data["pathInfo"]);
		vehicleGroupID = data["vehicleGroupID"];
		
		UpdateAfterBuild(vehicleTypes, pathInfo.roadList[pathInfo.roadList.len() - 1].tile, pathInfo.roadList[0].tile, AIStation.GetCoverageRadius(AIStation.GetStationID(pathInfo.roadList[0].tile)));
	}
	
	function SaveData() {
		local saveData = {};
		saveData["cargoID"] <- cargoID;
		saveData["travelFromNode"] <- travelFromNode.GetUID(cargoID);
		saveData["travelToNode"] <- travelToNode.GetUID(cargoID);
		saveData["vehicleTypes"] <- vehicleTypes;
		saveData["refittedForArticulatedVehicles"] <- refittedForArticulatedVehicles;
		saveData["pathInfo"] <- pathInfo.SaveData();
		saveData["vehicleGroupID"] <- vehicleGroupID;
		return saveData;
	}
	
	/**
	 * Based on this connection get a report which tells how many vehicles
	 * of type engineID are supported on top of the already existing fleet of
	 * vehicles.
	 * @param world The world.
	 * @param transportingEngineID The engine id to build which will transport the cargo.
	 * @param holdingEngineID The engine id to build which will hold the cargo to transport.
	 * @return A Report instance.
	 */
	function CompileReport(world, transportingEngineID, holdingEngineID) {
		// First we check how much we already transport.
		// Check if we already have vehicles who transport this cargo and deduce it from 
		// the number of vehicles we need to build.
		local cargoAlreadyTransported = 0;
		foreach (connection in travelFromNode.connections) {
			if (connection.cargoID == cargoID) {
				
				if (AIGroup.IsValidGroup(vehicleGroupID)) {
					local vehicles = AIVehicleList_Group(vehicleGroupID);
					foreach (vehicle, value in vehicles) {
						local engineID = AIVehicle.GetEngineType(vehicle);
						local travelTime = timeToTravelTo.rawget(engineID) + timeToTravelFrom.rawget(engineID);
						cargoAlreadyTransported += (World.DAYS_PER_MONTH / travelTime) * AIVehicle.GetCapacity(vehicle, cargoID);
					}
				}
			}
		}
		
		return Report(world, travelFromNode, travelToNode, cargoID, transportingEngineID, holdingEngineID, cargoAlreadyTransported);
	}
	
	/**
	 * If the connection is build this function is called to update its
	 * internal state.
	 */
	function UpdateAfterBuild(vehicleType, fromTile, toTile, stationCoverageRadius) {
		pathInfo.build = true;
		pathInfo.nrRoadStations = 1;
		pathInfo.buildDate = AIDate.GetCurrentDate();
		lastChecked = AIDate.GetCurrentDate();
		vehicleTypes = vehicleType;
		travelFromNodeStationID = AIStation.GetStationID(fromTile);
		travelToNodeStationID = AIStation.GetStationID(toTile);
		forceReplan = false;

		// In the case of a bilateral connection we want to make sure that
		// we don't hinder ourselves; Place the stations not to near each
		// other.
		if (bilateralConnection && connectionType == TOWN_TO_TOWN) {
			travelFromNode.AddExcludeTiles(cargoID, fromTile, stationCoverageRadius);
			travelToNode.AddExcludeTiles(cargoID, toTile, stationCoverageRadius);
		}
		
		travelFromNode.activeConnections.push(this);
		travelToNode.reverseActiveConnections.push(this);
		
		connectionManager.ConnectionRealised(this);
	}
	
	/**
	 * Get the number of vehicles operating.
	 */
	function GetNumberOfVehicles() {

		if (!AIGroup.IsValidGroup(vehicleGroupID))
			return 0;
		return AIVehicleList_Group(vehicleGroupID).Count();
	}
	
	/**
	 * Destroy this connection.
	 */
	function Demolish(destroyFrom, destroyTo, destroyDepots) {
		if (!pathInfo.build)
			assert(false);
		
		// Sell all vehicles.
		if (!AIGroup.IsValidGroup(vehicleGroupID)) {
			foreach (vehicleID, value in AIVehicleList_Group(vehicleGroupID)) {	
				if (!AIVehicle.SendVehicleToDepot(vehicleID)) {
					AIVehicle.ReverseVehicle(vehicleID);
					AIController.Sleep(5);
					AIVehicle.SendVehicleToDepot(vehicleID);
		    	}
			}
		}
		
/*		if (destroyFrom) {
			if (vehicleTypes == AIVehicle.VT_ROAD) {
				local startTileList = AITileList();
				local startStation = pathInfo.roadList[pathInfo.roadList.len() - 1].tile;
				
				startTileList.AddTile(startStation);
				DemolishStations(startTileList, AIStation.GetName(AIStation.GetStationID(startStation)), AIList());
			}
			AITile.DemolishTile(pathInfo.roadList[pathInfo.roadList.len() - 1].tile);
		}
		
		if (destroyTo) {
			if (vehicleTypes == AIVehicle.VT_ROAD) {
				local endTileList = AITileList();
				local endStation = pathInfo.roadList[0].tile;
				
				endTileList.AddTile(endStation);
				DemolishStations(endTileList, AIStation.GetName(AIStation.GetStationID(endStation)), AIList());
			}
			AITile.DemolishTile(pathInfo.roadList[0].tile);
		}
		
		if (destroyDepots) {
			AITile.DemolishTile(pathInfo.depot);
			if (bilateralConnection)
				AITile.DemolishTile(pathInfo.depotOtherEnd);
		}
		
		for (local i = 0; i < travelFromNode.activeConnections.len(); i++) {
			if (travelFromNode.activeConnections[i] == this) {
				travelFromNode.activeConnections.remove(i);
				break;
			}
		}
		
		for (local i = 0; i < travelToNode.reverseActiveConnections.len(); i++) {
			if (travelToNode.reverseActiveConnections[i] == this) {
				travelToNode.reverseActiveConnections.remove(i);
				break;
			}
		}
		*/
		
		
		connectionManager.ConnectionDemolished(this);
	}
	
	/**
	 * Utility function to destroy all road stations which are related.
	 * @param tileList A list of tiles which must be removed.
	 * @param stationName The name of stations to be removed.
	 * @param excludeList A list of stations already explored.
	 */
	function DemolishStations(tileList, stationName, excludeList) {
		if (tileList.Count() == 0)
			return;
 
 		local newTileList = AITileList();
 		local tile = tileList.Begin();
 		while (true) {
 			local currentStationID = AIStation.GetStationID(tile);
			foreach (surroundingTile in Tile.GetTilesAround(tile, true)) {
				if (excludeList.HasItem(surroundingTile)) continue;
				excludeList.AddTile(surroundingTile);
	
				local stationID = AIStation.GetStationID(surroundingTile);
	
				if (AIStation.IsValidStation(stationID)) {

					// Only explore this possibility if the station has the same name!
					if (AIStation.GetName(stationID) != stationName)
						continue;
					AITile.DemolishTile(surroundingTile);
					
					if (!newTileList.HasItem(surroundingTile))
						newTileList.AddTile(surroundingTile);
				}			
			}
			
			DemolishStations(newTileList, stationName, excludeList);
			
			tile = null;
			while (tileList.HasNext()) {
				tile = tileList.Next();
				if (!excludeList.HasItem(tile))
					break;
			}
			if (tile == null)
				return;
 		}
	}
	
	
	// Everything below this line is just a toy implementation designed to test :)
	function GetLocationsForNewStation(atStart) {
		if (!pathInfo.build)
			return AIList();
	
		local tileList = AITileList();	
		local excludeList = AITileList();	
		local tile = null;
		if (atStart) {
			tile = pathInfo.roadList[0].tile;
		} else {
			tile = pathInfo.roadList[pathInfo.roadList.len() - 1].tile;
		}
		excludeList.AddTile(tile);
		GetSurroundingTiles(tile, tileList, excludeList);
		
		return tileList;
	}
	
	function GetSurroundingTiles(tile, tileList, excludeList) {

		local currentStationID = AIStation.GetStationID(tile);
		foreach (surroundingTile in Tile.GetTilesAround(tile, true)) {
			if (excludeList.HasItem(surroundingTile)) continue;

			local stationID = AIStation.GetStationID(surroundingTile);

			if (AIStation.IsValidStation(stationID)) {
				excludeList.AddTile(surroundingTile);

				// Only explore this possibility if the station has the same name!
				if (AIStation.GetName(stationID) != AIStation.GetName(currentStationID))
					continue;

				GetSurroundingTiles(surroundingTile, tileList, excludeList);
				continue;
			}

			if (!tileList.HasItem(surroundingTile))
				tileList.AddTile(surroundingTile);
		}
	}
	
	function GetUID() {
		return travelFromNode.GetUID(cargoID);
	}
}
