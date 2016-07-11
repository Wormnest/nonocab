/**
 * World holds the current status of the world as the AI sees it.
 */
class World {
	static MAX_TOWNS = 1000;
	static MAX_INDUSTRIES = 2000;
	// We don't need town_list available all the time, replaced by a local.
	//town_list = null;			// List with all towns.
	// We don't need industry_list to be available all the time, commented out here.
	//industry_list = null;		// List with all industries.
	industry_table = null;		// Table with all industries.
	town_table = null;			// Table with all towns.
	cargo_list = null;			// List with all cargos.
	town_cargo_list = null;		// List of cargos that have effect on towns.
	townConnectionNodes = null;		// All connection nodes which are towns (replace later, now in use by AirplaneAdvisor).
	maxCargoID = null;				// The highest cargo ID number

	industry_tree = null;
	industryCacheAccepting = null;
	industryCacheProducing = null;
	
	starting_year = null;
	years_passed = null;
	
	pathFixer = null;
	niceCABEnabled = null;
	
	/**
	 * Initializes a representation of the 'world'.
	 */
	constructor(niceCAB) {
		niceCABEnabled = niceCAB;
		townConnectionNodes = [];
		starting_year = AIDate.GetYear(AIDate.GetCurrentDate());
		years_passed = 0;
		//town_list = AITownList();
		//town_list.Valuate(AITown.GetPopulation);
		//town_list.Sort(AIList.SORT_BY_VALUE, false);
		industry_table = {};
		town_table = {};
		//industry_list = AIIndustryList();

		// Construct complete industry node list.
		cargo_list = AICargoList();
		cargo_list.Sort(AIList.SORT_BY_VALUE, false);
		maxCargoID = cargo_list.Begin();
		industryCacheAccepting = array(maxCargoID + 1);
		industryCacheProducing = array(maxCargoID + 1);
		
		town_cargo_list = AICargoList();
		town_cargo_list.Valuate(HasCargoEffectOnTownsValuator);
		town_cargo_list.KeepValue(1);
		//town_cargo_list.Sort(AIList.SORT_BY_VALUE, false);

		industry_tree = [];
	
		// Fill the arrays with empty arrays, we can't use:
		// local industryCacheAccepting = array(cargos.Count(), [])
		// because it will all point to the same empty array...
		foreach (index, value in cargo_list) {
			industryCacheAccepting[index] = [];
			industryCacheProducing[index] = [];
		}
	}
	
	/**
	 * Insert an industryNode in the industryList.
	 * @industryID The id of the industry which needs to be added.
	 */
	function InsertIndustry(industryID);

	/**
	 * Remove an industryNode from the industryList.
	 * @industryID The id of the industry which needs to be removed.
	 */
	function RemoveIndustry(industryID);

	/**
	 * Debug purposes only:
	 * Print the constructed industry node.
	 */
	function PrintTree();
	
	/**
	 * Debug purposes only:
	 * Print a single node in the industry tree.
	 */
	function PrintNode(node, depth);	
}

function World::HasCargoEffectOnTownsValuator(cargoID)
{
	local effect = AICargo.GetTownEffect(cargoID);
	if (effect == AICargo.TE_NONE)
		// TE_NONE returns true when checking IsValidTownEffect
		return false;
	else
		return AICargo.IsValidTownEffect(effect);
}

function World::LoadData(data) {
	starting_year = data["starting_year"];
	years_passed = data["years_passed"];
}

function World::SaveData(saveTable) {
	saveTable["starting_year"] <- starting_year;
	saveTable["years_passed"] <- years_passed;

	return saveTable;
}

/**
 * Build a tree of all industry nodes, where we connect each producing
 * industry to an industry which accepts that produced cargo. The primary
 * industries (ie. the industries which only produce cargo) are the root
 * nodes of this tree.
 */
