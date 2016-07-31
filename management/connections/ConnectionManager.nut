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
		if (!connection.pathInfo.build) {
			Log.logError("Something is wrong: pathInfo.build is false for connection " + connection.ToString());
		}
		else if (connection.vehicleGroupID == null || !AIGroup.IsValidGroup(connection.vehicleGroupID)) {
			Log.logError("Invalid vehicle group for connection " + connection.ToString());
		}
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
							local share_veh = ManageVehiclesAction.GetSharedVehicle(vehicleID)
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
								if (!AIOrder.ShareOrders(newVehicleID, share_veh)) {
									Log.logError("Sharing orders failed unexpectedly! " + AIError.GetLastErrorString());
									share_veh = null;
								}
							}
							if (share_veh == null) {
								Log.logDebug("Set new orders");
								ManageVehiclesAction.SetOrders(newVehicleID, vehicleType, connection, false);
							}
							if (AIOrder.GetOrderCount(newVehicleID) <= 0) {
								Log.logError("Failed to add orders to vehicle " + AIVehicle.GetName(newVehicleID));
								// Vehicle without orders is worthless so sell it again!
								AIVehicle.SellVehicle(newVehicleID);
								// And don't try to get more.
								continue;
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
				// If vehicle has no orders then something is wrong: send it to depot even for ships.
				if (AIOrder.GetOrderCount(vehicleID) == 0) {
					Log.logError("We found a vehicle without orders: " + AIVehicle.GetName(vehicleID) + ". Group: " + AIGroup.GetName(connection.vehicleGroupID));
					AIVehicle.SendVehicleToDepot(vehicleID);
				}
				// Check if the vehicle is profitable.
				if (AIVehicle.GetAge(vehicleID) > Date.DAYS_PER_YEAR * 2 && AIVehicle.GetProfitLastYear(vehicleID) < 0 && AIVehicle.GetProfitThisYear(vehicleID) < 0) {
					if (vehicleType == AIVehicle.VT_WATER) {
						// First make sure orders are not shared.
						ManageVehiclesAction.UnshareVehicleOrders(vehicleID);
						// Make sure it's not going to try loading cargo.
						ManageVehiclesAction.RemoveFullLoadOrders(vehicleID);
						// Set age at which to go to depot to 0 so it will stop as soon as it reaches the first order in the list.
						AIOrder.SetOrderCompareValue(vehicleID, 0, 0);
					}
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
	
	Log.logInfo("Saving " + allConnections.len() + " connections.");
	local activeConnections = [];
	foreach (idx, connection in allConnections) {
		// Wormnest: To me it seems better to have incomplete connections in savedata
		// than for the saving to run out of time since that will make us crash.
		// Longest connection seen so far used 8625 ops (4kx4k map)!
		// So I guess it's better to use a limit of at least 10000. Lower values may be possible on smaller maps?
		// Since we are now caching the connections we are going to try to reduce this to 5000.
		if (AIController.GetOpsTillSuspend() < 5000) {
			Log.logError("Almost out of time saving. Discarding " + (allConnections.len() - idx) +
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
	if (savedConnectionsData.len() == 0) {
		Log.logInfo("There were no connections to load.");
		return;
	}
	// Make sure all nodes used by the saved connections are present.
	Log.logInfo("Checking industries and towns in saved connections.");
	foreach (savedConnectionData in savedConnectionsData) {
		local saved_from_uid = savedConnectionData["travelFromNode"];
		local saved_from_id = ConnectionNode.GetIDFromUID(saved_from_uid);
		local saved_to_uid = savedConnectionData["travelToNode"];
		local saved_to_id = ConnectionNode.GetIDFromUID(saved_from_uid);
		if (ConnectionNode.GetNodeTypeFromUID(saved_from_uid) == ConnectionNode.INDUSTRY_NODE) {
			//Log.logDebug("Saved Industry " + AIIndustry.GetName(saved_from_id));
			if (!world.industry_table.rawin(saved_from_id)) {
				Log.logDebug("Add industry " + AIIndustry.GetName(saved_from_id));
				world.InsertIndustry(saved_from_id);
			}
		}
		else { // town
			//Log.logDebug("Saved Town " + AITown.GetName(saved_from_id));
			if (!world.town_table.rawin(saved_from_id))
				world.InsertTown(saved_from_id);
		}
		local saved_to_uid = savedConnectionData["travelToNode"];
		local saved_to_id = ConnectionNode.GetIDFromUID(saved_to_uid);
		if (ConnectionNode.GetNodeTypeFromUID(saved_to_uid) == ConnectionNode.INDUSTRY_NODE) {
			//Log.logDebug("Saved Industry " + AIIndustry.GetName(saved_to_id));
			if (!world.industry_table.rawin(saved_to_id)) {
				Log.logDebug("Add industry " + AIIndustry.GetName(saved_to_id));
				world.InsertIndustry(saved_to_id);
			}
		}
		else { // town
			//Log.logDebug("Saved Town " + AITown.GetName(saved_to_id));
			if (!world.town_table.rawin(saved_to_id))
				world.InsertTown(saved_to_id);
		}
		//Log.logDebug("Saved Cargo " + AICargo.GetCargoLabel(savedConnectionData["cargoID"]));
		//Log.logDebug("Save vehicle type " + savedConnectionData["vehicleTypes"] +
		//	", vehicle group " + savedConnectionData["vehicleGroupID"] +
		//	" = " + AIGroup.GetName(savedConnectionData["vehicleGroupID"]));
	}
	
	// Keep track of how many connections still need to be loaded.
	local wantedConnections = savedConnectionsData.len();
	
	Log.logInfo("Restoring " + wantedConnections + " saved connections.");
	foreach (connectionFromNode in world.industry_tree) {
		foreach (savedConnectionData in savedConnectionsData) {
			local saved_from_uid = savedConnectionData["travelFromNode"];
			local saved_from_id = ConnectionNode.GetIDFromUID(saved_from_uid);
			
			// Saved node id should be same as connection node id
			if (saved_from_uid != connectionFromNode.GetUID(savedConnectionData["cargoID"]))
				continue;
			
			Log.logDebug("Process: " + savedConnectionData["travelFromNode"] + " " +
				savedConnectionData["travelToNode"] + " " +
				AICargo.GetCargoLabel(savedConnectionData["cargoID"]));
			if (savedConnectionData["vehicleGroupID"] == null) {
				Log.logWarning("vehicleGroupID is null (should not happen), skipping this connection since it's probably invalid.");
				continue;
			}
			Log.logDebug("Save vehicle type " + savedConnectionData["vehicleTypes"] +
				", vehicle group " + savedConnectionData["vehicleGroupID"] +
				" = " + AIGroup.GetName(savedConnectionData["vehicleGroupID"]));

			// We have found the correct node, now find the correct cargo
			local cargoFound = false;
			foreach (cargoID in connectionFromNode.cargoIdsProducing) {
				Log.logDebug("Producing cargo: " + AICargo.GetCargoLabel(cargoID));
				if (cargoID == savedConnectionData["cargoID"]) {
					Log.logDebug("--> Found the cargo we wanted!");
					cargoFound = true;
					break;
				}
			}
			local cargoID = savedConnectionData["cargoID"];
			if (!cargoFound) {
				Log.logError("We couldn't find the correct cargo! " + AICargo.GetCargoLabel(cargoID));
				unsuccessfulLoads++;
				wantedConnections--;
				continue;
			}
			
			// Now we need to find the correct to node.
			local foundConnectionToNode = -1;
			local saved_to_uid = savedConnectionData["travelToNode"];
			foreach (connectionToNode in connectionFromNode.connectionNodeList) {
				//Log.logDebug("compare " + connectionToNode.GetUID(cargoID) + " v.s. " + savedConnectionData["travelToNode"] + " " + connectionToNode.GetName());
				if (connectionToNode.GetUID(cargoID) == saved_to_uid) {
					foundConnectionToNode = connectionToNode;
					break;
				}
			}
			// Connections from town <--> town are stored only in a single direction. Therefore we need to
			// check if the reverse connection does exist.
			// Besides towns this can also happen for industries that both produce and accept the same cargo like banks (Valuables).
			if (foundConnectionToNode == -1 && connectionFromNode.connectionNodeListReversed.len() > 0)
			{
				Log.logDebug("Check reversed list!");
				foreach (connectionToNode in connectionFromNode.connectionNodeListReversed) {
					//Log.logDebug("compare " + connectionToNode.GetUID(cargoID) + " v.s. " + savedConnectionData["travelToNode"] + " " + connectionToNode.GetName());
					if (connectionToNode.GetUID(cargoID) == saved_to_uid) {
						foundConnectionToNode = connectionToNode;
						break;
					}
				}
			}
			if (foundConnectionToNode == -1) {
				unsuccessfulLoads++;
				wantedConnections--;
				local saved_to_id = ConnectionNode.GetIDFromUID(saved_to_uid);
				if (Log.logLevel == 0) {
					Log.logDebug("Save vehicle type " + savedConnectionData["vehicleTypes"] +
						", vehicle group " + savedConnectionData["vehicleGroupID"] +
						" = " + AIGroup.GetName(savedConnectionData["vehicleGroupID"]) +
						", from node: " + savedConnectionData["travelFromNode"] + " = " + connectionFromNode.GetName() +
						" to node: " + savedConnectionData["travelToNode"] + "= " +
						(ConnectionNode.GetNodeTypeFromUID(saved_to_uid) == ConnectionNode.TOWN_NODE ? AITown.GetName(saved_to_id) : AIIndustry.GetName(saved_to_id)) +
						", cargo " + AICargo.GetCargoLabel(cargoID));
					if (ConnectionNode.GetNodeTypeFromUID(saved_to_uid) == ConnectionNode.TOWN_NODE) {
						if (world.town_table.rawin(saved_to_id)) {
							Log.logDebug("Town exists in town table!");
						}
						else
							Log.logDebug("Town doesn't exists in town table!");
					}
					else {
						if (world.industry_table.rawin(saved_to_id)) {
							Log.logDebug("Industry exists in industry table!");
						}
						else
							Log.logDebug("Industry doesn't exists in industry table!");
					}
				}
				Log.logError("Connection destination node not found!");
				continue;
			}
			Log.logDebug("Initialize connection.");
			
			// We found the connection. Now save the connection data.
			local existingConnection = Connection(cargoID, connectionFromNode, foundConnectionToNode, null, this);
			existingConnection.LoadData(savedConnectionData);
			connectionFromNode.AddConnection(foundConnectionToNode, existingConnection);
				
			Log.logInfo("Loaded connection from " + connectionFromNode.GetName() + " to " + foundConnectionToNode.GetName() + " carrying " + AICargo.GetCargoLabel(cargoID));
			wantedConnections--;
			
			// Do not break here since the same connection from node might be used for a different cargo!
			//break;
		}
		// If there are no more saved connections to load then stop the loop.
		if (wantedConnections == 0)
			break;
	}
	if (unsuccessfulLoads > 0 || wantedConnections > 0)
		Log.logWarning("Successfully loaded: [" + (savedConnectionsData.len() - unsuccessfulLoads - wantedConnections) + "/" + savedConnectionsData.len() + "] " +
			"Unsuccessfull: " + unsuccessfulLoads + " Not found: " + wantedConnections);
	else
		Log.logInfo("Successfully loaded: [" + (savedConnectionsData.len() - unsuccessfulLoads - wantedConnections) + "/" + savedConnectionsData.len() + "]");
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
	// In case of error we are going to ignore the connection instead of crash.
	if (!connection.pathInfo.build)
		Log.logError("ConnectionRealised: pathInfo.build is invalid!");
	else if (!AIStation.IsValidStation(connection.pathInfo.travelFromNodeStationID) || !AIStation.IsValidStation(connection.pathInfo.travelToNodeStationID)) {
		// This should never happen! If it does give us at least some info to figure out the cause.
		Log.logInfo("Connection from " + connection.travelFromNode.GetName() + " to " + connection.travelToNode.GetName() +
			" carrying " + AICargo.GetCargoLabel(connection.cargoID) + ". Group: " + AIGroup.GetName(connection.vehicleGroupID));
		Log.logInfo("From station: " + AIBaseStation.GetName(connection.pathInfo.travelFromNodeStationID) +
			", To station: "+ AIBaseStation.GetName(connection.pathInfo.travelToNodeStationID) + ", build/update year: " + AIDate.GetYear(connection.pathInfo.buildDate));
		Log.logInfo("From station tile based on roadList: " + connection.pathInfo.roadList[connection.pathInfo.roadList.len()-1].tile +
			", name: " + AIBaseStation.GetName(AIStation.GetStationID(connection.pathInfo.roadList[connection.pathInfo.roadList.len()-1].tile)));
		Log.logInfo("To station tile based on roadList: " + connection.pathInfo.roadList[0].tile + ", name: " + AIBaseStation.GetName(AIStation.GetStationID(connection.pathInfo.roadList[0].tile)));
		Log.logError("ConnectionRealised: From or To station is invalid! Group: " + AIGroup.GetName(connection.vehicleGroupID));
	}
	else {
		allConnections.push(connection);
		
		stationIDToConnection[connection.pathInfo.travelFromNodeStationID] <- connection;
		stationIDToConnection[connection.pathInfo.travelToNodeStationID] <- connection;
		
		foreach (listener in connectionListeners)
			listener.ConnectionRealised(connection);
	}
}

function ConnectionManager::ConnectionDemolished(connection) {
	local found = false;
	for (local i = 0; i < allConnections.len(); i++) {
		if (allConnections[i] == connection) {
			allConnections.remove(i);
			found = true;
			break;
		}
	}
	if (!found)
		Log.logError("ConnectionDemolished: Couldn't find connection to remove! " + connection.ToString());
	
	foreach (listener in connectionListeners)
		listener.ConnectionDemolished(connection);
}

function ConnectionManager::PrintConnections()
{
	Log.logInfo("We currently have " + allConnections.len() + " connections.");
	foreach (connection in allConnections) {
		local engine = (connection.bestTransportEngine == null ? "" : ", engine: " + AIEngine.GetName(connection.bestTransportEngine));
		local vehGroup = connection.vehicleGroupID;
		if (vehGroup == null) {
			Log.logError("Vehicle group ID is null!");
			vehGroup = -1;
		}
		Log.logInfo("Connection: " + connection.ToString() + ", group: " + vehGroup + " = " + AIGroup.GetName(vehGroup) +
			engine + ", vehicle count: " + connection.GetNumberOfVehicles());
	}
}
