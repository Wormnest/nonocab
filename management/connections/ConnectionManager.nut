class ConnectionManager {

	connectionListeners = null;
	stationIDToConnection = null;  // Mapping from station IDs to connections.
	interConnectedStations = null; // Mapping from station IDs of connections to stationIDs of 
	                               // other connections who are connected to it. This is done to
	                               // keep track of rail connections which must be upgraded together.
	allConnections = null;
	
	constructor(worldEventManager) {
		worldEventManager.AddEventListener(this, AIEvent.AI_ET_ENGINE_AVAILABLE);
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
				
				// If the vehicle is very old, we assume it needs to be replaced
				// by a new vehicle.
				if (AIVehicle.GetAgeLeft(vehicleID) <= 0) {
					local currentEngineID = AIVehicle.GetEngineType(vehicleID);

					// Check what the best engine at the moment is.
					local replacementEngineID = connection.GetBestTransportingEngine(vehicleType);
					
					if (AIEngine.IsBuildable(replacementEngineID)) {
						
						local doReplace = true;
						// Don't replace an airplane if the airfield is very small.
						if (vehicleType == AIVehicle.VT_AIR) {
							if (AIEngine.GetPlaneType(AIVehicle.GetEngineType(vehicleID)) !=
								AIEngine.GetPlaneType(replacementEngineID))
								doReplace = false;
						}
						
						// Don't replace trains, ever!
						// TODO: Be smarter about this.
						else if (vehicleType == AIVehicle.VT_RAIL) {
							doReplace = false;
						}
						
						if (doReplace) {
							// Create a new vehicle.
							local newVehicleID = AIVehicle.BuildVehicle(AIVehicle.GetLocation(vehicleID), replacementEngineID);
							if (AIVehicle.IsValidVehicle(newVehicleID)) {
								
								// Let is share orders with the vehicle.
								AIOrder.ShareOrders(newVehicleID, vehicleID);
								AIGroup.MoveVehicle(connection.vehicleGroupID, newVehicleID);
								AIVehicle.StartStopVehicle(newVehicleID);
							} else {
								// If we failed, simply try again next time.
								continue;
							}
						}
					}
				}
				
				AIVehicle.SellVehicle(vehicleID);
			}
			
			// Check if the vehicle is profitable.
			if (AIVehicle.GetAge(vehicleID) > Date.DAYS_PER_YEAR * 2 && AIVehicle.GetProfitLastYear(vehicleID) < 0 && AIVehicle.GetProfitThisYear(vehicleID) < 0) {
				if (vehicleType == AIVehicle.VT_WATER)
					AIOrder.SetOrderCompareValue(vehicleID, 0, 0);
				else if ((AIOrder.GetOrderFlags(vehicleID, AIOrder.ORDER_CURRENT) & AIOrder.AIOF_STOP_IN_DEPOT) == 0)
					AIVehicle.SendVehicleToDepot(vehicleID);
	
			}
		}
	}
}

function ConnectionManager::SaveData(saveData) {
	local CMsaveData = {};
	CMsaveData["interConnectedStations"] <- interConnectedStations;
	
	local activeConnections = [];
	foreach (connection in allConnections) {
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
					
				Log.logDebug("Found propper from node! " + connectionFromNode.GetName());
					
				if (cargoID != savedConnectionData["cargoID"])
					continue;
					
				Log.logDebug("Found propper Cargo ID! " + AICargo.GetCargoLabel(cargoID));
				
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
						
				Log.logDebug("Found propper to node!");
				    	
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
		
	Log.logInfo("Successfully load: [" + (savedConnectionsData.len() - unsuccessfulLoads) + "/" + savedConnectionsData.len() + "]");
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
			connections.push(stationIDToConnection.rawget(stationID));
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