function World::BuildIndustryTree() {

	Log.logDebug("Build industry tree");
	// For each industry we will determine all possible connections to other
	// industries which accept its goods. We build a tree structure in which
	// the root nodes consist of industry nodes who only produce products but
	// don't accept anything (the so called primary industries). The children
	// of these nodes are indutries which only accept goods which the root nodes
	// produce, and so on.
	//
	// Primary economies -> Secondary economies -> ... -> Towns
	// Town <-> town
	//
	//
	// Every industry is stored in an IndustryNode.
	local industry_list = AIIndustryList();
	Log.logInfo("Build industry list consisting of " + industry_list.Count() + " industries.");

	// On large maps we can get way to many industries. We should limit it.
	// Maybe in the future let the use set it within limits depending on how much memory they have.
	// For now I think a reasonable limit is 2000 industries.
	// On a test 2kx2k map I got 3520 industres on a 4kx4k map 14080 industries.
	if (industry_list.Count() > MAX_INDUSTRIES) {
		// There's no real good way to select a top x number of industries.
		// For base producting industries it's possible but for industries that need products
		// to be delivered first we can't do that.
		// So for now we just randomly select 2000 industries.
		Log.logWarning("There are more industries on this map than we can reasonably handle. Limiting to top " + MAX_INDUSTRIES + ".");
		industry_list.Valuate(AIBase.RandItem);
		industry_list.KeepTop(MAX_INDUSTRIES);
		/// @todo If we're loading a savegame we may be skipping an industry we're already using in a connection. In that case it should be added again!
	}
	foreach (industry, value in industry_list)
		InsertIndustry(industry);
	industry_list = null; // Free all the memory as soon as possible.
	Log.logInfo("Build industry list - done.");
	
	local town_list = AITownList();
	town_list.Valuate(AITown.GetPopulation);
	Log.logInfo("Build town list consisting of " + town_list.Count() + " towns.");
	// On large maps we can get way to many towns. We should limit it.
	// Maybe in the future let the use set it within limits depending on how much memory they have.
	// For now I think a reasonable limit is 1000 towns.
	// On a test 2kx2k map I got 1600 towns on a 4kx4k map 7680 towns.
	if (town_list.Count() > MAX_TOWNS) {
		Log.logWarning("There are more towns on this map than we can reasonably handle. Limiting to top " + MAX_TOWNS + ".");
		town_list.KeepTop(MAX_TOWNS);
	}
	town_list.Sort(AIList.SORT_BY_VALUE, false);

	// Now handle the connections Industry --> Town
	foreach (town, value in town_list) {
		InsertTown(town);
	}
	
	Log.logInfo("Build town list - done.");
}

/**
 * Insert a townNode in the industryList.
 * @param town The id of the town which needs to be added.
 */
function World::InsertTown(town)
{
	Log.logDebug("Town: " + AITown.GetName(town));
	local townNode = TownConnectionNode(town);
	local isNearWater = townNode.isNearWater;
	local stationRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	local rv_station_radius = AIStation.GetCoverageRadius(AIStation.STATION_BUS_STOP);
	
	// Make it easier to check whether a certain town is stored in our data or not.
	town_table[town] <- townNode;

	// Check if this town accepts something an industry creates.
	foreach (cargo, dummyvalue in town_cargo_list) {
		
		// Get acceptance based on radius of a roadvehicle station. Using a radius 1 instead may fail
		// to find enough acceptance even though for the whole town there may be enough acceptance.
		/// @todo Maybe we should completely remove this check and just depend on our checking for acceptance when we are looking for suitable connections.
		if (AITile.GetCargoAcceptance(townNode.GetLocation(), cargo, 1, 1, rv_station_radius)) {
			
			// Check if this town is near to water.
			if (!isNearWater) {
				local townTiles = townNode.GetAcceptingTiles(cargo, stationRadius, 1, 1);
				townTiles.Valuate(AITile.IsCoastTile);
				townTiles.KeepValue(1);
				if (townTiles.Count() > 0)
					townNode.isNearWater = true;
				isNearWater = true;
			}

			// Check if we have an industry which actually produces this cargo.
			foreach (connectionNode in industryCacheProducing[cargo])
				connectionNode.connectionNodeList.push(townNode);
			
			// Add this town to the accepting cache for future industries.
			industryCacheAccepting[cargo].push(townNode);

			// Only add cargo as produced in town if it has at least some production
			// This will filter out GOODS on the producing side for towns.
			switch (AICargo.GetTownEffect(cargo)) {
				case AICargo.TE_MAIL:
				case AICargo.TE_PASSENGERS:
					// I think mail and passengers are the only cargos that can be produced in a town.
					/// @todo However is this also true for NewGRF industries?
					townNode.cargoIdsProducing.push(cargo);
					break;
			}
			
			townNode.cargoIdsAccepting.push(cargo);
		}
	}

	// Add town <-> town connections, we only store these connections as 1-way directions
	// because they are bidirectional.
	foreach (townConnectionNode in townConnectionNodes) {
		townNode.connectionNodeList.push(townConnectionNode);
		townConnectionNode.connectionNodeListReversed.push(townNode);
	}

	townConnectionNodes.push(townNode);
	industry_tree.push(townNode);
}

