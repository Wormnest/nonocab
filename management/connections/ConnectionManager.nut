class ConnectionManager {

	connectionListeners = null;
	stationIDToConnection = null;  // Mapping from station IDs to connections.
	interConnectedStations = null; // Mapping from station IDs of connections to stationIDs of 
	                               // other connections who are connected to it. This is done to
	                               // keep track of rail connections which must be upgraded together.
	
	constructor() {
		connectionListeners = [];
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
	saveData["ConnectionManager"] <- CMsaveData;
}

function ConnectionManager::LoadData(data) {
	local CMsaveData = data["ConnectionManager"];
	interConnectedStations = CMsaveData["interConnectedStations"];
}

function ConnectionManager::GetConnection(stationID) {
	if (stationIDToConnection.rawin(stationID))
		return stationIDToConnection.rawget(stationID);
	return null;
}

function ConnectionManager::GetInterconnectedConnections(connection) {
	assert(GetConnection(connection.travelFromNodeStationID) != null);
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
	
	//connectedStations2.clear();
	//connectedStations2.extend(connectedStations1);
	
	// Add the new connections.
	//connectedStations1.push(connection2.travelFromNodeStationID);
	//connectedStations2.push(connection1.travelFromNodeStationID);
	
	//Log.logWarning(connectedStations1.len() + " " + connectedStations2.len());
	
	// TODO: Remove afterwards.
	// Test if they're really added.
	local test1 = interConnectedStations.rawget(connection1.travelFromNodeStationID);
	local test2 = interConnectedStations.rawget(connection2.travelFromNodeStationID);
	
	Log.logWarning(test1.len() + " " + test2.len());
	
	local found1 = false;
	foreach (connection in test1) {
		if (connection == connection2.travelFromNodeStationID) {
			found1 = true;
			break;
		}
	}
	assert(found1);
	
	local found2 = false;
	foreach (connection in test2) {
		if (connection == connection1.travelFromNodeStationID) {
			found2 = true;
			break;
		}
	}
	assert(found2);
	
	assert(test1.len() == connectedStations1.len());
	assert(test2.len() == connectedStations1.len());
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
	assert(AIStation.IsValidStation(connection.travelFromNodeStationID));
	stationIDToConnection[connection.travelFromNodeStationID] <- connection;
	
	assert(AIStation.IsValidStation(connection.travelToNodeStationID));
	stationIDToConnection[connection.travelToNodeStationID] <- connection;
	foreach (listener in connectionListeners)
		listener.ConnectionRealised(connection);
}

function ConnectionManager::ConnectionDemolished(connection) {
//	assert(AIStation.IsValidStation(connection.travelFromNodeStationID));
//	stationIDToConnection.rawdelete(connection.travelFromNodeStationID);
	
//	assert(AIStation.IsValidStation(connection.travelToNodeStationID));
//	stationIDToConnection[connection.travelToNodeStationID] <- null;
	foreach (listener in connectionListeners)
		listener.ConnectionDemolished(connection);
}
