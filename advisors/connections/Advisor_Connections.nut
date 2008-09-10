import("queue.binary_heap", "BinaryHeap", 1);

/**
 * Build economy tree with primary economies which require no input
 * to produce on the root level, secundary economies which require
 * input from primary industries as children and so on. The max 
 * depth in OpenTTD is 4;
 *
 * Grain                              }
 * Iron ore        -> Steel           }-> Goods  -> Town
 * Livestock                          }
 */
class ConnectionAdvisor extends Advisor
{
	world = null;				// Pointer to the World class.
	connectionReports = null;
		
	constructor(world)
	{
		this.world = world;
		connectionReports = BinaryHeap();
		
		UpdateIndustryConnections();
	}
	
	/**
	 * Check which set of industry connections yield the highest profit.
	 */
	function getReports();

	/**
	 * Iterate through the industry tree and update its information.
	 */
	function UpdateIndustryConnections();
	
	/**
	 * Debug purposes only:
	 * Print the constructed industry node.
	 */
	function PrintTree();
	
	/**
	 * Debug purposes only:
	 * Print a single node in the industry tree.
	 */
	function PrintNode();
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function ConnectionAdvisor::getReports()
{
	// The report list to construct.
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
	
	// The number of connections which we've compared.
	local comparedConnections = 0;
	
	// Check how much we have to spend:
	local money = AICompany.GetBankBalance(AICompany.MY_COMPANY);
	
	// Hold a cache of possible connections.
	local connectionCache = BinaryHeap();

	// Try to get the best subset of options.
	local report;
	while ((report = connectionReports.Pop()) != null) {

		/**
		 * Do an aditional check to prevent this piece of code to check all possible 
		 * connections and just check a reasonable number until we've spend enough
		 * money or till we've spend enough time in this function.
		 */
		if (comparedConnections > 10 && connectionCache.Count() > 0 ||	// We've compared at least 10 connections and found at leat 1 report
		money < 20000 && comparedConnections > 15 || // We've compared at leats 15 connections and we're low on money 
		comparedConnections > 20) {	// We've compared at least 20 connections.
			break;
		}
		
		comparedConnections++;

		// If the report is already fully calculated, check if we can afford it and execute it!
		if (report.cost != 0 && report.cost < money) {

			local otherConnection = report.fromConnectionNode.GetConnection(report.toConnectionNode);
			if (otherConnection != null && otherConnection.build == true) {
				// Check if we need to add / remove vehicles to this connection.

			} else {
				
				connectionCache.Insert(report, -report.Utility());
				// The cost has already been calculated, so we can build it immediatly.
				report.print();
				money -= report.cost;
			}
		} else if (report.cost == 0) {

			// The actionlist to construct.
			local actionList = [];

			// If we haven't calculated yet what it cost to build this report, we do it now.
			local pathfinder = RoadPathFinding();
			local pathList = pathfinder.FindFastestRoad(report.fromConnectionNode.GetProducingTiles(), report.toConnectionNode.GetAcceptingTiles());

			if (pathList == null) {
				Log.logError("No path found from " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName());
				continue;
			}
			// Now we know the prices, check how many vehicles we can build and what the actual income per vehicle is.
			local timeToTravelTo = pathfinder.GetTime(pathList.roadList, AIEngine.GetMaxSpeed(report.engineID), true);
			local timeToTravelFrom = pathfinder.GetTime(pathList.roadList, AIEngine.GetMaxSpeed(report.engineID), false);

			// Calculate bruto income per vehicle per run.
			local incomePerRun = AICargo.GetCargoIncome(report.cargoID, 
				AIMap.DistanceManhattan(pathList.roadList[0].tile, pathList.roadList[pathList.roadList.len() - 1].tile), 
				timeToTravelTo) * AIEngine.GetCapacity(report.engineID);


			// Calculate netto income per vehicle.
			local incomePerVehicle = incomePerRun - ((timeToTravelTo + timeToTravelFrom) * AIEngine.GetRunningCost(report.engineID) / 364);

			local productionPerMonth;
			// Calculate the number of vehicles which can operate:
			for (local i = 0; i < report.fromConnectionNode.cargoIdsProducing.len(); i++) {

				if (report.cargoID == report.fromConnectionNode.cargoIdsProducing[i]) {
					productionPerMonth = report.fromConnectionNode.cargoProducing[i];
					break;
				}
			}

			local transportedCargoPerVehiclePerMonth = (30.0 / (timeToTravelTo + timeToTravelFrom)) * AIEngine.GetCapacity(report.engineID);
			report.nrVehicles = productionPerMonth / transportedCargoPerVehiclePerMonth;

			// Calculate the profit per month per vehicle
			report.profitPerMonthPerVehicle = incomePerVehicle * (30.0 / (timeToTravelTo + timeToTravelFrom));
			report.cost = pathfinder.GetCostForRoad(pathList) + report.nrVehicles * AIEngine.GetPrice(report.engineID);

			// If we can afford it, add it to the possible connection list.
			if (report.cost < money) {
				connectionCache.Insert(report, -report.Utility());
				
				// Check if the industry connection node actually exists else create it, and update it!
				local connectionNode = report.fromConnectionNode.GetConnection(report.toConnectionNode);
				if (connectionNode == null) {
					connectionNode = Connection(report.fromConnectionNode, report.toConnectionNode, Connection.INDUSTRY_TO_INDUSTRY);
					report.fromConnectionNode.AddConnection(report.toConnectionNode, connectionNode);
				}
				
				connectionNode.pathInfo = pathList;
			}
		}
	}
	
	// We have a list with possible connections we can afford, we now apply
	// a subsum algorithm to get the best profit possible with the given money.
	local reports = [];
	
	foreach (report in SubSum.GetSubSum(connectionCache, money)) {
		local actionList = [];
			
		// The industryConnectionNode gives us the actual connection.
		local connectionNode = report.fromConnectionNode.GetConnection(report.toConnectionNode);

		// Give the action to build the road.
		actionList.push(BuildRoadAction(connectionNode, true, true));
			
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();
		vehicleAction.BuyVehicles(report.engineID, report.nrVehicles, connectionNode.pathInfo);
		vehicleAction.AddActionHandlerFunction(ConnectionManageVehiclesActionHandler(connectionNode));
		actionList.push(vehicleAction);

		// Create a report and store it!
		reports.push(Report(report.ToString(), report.cost, report.Profit(), actionList));		
	}
	
	return reports;
}

function ConnectionAdvisor::UpdateIndustryConnections() {
	world.UpdateCargoTransportEngineIds();

	// Upon initialisation we look at all possible connections in the world and try to
	// find the most prommising once in terms of cost to build to profit ratio. We can't
	// however get perfect information by calculating all possible routes as that will take
	// us way to much time.
	//
	// Therefore we try to get an indication by taking the Manhattan distance between two
	// industries and see what the profit would be if we would be able to build a straight
	// road and let and vehicle operate on it.
	//
	// The next step would be to look at the most prommising connection nodes and do some
	// actual pathfinding on that selection to find the best one(s).
	foreach (primIndustryConnectionNode in world.industry_tree) {

		foreach (secondConnectionNode in primIndustryConnectionNode.connectionNodeList) {

			// Check if this connection already exists.
			local connection = primIndustryConnectionNode.GetConnection(secondConnectionNode); 
			if (connection != null) {

				// See if we need to add or remove some vehicles.

			} else {
				local manhattanDistance = AIMap.DistanceManhattan(primIndustryConnectionNode.GetLocation(), secondConnectionNode.GetLocation());

				// Take a guess at the travel time and profit for each cargo type.
				foreach (cargo in primIndustryConnectionNode.cargoIdsProducing) {

					local maxSpeed = AIEngine.GetMaxSpeed(world.cargoTransportEngineIds[cargo]);
					local travelTime = manhattanDistance * RoadPathFinding.straightRoadLength / maxSpeed;
					local incomePerRun = AICargo.GetCargoIncome(cargo, manhattanDistance, travelTime.tointeger()) * AIEngine.GetCapacity(world.cargoTransportEngineIds[cargo]);

					local report = ConnectionReport();
					report.profitPerMonthPerVehicle = (30.0 / travelTime) * incomePerRun;
					report.engineID = world.cargoTransportEngineIds[cargo];
					report.fromConnectionNode = primIndustryConnectionNode;
					report.toConnectionNode = secondConnectionNode;
					report.cargoID = cargo;

					connectionReports.Insert(report, -report.profitPerMonthPerVehicle);
				}
			}
		}
	}
}


/**
 * Debug purposes only.
 */
function ConnectionAdvisor::PrintTree() {
	Log.logDebug("PrintTree");
	foreach (primIndustry in industry_tree) {
		PrintNode(primIndustry, 0);
	}
	Log.logDebug("Done!");
}

function ConnectionAdvisor::PrintNode(node, depth) {
	local string = "";
	for (local i = 0; i < depth; i++) {
		string += "      ";
	}

	Log.logDebug(string + AIIndustry.GetName(node.industryID) + " -> ");

	foreach (transport in node.industryConnections) {
		Log.logDebug("Vehcile travel time: " + transport.timeToTravelTo);
		Log.logDebug("Cargo: " + AICargo.GetCargoLabel(transport.cargoID));
		Log.logDebug("Cost: " + node.costToBuild);
	}
	foreach (iNode in node.industryNodeList)
		PrintNode(iNode, depth + 1);
}	