/**
 * Insert an industryNode in the industryList.
 * @industryID The id of the industry which needs to be added.
 */
function World::InsertIndustry(industryID) {

	local industryNode = IndustryConnectionNode(industryID, niceCABEnabled);
	
	// Make sure this industry hasn't already been added.
	//if (!industry_table.rawin(industryID))
		industry_table[industryID] <- industryNode;
	//else
	//	assert(false);

	local hasBilateral = false;
	local isPrimaryIndustry = false;

	// We want to preprocess all industries which can be built near water.
	local isNearWater = industryNode.isNearWater;
	local stationRadius = AIStation.GetCoverageRadius(AIStation.STATION_DOCK);
	local ignoreProducersList = {};
	local ignoreAccepterssList = {};
	
	// Check which cargo is accepted.
	foreach (cargo, value in cargo_list) {
		
		local acceptsCargo = AIIndustry.IsCargoAccepted(industryID, cargo);
		local producesCargo = AIIndustry.GetLastMonthProduction(industryID, cargo) != -1;
		local isBilateral =  acceptsCargo && producesCargo;
		if (isBilateral)
			hasBilateral = true;
		if (!isPrimaryIndustry)
			isPrimaryIndustry = AIIndustryType.IsRawIndustry(AIIndustry.GetIndustryType(industryID));

		if (producesCargo) {
			
			// Save production information.
			industryNode.cargoIdsProducing.push(cargo);

			// Add to cache.
			industryCacheProducing[cargo].push(industryNode);

			// Check for accepting industries for these products.
			foreach (cachedIndustry in industryCacheAccepting[cargo]) {

				// Make sure we don't add industries twice!
				if (ignoreProducersList.rawin(cachedIndustry)) continue;
				
				ignoreProducersList[cachedIndustry] <- null;
				industryNode.connectionNodeList.push(cachedIndustry);
				if (isBilateral)
					cachedIndustry.connectionNodeListReversed.push(industryNode);
			}
		}

		// Check if the industry actually accepts something.
		if (acceptsCargo) {
			industryNode.cargoIdsAccepting.push(cargo);

			// Add to cache.
			industryCacheAccepting[cargo].push(industryNode);

			// Check if there are producing plants which this industry accepts.
			if (!isBilateral) {
				foreach (cachedIndustry in industryCacheProducing[cargo]) {
					
					// Make sure we don't add industries twice!
					if (ignoreAccepterssList.rawin(cachedIndustry)) continue;

					ignoreAccepterssList[cachedIndustry] <- null;
					cachedIndustry.connectionNodeList.push(industryNode);
					industryNode.connectionNodeListReversed.push(cachedIndustry);
				}
			}
		}

		// Check if this industry is near to water.
		if ((acceptsCargo || producesCargo) && !isNearWater) {
			if (AIIndustry.IsBuiltOnWater(industryNode.id))
				industryNode.isNearWater = true;
			else {
				local industryTiles = acceptsCargo ? industryNode.GetAcceptingTiles(cargo, stationRadius, 1, 1) : industryNode.GetProducingTiles(cargo, stationRadius, 1, 1);
				industryTiles.Valuate(AITile.IsCoastTile);
				industryTiles.KeepValue(1);
				if (industryTiles.Count() > 0)
					industryNode.isNearWater = true;
			}
			isNearWater = true;
		}
	}

	// If the industry doesn't accept anything we add it to the root list.
	if (industryNode.cargoIdsAccepting.len() == 0 || industryNode.cargoIdsProducing.len() > 0 || hasBilateral || isPrimaryIndustry)
		industry_tree.push(industryNode);
}

/**
 * Remove an industryNode from the industryList.
 * @industryID The id of the industry which needs to be removed.
 */
