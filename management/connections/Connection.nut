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
	vehiclesOperating = null;       // List of VehicleGroup instances to keep track of all vehicles on this connection.
	pathInfo = null;                // PathInfo class which contains all information about the path.
	bilateralConnection = null;     // If this is true, cargo is carried in both directions.
	travelFromNodeStationID = null; // The station ID which is build at the producing side.
	travelToNodeStationID = null;   // The station ID which is build at the accepting side.
	connectionManager = null;       // Updates are send to all listeners when connection is realised, demolished or updated.

	forceReplan = null;		// Force this connection to be replanned.
	
	constructor(cargo_id, travel_from_node, travel_to_node, path_info, connection_manager) {
		cargoID = cargo_id;
		travelFromNode = travel_from_node;
		travelToNode = travel_to_node;
		pathInfo = path_info;
		connectionManager = connection_manager;
		forceReplan = false;
		bilateralConnection = travel_from_node.GetProduction(cargo_id) != -1 && travel_to_node.GetProduction(cargo_id) != -1;
		
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
		vehiclesOperating = [];
	}
	
	/**
	 * Based on this connection get a report which tells how many vehicles
	 * of type engineID are supported on top of the already existing fleet of
	 * vehicles.
	 * @param world The world.
	 * @param enginID The engine id to build.
	 * @return A ConnectionReport instance.
	 */
	function CompileReport(world, engineID) {
		// First we check how much we already transport.
		// Check if we already have vehicles who transport this cargo and deduce it from 
		// the number of vehicles we need to build.
		local cargoAlreadyTransported = 0;
		foreach (connection in travelFromNode.connections) {
			if (connection.cargoID == cargoID) {
				
				// This shouldn't happen!
				if (connection.pathInfo == null)
					continue;
				
				// We don't want multiple connections use the same source unless it is a bilateral connection! (need rewrite..)
				if (!connection.bilateralConnection && connection.pathInfo.build && connection.travelToNode != travelToNode)
					return null;
					
				foreach (vehicleGroup in connection.vehiclesOperating) {
					cargoAlreadyTransported += vehicleGroup.vehicleIDs.len() * (World.DAYS_PER_MONTH / (vehicleGroup.timeToTravelTo + vehicleGroup.timeToTravelFrom)) * AIEngine.GetCapacity(vehicleGroup.engineID);
				}
			}
		}
	
		return ConnectionReport(world, travelFromNode, travelToNode, cargoID, engineID, cargoAlreadyTransported);
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
		
		connectionManager.ConnectionRealised(this);
	}
	
	/**
	 * Destroy this connection.
	 */
	function Demolish() {
		if (!pathInfo.build)
			return;
		AITile.DemolishTile(pathInfo.depot);
		local startTileList = AIList();
		local startStation = pathInfo.roadList[0].tile;
		local endTileList = AIList();
		local endStation = pathInfo.roadList[pathInfo.roadList.len() - 1].tile;
		
		startTileList.Add(startStation, startStation);
		DemolishStations(startTileList, AIStation.GetName(AIStation.GetStationID(startStation)), AIList());

		startTileList.Add(endStation, endStation);
		DemolishStations(endTileList, AIStation.GetName(AIStation.GetStationID(endStation)), AIList());

		AITile.Demolishtile(pathInfo.roadList[0].tile);
		AITile.Demolishtile(pathInfo.roadList[pathInfo.roadList.len() - 1].tile);
		
		if (bilateralConnection)
			AITile.Demolishtile(pathInfo.depotOtherEnd);
			
		connectionManager.ConnectionDemolished(this);
	}
	
	/**
	 * Utility function to destroy all road stations which are related.
	 * @param tileList A list of tiles which must be removed.
	 * @param stationName The name of stations to be removed.
	 * @param excludeList A list of stations already explored.
	 */
	function DemolishStations(tileList, stationName, excludeList) {
		if (stationList.Count() == 0)
			return;
 
		local tile = tileList.remove(0);
		local currentStationID = AIStation.GetStationID(tile);
		foreach (surroundingTile in Tile.GetTilesAround(tile, true)) {
			if (excludeList.HasItem(surroundingTile)) continue;

			local stationID = AIStation.GetStationID(surroundingTile);

			if (AIStation.IsValidStation(stationID)) {
				excludeList.AddItem(surroundingTile, surroundingTile);

				// Only explore this possibility if the station has the same name!
				if (AIStation.GetName(stationID) != stationName)
					continue;
				AITile.DemolishTile(tile);

				DemolishStations(surroundingTile, stationName, excludeList);
				continue;
			}

			if (!tileList.HasItem(surroundingTile))
				tileList.AddItem(surroundingTile, surroundingTile);
		}
	}
	
	
	// Everything below this line is just a toy implementation designed to test :)
	function GetLocationsForNewStation(atStart) {
		if (!pathInfo.build)
			return AIList();
	
		local tileList = AIList();	
		local excludeList = AIList();	
		local tile = null;
		if (atStart) {
			tile = pathInfo.roadList[0].tile;
		} else {
			tile = pathInfo.roadList[pathInfo.roadList.len() - 1].tile;
		}
		excludeList.AddItem(tile, tile);
		GetSurroundingTiles(tile, tileList, excludeList);
		
		return tileList;
	}
	
	function GetSurroundingTiles(tile, tileList, excludeList) {

		local currentStationID = AIStation.GetStationID(tile);
		foreach (surroundingTile in Tile.GetTilesAround(tile, true)) {
			if (excludeList.HasItem(surroundingTile)) continue;

			local stationID = AIStation.GetStationID(surroundingTile);

			if (AIStation.IsValidStation(stationID)) {
				excludeList.AddItem(surroundingTile, surroundingTile);

				// Only explore this possibility if the station has the same name!
				if (AIStation.GetName(stationID) != AIStation.GetName(currentStationID))
					continue;

				GetSurroundingTiles(surroundingTile, tileList, excludeList);
				continue;
			}

			if (!tileList.HasItem(surroundingTile))
				tileList.AddItem(surroundingTile, surroundingTile);
		}
	}
	
	function GetUID() {
		return travelFromNode.GetUID(cargoID);
	}
}
