class ConnectionManager {

	connectionListeners = null;
	stationIDToConnection = null;  // Mapping from station IDs to connections.
	interConnectedStations = null; // Mapping from station IDs of connections to stationIDs of 
	                               // other connections who are connected to it. This is done to
	                               // keep track of rail connections which must be upgraded together.
	allConnections = null;
	
	constructor() {
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
				ConnectionRealised(existingConnection);
					
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
	if (interConnectedStations.rawin(connection.travelFromNodeStationID)) {
		local stationIDs = interConnectedStations.rawget(connection.travelFromNodeStationID);
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
	if (interConnectedStations.rawin(connection1.travelFromNodeStationID))
		connectedStations1 = interConnectedStations.rawget(connection1.travelFromNodeStationID);
	else {
		connectedStations1 = [connection1.travelFromNodeStationID];
		interConnectedStations[connection1.travelFromNodeStationID] <- connectedStations1;
	}
	
	// Make sure these stations weren't connected before.
	for (local i = 0; i < connectedStations1.len(); i++)
		if (connectedStations1[i] == connection2.travelFromNodeStationID)
			return;
	
	Log.logWarning(connection1.travelFromNode.GetName() + " connected to " + connection2.travelFromNode.GetName());
	
	local connectedStations2 = null;
	if (interConnectedStations.rawin(connection2.travelFromNodeStationID))
		connectedStations2 = interConnectedStations.rawget(connection2.travelFromNodeStationID);
	else {
		connectedStations2 = [connection2.travelFromNodeStationID];
		interConnectedStations[connection2.travelFromNodeStationID] <- connectedStations2;
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
	
	allConnections.push(connection);
	
	assert(AIStation.IsValidStation(connection.travelFromNodeStationID));
	stationIDToConnection[connection.travelFromNodeStationID] <- connection;
	
	assert(AIStation.IsValidStation(connection.travelToNodeStationID));
	stationIDToConnection[connection.travelToNodeStationID] <- connection;
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