function World::RemoveIndustry(industryID) {
	
	
	if (!industry_table.rawin(industryID)) {
		Log.logWarning("Industry removed which wasn't in our tree!");
		//assert(false);
		return null;
	}
	
	local industryNode = industry_table.rawget(industryID);
	
	// Remove the industry from the caches.
	foreach (cargo in industryNode.cargoIdsProducing) {
		for (local i = 0; i < industryCacheProducing[cargo].len(); i++) {
			if (industryCacheProducing[cargo][i].id == industryNode.id) {
				industryCacheProducing[cargo].remove(i);
				break;
			}
		}
	}
	
	foreach (cargo in industryNode.cargoIdsAccepting) {
		for (local i = 0; i < industryCacheAccepting[cargo].len(); i++) {
			if (industryCacheAccepting[cargo][i].id == industryNode.id) {
				industryCacheAccepting[cargo].remove(i);
				break;
			}
		}
	}
	
	// Remove the industry from the root list (if it's there).
	if (industryNode.cargoIdsAccepting.len() == 0) {
		for (local i = 0; i < industry_tree.len(); i++) {
			if (industry_tree[i].id == industryNode.id) {
				industry_tree.remove(i);
				break;
			}
		}
	}
	
	// Now we need to remove this industry from all industry nodes which produces
	// cargo this industry used to accept.
	
	// We add all connection to demolish in a tupple, because if we call the Demolish
	// function it will remove an element from the array and this will screw up the
	// iterators below resulting in a run-time error. After all connections which must
	// be destroyed are identified they will be demolished out side the iterators.
	local toDemolishList = [];
	foreach (connection in industryNode.reverseActiveConnections)
		// Remove all connections which are already built!
		foreach (fromConnnection in connection.travelFromNode.activeConnections)
			if (fromConnnection.travelToNode == industryNode)
				toDemolishList.push([fromConnnection, true]);
	
	// Remove all connections which are already built!
	foreach (connection in industryNode.activeConnections) {
		// If there are more connections dropping cargo off at
		// the end destination, we don't destroy those road stations!
		local demolishDestinationRoadStations = true;
		if (connection.vehicleTypes == AIVehicle.VT_ROAD && 
			connection.travelToNode.reverseActiveConnections.len() > 1)
			demolishDestinationRoadStations = false;

		toDemolishList.push([connection, demolishDestinationRoadStations]);
	}

	foreach (connectionTuple in toDemolishList)
		connectionTuple[0].Demolish(true, connectionTuple[1], false);

	industry_table.rawdelete(industryID);
	industryNode.isInvalid = true;
	return industryNode;
}

/**
 * Handle the event where an industry is opened in the world. We add it to
 * the data structures and return the stored node.
 * @param industryID The new industry ID.
 * @return The stored industry node.
 */
function World::ProcessIndustryOpenedEvent(industryID) {
	// We don't want more than MAX_INDUSTRIES industries or we might run out of memory.
	if (industry_table.len() >= MAX_INDUSTRIES)
		return null;

		Log.logInfo("New industry: " + AIIndustry.GetName(industryID) + " added to the world!");
	InsertIndustry(industryID);
	return industry_table[industryID];
}			

/**
 * Handle the event where an industry is closed in the world. We remove it from
 * the data structures and return the deleted node.
 * @param industryID The removed industry ID.
 * @return The removed industry node.
 */
function World::ProcessIndustryClosedEvent(industryID) {
	Log.logInfo("Industry: " + AIIndustry.GetName(industryID) + " removed from the world!");
	return RemoveIndustry(industryID);
}

/**
 * Debug purposes only.
 */
function World::PrintTree() {
	Log.logDebug("PrintTree");
	foreach (primIndustry in industry_tree) {
		PrintNode(primIndustry, 0);
	}
	Log.logDebug("Done!");
}

function World::PrintNode(node, depth) {
	local string = "";
	for (local i = 0; i < depth; i++) {
		string += "      ";
	}

	Log.logDebug(string + node.GetName() + " -> ");

	foreach (transport in node.connections) {
		Log.logDebug("Vehcile travel time: " + transport.timeToTravelTo);
		Log.logDebug("Cargo: " + AICargo.GetCargoLabel(transport.cargoID));
		Log.logDebug("Cost: " + node.costToBuild);
	}
	foreach (iNode in node.connectionNodeList)
		PrintNode(iNode, depth + 1);
}	


