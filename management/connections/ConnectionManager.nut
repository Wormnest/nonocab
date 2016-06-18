class ConnectionManager {

	connectionListeners = null;
	stationIDToConnection = null;  // Mapping from station IDs to connections.
	interConnectedStations = null; // Mapping from station IDs of connections to stationIDs of 
	                               // other connections who are connected to it. This is done to
	                               // keep track of rail connections which must be upgraded together.
	allConnections = null;
	
	constructor(worldEventManager) {
		worldEventManager.AddEventListener(this, AIEvent.ET_ENGINE_AVAILABLE);
		connectionListeners = [];
		allConnections = [];
		stationIDToConnection = {};
		interConnectedStations = {};
	}
	
	function AddConnectionListener(listener);
	function RemoveConnectionListener(listener);
	function ConnectionRealised(connection);
	function ConnectionDemolished(connection);
}

/**
 * TODO: Go through all connections and check which vehicles need to be sold (at least 3 years old
 * and making a loss the last year in operation) and which need to be replaced (in depot but max age
 * not yet reached).
 */ 
function ConnectionManager::MaintainActiveConnections() {
	
	foreach (connection in allConnections) {
		local vehicleList = AIVehicleList_Group(connection.vehicleGroupID);
		
		foreach (vehicleID, value in vehicleList) {
			local vehicleType = AIVehicle.GetVehicleType(vehicleID);
			if (AIVehicle.IsStoppedInDepot(vehicleID)) {
				Log.logDebug("Vehicle: " + AIVehicle.GetName(vehicleID) + " is stopped in depot.");
				
				// If the vehicle is very old, we assume it needs to be replaced
				// by a new vehicle.
				if (AIVehicle.GetAgeLeft(vehicleID) <= 0) {
					local currentEngineID = AIVehicle.GetEngineType(vehicleID);

					// Check what the best engine at the moment is.
					local replacementEngineID = connection.GetBestTransportingEngine(vehicleType);

					// Replace if we have a valid replacement engine.
					if ((replacementEngineID != null) && (replacementEngineID[0] != null) &&
						AIEngine.IsBuildable(replacementEngineID[0])) {
						
						local doReplace = true;
						// Don't replace an airplane if the airfield is very small.
						if (vehicleType == AIVehicle.VT_AIR) {
							if (AIEngine.GetPlaneType(AIVehicle.GetEngineType(vehicleID)) !=
								AIEngine.GetPlaneType(replacementEngineID[0]))
								doReplace = false;
						}
						
						if (doReplace) {
							// Create a new vehicle.
							// We sell the old vehicle first that way we can replace it even if we have reached the max vehicle limit.
							
							// If multiple vehicles share the same orders pick one to share the new vehicles orders with.
							local depot_loc = AIVehicle.GetLocation(vehicleID);
							local shared_vehicles = AIVehicleList_SharedOrders(vehicleID);
							local share_veh = null;
							if (shared_vehicles.Count() > 1) {
								foreach (veh in shared_vehicles)
									if (veh != vehicleID) {
										share_veh = veh;
										break;
									}
							}
							// Now sell the old vehicle.
							Log.logDebug("Selling vehicle: " + AIVehicle.GetName(vehicleID));
							AIVehicle.SellVehicle(vehicleID);
							
							// Build a new one and check if it's valid
							local newVehicleID;
							if (vehicleType == AIVehicle.VT_RAIL)
								/// @todo Decide on actual number of wagons, however in Report.nut currently also a fixed amount of 5 is used?
								newVehicleID = ManageVehiclesAction.BuildTrain(depot_loc, replacementEngineID[0], connection.cargoID, replacementEngineID[1], 5 /*numberWagons*/ );
							else
								newVehicleID = ManageVehiclesAction.BuildVehicle(depot_loc, replacementEngineID[0], connection.cargoID, true);
							if (newVehicleID == null) {
								// Building failed for whatever reason that is already shown in log.
								continue;
							}
							Log.logDebug("Replacing it with " + AIVehicle.GetName(newVehicleID) + " using engine " + AIEngine.GetName(replacementEngineID[0]));
							// Give orders to the new vehicle.
							// If the sold vehicle was sharing orders with other vehicles then we can share orders.
							// Otherwise set orders. But since we currently don't know what direction the old vehicle was going, for now always use false.
							if (share_veh != null) {
								Log.logDebug("Share orders with " + AIVehicle.GetName(share_veh));
								AIOrder.ShareOrders(newVehicleID, share_veh);
							}
							else {
								Log.logDebug("Set new orders");
								ManageVehiclesAction.SetOrders(newVehicleID, vehicleType, connection, false);
							}
							AIGroup.MoveVehicle(connection.vehicleGroupID, newVehicleID);
							AIVehicle.StartStopVehicle(newVehicleID);
							
							// Since we already sold the vehicle if we arrive here we should go on to the next.
							continue;
						}
					}
					else {
						Log.logWarning("We can't replace " + AIVehicle.GetName(vehicleID) + " with a new one!");
					}
				}
				
				/// @todo If this was the last vehicle on this connection maybe signal
				/// @todo that this connection should be removed!
				Log.logDebug("Selling vehicle: " + AIVehicle.GetName(vehicleID) + ", connection: " + connection.ToString());
				AIVehicle.SellVehicle(vehicleID);
			}
			else { // Not stopped in depot
				// Check if the vehicle is profitable.
				if (AIVehicle.GetAge(vehicleID) > Date.DAYS_PER_YEAR * 2 && AIVehicle.GetProfitLastYear(vehicleID) < 0 && AIVehicle.GetProfitThisYear(vehicleID) < 0) {
					if (vehicleType == AIVehicle.VT_WATER)
						AIOrder.SetOrderCompareValue(vehicleID, 0, 0);
					else if ((AIOrder.GetOrderFlags(vehicleID, AIOrder.ORDER_CURRENT) & AIOrder.OF_STOP_IN_DEPOT) == 0)
						AIVehicle.SendVehicleToDepot(vehicleID);
				}
			}
		}
	}
}

