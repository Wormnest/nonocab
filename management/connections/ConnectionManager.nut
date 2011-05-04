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
	assert(AIStation.IsValidStation(connection.pathInfo.travelFromNodeStationID));
	stationIDToConnection[connection.pathInfo.travelFromNodeStationID] <- connection;
	
	assert(AIStation.IsValidStation(connection.pathInfo.travelToNodeStationID));
	stationIDToConnection[connection.pathInfo.travelToNodeStationID] <- connection;
	foreach (listener in connectionListeners)
		listener.ConnectionRealised(connection);
}

function ConnectionManager::ConnectionDemolished(connection) {
	foreach (listener in connectionListeners)
		listener.ConnectionDemolished(connection);
}
