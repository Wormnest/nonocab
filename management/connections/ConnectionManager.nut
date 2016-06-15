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
						
						// Don't replace trains, ever!
						/// @todo Replacement for trains!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
						else if (vehicleType == AIVehicle.VT_RAIL) {
							doReplace = false;
						}
						
						if (doReplace) {
							// Create a new vehicle.
							// Wormnest: I think when replacing it's better to sell the vehicle first and
							// then try to replace it. However then we won't be able to share orders with
							// the old vehicle so for now we will leave it as is.
							local newVehicleID = AIVehicle.BuildVehicle(AIVehicle.GetLocation(vehicleID), replacementEngineID[0]);
							if (AIVehicle.IsValidVehicle(newVehicleID)) {
								Log.logDebug("Replacing it with " + AIVehicle.GetName(newVehicleID));
								
								// Let is share orders with the vehicle.
								AIOrder.ShareOrders(newVehicleID, vehicleID);
								AIGroup.MoveVehicle(connection.vehicleGroupID, newVehicleID);
								AIVehicle.StartStopVehicle(newVehicleID);
							} else {
								local lasterr = AIError.GetLastError();
								if ((lasterr == AIVehicle.ERR_VEHICLE_TOO_MANY) ||
									(lasterr == AIVehicle.ERR_VEHICLE_BUILD_DISABLED)) {
									Log.logDebug("Can't replace vehicle because we have reached the current limit!");
									// Next we will sell it anyway and not try again since that will keep failing.
								}
								else {
								// If we failed, simply try again next time.
									Log.logDebug("Failed to replace vehicle! " + AIError.GetLastErrorString());
									continue;
								}
							}
						}
					}
				}
				
				Log.logDebug("Selling vehicle: " + AIVehicle.GetName(vehicleID));
				AIVehicle.SellVehicle(vehicleID);
			}
			
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