function ConnectionManager::SaveData(saveData) {
	local CMsaveData = {};
	CMsaveData["interConnectedStations"] <- interConnectedStations;
	
	local activeConnections = [];
	foreach (idx, connection in allConnections) {
		// Wormnest: To me it seems better to have incomplete connections in savedata
		// than for the saving to run out of time since that will make us crash.
		// Longest connection seen so far used 8625 ops (4kx4k map)!
		// So I guess it's better to use a limit of at least 10000. Lower values may be possible on smaller maps?
		if (AIController.GetOpsTillSuspend() < 10000) {
			Log.logError("Almost out of time saving. Discarding " + (allConnections.len() - idx - 1) +
			" of " + allConnections.len() + " connections!");
			break;
		}
		activeConnections.push(connection.SaveData());
	}
	
	CMsaveData["allConnections"] <- activeConnections;
	saveData["ConnectionManager"] <- CMsaveData;
}

function ConnectionManager::LoadData(data, world) {
	local CMsaveData = data["ConnectionManager"];
	interConnectedStations = CMsaveData["interConnectedStations"];
	local unsuccessfulLoads = 0;
	
	local savedConnectionsData = CMsaveData["allConnections"];
	foreach (savedConnectionData in savedConnectionsData) {
		Log.logDebug("Process: " + savedConnectionData["travelFromNode"] + " " + savedConnectionData["travelToNode"] + " " + AICargo.GetCargoLabel(savedConnectionData["cargoID"]));
		local connectionProcesses = false;
		
		// Search for the connection which matches the saved values.
		foreach (connectionFromNode in world.industry_tree) {
			foreach (cargoID in connectionFromNode.cargoIdsProducing) {
				if (connectionFromNode.GetUID(cargoID) != savedConnectionData["travelFromNode"])
					continue;
					
				Log.logDebug("Found proper from node! " + connectionFromNode.GetName());
					
				if (cargoID != savedConnectionData["cargoID"])
					continue;
					
				Log.logDebug("Found proper Cargo ID! " + AICargo.GetCargoLabel(cargoID));
				
				local foundConnectionToNode = -1;
				
				foreach (connectionToNode in connectionFromNode.connectionNodeList) {
				
					Log.logDebug("compare " + connectionToNode.GetUID(cargoID) + " v.s. " + savedConnectionData["travelToNode"] + " " + connectionToNode.GetName());
					if (connectionToNode.GetUID(cargoID) != savedConnectionData["travelToNode"])
						continue;
						
					foundConnectionToNode = connectionToNode;
					break;
				}

				// Connections from town <--> town are stored only in a single direction. Therefore we need to
				// check if the reverse connection does exist.				
				if (foundConnectionToNode == -1 &&
				    connectionFromNode.nodeType == ConnectionNode.TOWN_NODE)
				{
					Log.logDebug("Check reversed list!");
					foreach (connectionToNode in connectionFromNode.connectionNodeListReversed) {
					
						Log.logDebug("compare " + connectionToNode.GetUID(cargoID) + " v.s. " + savedConnectionData["travelToNode"] + " " + connectionToNode.GetName());
						if (connectionToNode.GetUID(cargoID) != savedConnectionData["travelToNode"])
							continue;
							
						foundConnectionToNode = connectionToNode;
						break;
					}
				}
				
				if (foundConnectionToNode == -1)
					continue;
						
				Log.logDebug("Found proper to node! " + foundConnectionToNode.GetName());
				    	
				local existingConnection = Connection(cargoID, connectionFromNode, foundConnectionToNode, null, this);
				existingConnection.LoadData(savedConnectionData);
				connectionFromNode.AddConnection(foundConnectionToNode, existingConnection);
					
				Log.logInfo("Loaded connection from " + connectionFromNode.GetName() + " to " + foundConnectionToNode.GetName() + " carrying " + AICargo.GetCargoLabel(cargoID));

				connectionProcesses = true;
				break;
			}
			
			if (connectionProcesses)
				break;
		}
		
		if (!connectionProcesses) {
			++unsuccessfulLoads;
			Log.logError("A saved connection was not present!");
		}
	}
		
	Log.logInfo("Successfully loaded: [" + (savedConnectionsData.len() - unsuccessfulLoads) + "/" + savedConnectionsData.len() + "]");
}

