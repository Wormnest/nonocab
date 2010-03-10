class TransferVehicles extends Action {

	oldConnection = null;
	newConnection = null;
	world = null;
	
	constructor(world, oldConnection, newConnection) {
		Action.constructor();
		this.world = world;
		this.oldConnection = oldConnection;
		this.newConnection = newConnection;
	}
	
	/**
	 * Find all vehicles off the old connection and issue new orders!
	 */
	function Execute() {
		// Check if there is a possibility to transfer vehicles from the
		// start of the old connection to the start of the new connection.
		/*if (oldConnection.vehicleTypes == newConnection.vehicleTypes &&
		oldConnection.vehicleTypes == AIVehicle.VT_ROAD) {
			local helper = RoadPathFinderHelper();
			local pathFinder = RoadPathFinding(helper);
			
			local startList = AIList();
			local roadList = oldConnection.pathInfo.roadList;
			startList.AddItem(roadList[roadList.len() - 1].tile);
			
			local endList = AIList();
			endList.AddItem(roadList[0].tile);
			local pathInfo = pathFinder.FindFastestRoad(startList, endList, false, false, null, 100, null);
			
			if (pathInfo == null) {
				Log.logError("No path found to connect the two pieces!");
			}
			
			// Construct this path!
			local dummyConnection = Connection(oldConnection.cargoID, oldConnection.travelFromNode, oldConnection.travelToNode, pathInfo, null);
			local builder = PathBuilder(dummyConnection, world.cargoTransportEngineIds[AIVehicle.VT_ROAD][newConnection.cargoID], world.pathFixer);
			builder.RealiseConnection(false);
		}*/

		local test = AIExecMode();
		foreach (group in oldConnection.vehiclesOperating) {

			// Use a 'main' vehicle to enable the sharing of orders.
			local roadList = oldConnection.pathInfo.roadList;
			local mainVehicleID = -1;
			local mainVehicleIDReverse = -1;
			foreach (vehicle in group.vehicleIDs) {
				if (mainVehicleIDReverse == null && AIOrder.GetOrderDestination(vehicle, 0) == roadList[0].tile ||
					mainVehicleID == null && AIOrder.GetOrderDestination(vehicle, 0) == roadList[roadList.len() - 1].tile) {
					local orderCount = AIOrder.GetOrderCount(vehicle);
					
					// Duplicate old orders with new destinations and remove the old ones.
					for (local i = 0; i < orderCount; i++) {
						local destination = AIOrder.GetOrderDestination(vehicle, 0);
						local flags = AIOrder.GetOrderFlags(vehicle, 0);
						if (destination == oldConnection.travelFromNode)
							AIOrder.AppendOrder(vehicle, newConnection.travelFromNode, flags); 
						else if (destination == oldConnection.travelToNode)
							AIOrder.AppendOrder(vehicle, newConnection.travelToNode, flags);
						else
							AIOrder.AppendOrder(vehicle, destination, flags);
							
						AIOrder.RemoveOrder(vehicle, 0);
					}
					
					if (AIOrder.GetOrderDestination(vehicle, 0) == roadList[0].tile)
						mainVehicleIDReverse = vehicle;
					else
						mainVehicleID = vehicle;
				}
				if (mainVehicleID != -1 && mainVehicleIDReverse != -1)
					break;
			}
		}
		return true;
	}
}