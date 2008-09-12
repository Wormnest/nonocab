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
		
	}
	
	/**
	 * Check which set of industry connections yield the highest profit.
	 */
	function getReports();

	/**
	 * Iterate through the industry tree and update its information.
	 * @industryTree An array with connectionNode instances.
	 */
	function UpdateIndustryConnections(industryTree);
}

/**
 * Construct a report by finding the largest subset of buildable infrastructure given
 * the amount of money available to us, which in turn yields the largest income.
 */
function ConnectionAdvisor::getReports()
{
	Log.logDebug("getReports()");
	connectionReports = BinaryHeap();
	UpdateIndustryConnections(world.industry_tree);

	// The report list to construct.
	local radius = AIStation.GetCoverageRadius(AIStation.STATION_TRUCK_STOP);
	
	// The number of connections which we've compared.
	local comparedConnections = 0;
	
	// Check how much we have to spend:
	local money = AICompany.GetBankBalance(AICompany.MY_COMPANY) + AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount();
	
	// Hold a cache of possible connections.
	local connectionCache = BinaryHeap();

	// Try to get the best subset of options.
	local report;
	
	
	local asfs = AITestMode();
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

		local otherConnection = report.fromConnectionNode.GetConnection(report.toConnectionNode);

		// Check if the connection has already been build.
		if (otherConnection != null && otherConnection.pathInfo.build == true) {
			// Check if we need to add / remove vehicles to this connection.


		} else {

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
			local costPerVehicle = AIEngine.GetPrice(report.engineID);
			local costForRoad = pathfinder.GetCostForRoad(pathList);
			local maxNrVehicles = productionPerMonth / transportedCargoPerVehiclePerMonth;
			
			if (costForRoad + costPerVehicle * maxNrVehicles > money) {
				maxNrVehicles = (money - costForRoad) / costPerVehicle;
			}
			
			// Check if we already have vehicles who transport this cargo and deduce it from 
			// the number of vehicles we need to build.
			foreach (connection in report.fromConnectionNode.connections) {
				if (connection.cargoID == report.cargoID) {
					maxNrVehicles -= connection.vehiclesOperating.vehicleIDs.len();
				}
			}
			
			// If we can't buy any vehicles, don't bother.
			if (maxNrVehicles.tointeger() <= 0) {
				Log.logDebug("To many vehicles already operating on " + report.fromConnectionNode.GetName() + "!");
				continue;
			}
			
			report.nrVehicles = maxNrVehicles;

			// Calculate the profit per month per vehicle
			report.profitPerMonthPerVehicle = incomePerVehicle * (30.0 / (timeToTravelTo + timeToTravelFrom));
			report.cost = costForRoad + costPerVehicle * maxNrVehicles;

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
		Log.logDebug("Report a connection from: " + report.fromConnectionNode.GetName() + " to " + report.toConnectionNode.GetName());
		local actionList = [];
			
		// The industryConnectionNode gives us the actual connection.
		local connectionNode = report.fromConnectionNode.GetConnection(report.toConnectionNode);

		// Give the action to build the road.
		actionList.push(BuildRoadAction(connectionNode, true, true));
			
		// Add the action to build the vehicles.
		local vehicleAction = ManageVehiclesAction();
		vehicleAction.BuyVehicles(report.engineID, report.nrVehicles, connectionNode);
		actionList.push(vehicleAction);

		// Create a report and store it!
		reports.push(Report(report.ToString(), report.cost, report.Profit(), actionList));
		break;	// Debug		
	}
	
	return reports;
}

function ConnectionAdvisor::UpdateIndustryConnections(industry_tree) {
	

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
	foreach (primIndustryConnectionNode in industry_tree) {

		foreach (secondConnectionNode in primIndustryConnectionNode.connectionNodeList) {

			// Check if this connection already exists.
			local connection = primIndustryConnectionNode.GetConnection(secondConnectionNode); 
			

			local manhattanDistance = AIMap.DistanceManhattan(primIndustryConnectionNode.GetLocation(), secondConnectionNode.GetLocation());
			// See if we need to add or remove some vehicles.
			// Take a guess at the travel time and profit for each cargo type.
			foreach (cargo in primIndustryConnectionNode.cargoIdsProducing) {

				local maxSpeed = AIEngine.GetMaxSpeed(world.cargoTransportEngineIds[cargo]);
				local travelTime = 0;
				if (connection != null && connection.pathInfo.build)
					travelTime = RoadPathFinding().GetTime(connection.pathInfo.roadList, maxSpeed, true);
				else 
					travelTime = manhattanDistance * RoadPathFinding.straightRoadLength / maxSpeed;
				local incomePerRun = AICargo.GetCargoIncome(cargo, manhattanDistance, travelTime.tointeger()) * AIEngine.GetCapacity(world.cargoTransportEngineIds[cargo]);

				local report = ConnectionReport();
				report.profitPerMonthPerVehicle = (30.0 / travelTime) * incomePerRun;
				report.engineID = world.cargoTransportEngineIds[cargo];
				report.fromConnectionNode = primIndustryConnectionNode;
				report.toConnectionNode = secondConnectionNode;
				report.cargoID = cargo;

				connectionReports.Insert(report, -report.profitPerMonthPerVehicle);
			}
				
			// Also check for other connection starting from this node.
			UpdateIndustryConnections(secondConnectionNode.connectionNodeList);
		}
	}
}