/**
 * Whenever a new Engine becomes available, update the cached transport and holding engine IDs for all built connections.
 */
function ConnectionManager::WE_EngineReplaced(newEngineID) {
	foreach (connection in allConnections) {
		connection.NewEngineAvailable(newEngineID);
	}
}

function ConnectionManager::FindConnectionNode(connectionNodeList, cargoID, connectionNodeToFindGUID) {
	foreach (connectionNode in connectionNodeList) {
	
		Log.logInfo("compare " + connectionNode.GetUID(cargoID) + " v.s. " + connectionNodeToFindGUID + " " + connectionNode.GetName());
		if (connectionNode.GetUID(cargoID) != connectionNodeToFindGUID)
			continue;
			
		Log.logInfo("Found propper to node!");
		    	
		local existingConnection = Connection(cargoID, connectionFromNode, connectionToNode, null, this);
		existingConnection.LoadData(savedConnectionData);
		connectionFromNode.AddConnection(connectionToNode, existingConnection);
			
		Log.logInfo("Loaded connection from " + connectionFromNode.GetName() + " to " + connectionToNode.GetName() + " carrying " + AICargo.GetCargoLabel(cargoID));
		ConnectionRealised(existingConnection);
			
		connectionProcesses = true;
		break;
	}
}

function ConnectionManager::GetConnection(stationID) {
	if (stationIDToConnection.rawin(stationID))
		return stationIDToConnection.rawget(stationID);
	return null;
}

function ConnectionManager::GetInterconnectedConnections(connection) {
	if (interConnectedStations.rawin(connection.pathInfo.travelFromNodeStationID)) {
		local stationIDs = interConnectedStations.rawget(connection.pathInfo.travelFromNodeStationID);
		local connections = [];
		
		foreach (stationID in stationIDs)
			if (stationIDToConnection.rawin(stationID))
				connections.push(stationIDToConnection.rawget(stationID));
			else
				Log.logError("stationID not found! Probably caused by an incomplete savegame.");
		return connections;
	}
	return null;
}

function ConnectionManager::MakeInterconnected(connection1, connection2) {
	// First make the connections share eachother's connections.
	local connectedStations1 = null;
	if (interConnectedStations.rawin(connection1.pathInfo.travelFromNodeStationID))
		connectedStations1 = interConnectedStations.rawget(connection1.pathInfo.travelFromNodeStationID);
	else {
		connectedStations1 = [connection1.pathInfo.travelFromNodeStationID];
		interConnectedStations[connection1.pathInfo.travelFromNodeStationID] <- connectedStations1;
	}
	
	// Make sure these stations weren't connected before.
	for (local i = 0; i < connectedStations1.len(); i++)
		if (connectedStations1[i] == connection2.pathInfo.travelFromNodeStationID)
			return;
	
	Log.logWarning(connection1.travelFromNode.GetName() + " connected to " + connection2.travelFromNode.GetName());
	
	local connectedStations2 = null;
	if (interConnectedStations.rawin(connection2.pathInfo.travelFromNodeStationID))
		connectedStations2 = interConnectedStations.rawget(connection2.pathInfo.travelFromNodeStationID);
	else {
		connectedStations2 = [connection2.pathInfo.travelFromNodeStationID];
		interConnectedStations[connection2.pathInfo.travelFromNodeStationID] <- connectedStations2;
	}
	
	// Combine the arrays.
	connectedStations1.extend(connectedStations2);
	foreach (connectionStationID in connectedStations1) {
		interConnectedStations[connectionStationID] <- connectedStations1;
	}
}

function ConnectionManager::AddConnectionListener(listener) {
	connectionListeners.push(listener);
}

function ConnectionManager::RemoveConnectionListener(listener) {
	for (local i = 0; i < connectionListeners.len(); i++) {
		if (connectionListeners[i] == listener) {
			connectionListeners.remove(i);
			break;
		}
	}
}

function ConnectionManager::ConnectionRealised(connection) {
	
	assert (connection.pathInfo.build);
	allConnections.push(connection);
	
	assert(AIStation.IsValidStation(connection.pathInfo.travelFromNodeStationID));
	stationIDToConnection[connection.pathInfo.travelFromNodeStationID] <- connection;
	
	assert(AIStation.IsValidStation(connection.pathInfo.travelToNodeStationID));
	stationIDToConnection[connection.pathInfo.travelToNodeStationID] <- connection;
	foreach (listener in connectionListeners)
		listener.ConnectionRealised(connection);
}

function ConnectionManager::ConnectionDemolished(connection) {
	
	for (local i = 0; i < allConnections.len(); i++) {
		if (allConnections[i] == connection) {
			allConnections.remove(i);
			break;
		}
	}
	
	foreach (listener in connectionListeners)
		listener.ConnectionDemolished(connection);
}
