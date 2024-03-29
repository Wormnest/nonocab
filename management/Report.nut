/**
 * This class is the base class for all reports which can be constructed and
 * presented to the Parlement for selection and execution. A report consists 
 * of a list of actions which must be executed if this reports is selecte for
 * execution. 
 *
 * All reports in this framework calculate their Utility as the netto profit
 * per month times the actual number of months over which this netto profit 
 * is gained!
 */
class Report
{
	
	actions = null;                           // The list of actions.
	brutoIncomePerMonth = 0;                  // The bruto income per month which is invariant of the number of vehicles.
	brutoCostPerMonth = 0;                    // The bruto cost per month which is invariant of the number of vehicles.
	initialCost = 0;                          // Initial cost, which is only paid once!
	runningTimeBeforeReplacementInMonths = 0; // The running time in which profit can be made.
	
	brutoIncomePerMonthPerVehicle = 0;         // The bruto income per month per vehicle.
	brutoCostPerMonthPerVehicle = 0;           // The bruto cost per month per vehicle.
	initialCostPerVehicle = 0;                 // The initial cost per vehicle which is only paid once!
	nrVehicles = 0;                            // The total number of vehicles.
	maxVehicles = 0;						   // The maximum number of vehicles this route can handle.
	nrWagonsPerVehicle = 0;                    // The number of wagons per vehicle we'll build.
	transportEngineID = 0;                     // The engine ID to transport the cargo.
	holdingEngineID = 0;                       // The engine ID to hold the cargo to be transported.
	                                   
	isInvalid = null;                          // If an error is found during the construction this value is set to true.
	connection = null;                         // The proposed connection.
	
	nrRoadStations = 0;                        // The number of road stations which need to be build on each side.
	
	upgradeToRailType = 0;                     // The rail type to upgrade an existing connection to (or null if not).
	loadingTime = 0;                           // The time it takes to load a vehicle.

	//world = 0;

	/**
	 * Construct a connection report.
	 * @param world The world.
	 * @param travelFromNode The connection node the connection comes from (the producing side).
	 * @param travelToNode The connection node the connection goes to (the accepting side).
	 * @param transportEngineID The engine which is used (or will be used) for transporting the cargo.
	 * @param holdingEngineID The engine which is used (or will be used) for holding the cargo.
	 * @param cargoAlreadyTransported The cargo which is already transpored.
	 */
	constructor(connection, transportEngineID, holdingEngineID, cargoAlreadyTransported) {

		this.transportEngineID = transportEngineID;
		this.holdingEngineID = holdingEngineID;
		this.connection = connection;
		isInvalid = false;
		upgradeToRailType = null;
		loadingTime = 0;
		
		// Check if the engine is valid.
		if ((transportEngineID == null) || !AIEngine.IsBuildable(transportEngineID) || !AIEngine.IsBuildable(holdingEngineID) ||
			connection.travelToNode.isInvalid || connection.travelFromNode.isInvalid) {
			isInvalid = true;
			return;
		}
		// Calculate the travel times for the prospected engine ID.
		local maxSpeed = AIEngine.GetMaxSpeed(transportEngineID);
		
		// Get the distances (real or estimated).
		//connection = travelFromNode.GetConnection(travelToNode, cargoID);
		assert (connection != null);
		local distance = AIMap.DistanceManhattan(connection.travelFromNode.GetLocation(), connection.travelToNode.GetLocation());
		if (distance < 0) {
			// Probably an industry disappeared
			isInvalid = true;
			return;
		}

		// Don't use a function call to get the same info again and again since I read somewhere Squirrel function calls can be quite slow.
		local veh_type = AIEngine.GetVehicleType(transportEngineID);
		/// @todo We should probably change the below if structure to a switch.
		if (veh_type == AIVehicle.VT_ROAD) {
			if (connection.pathInfo.roadList != null && connection.pathInfo.vehicleType == AIVehicle.VT_ROAD) {

				if (!connection.pathInfo.build)
					initialCost = PathBuilder(connection.pathInfo.roadList, AIEngine.GetMaxSpeed(transportEngineID)).GetCostForRoad();
			} else {
				/// @todo Instead of a guess of 3 * distance we could use that as initial value but
				/// @todo after building a few connections use the average cost for those.
				initialCost = AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_ROAD) * distance * 3 +
				              AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_DEPOT) +
				              AIRoad.GetBuildCost(AIRoad.ROADTYPE_ROAD, AIRoad.BT_TRUCK_STOP) * 2;
			}

			loadingTime = 0;
		} else if (veh_type == AIVehicle.VT_AIR) {
			if (!connection.pathInfo.build) {

				local isTowntoTown = connection.travelFromNode.nodeType == ConnectionNode.TOWN_NODE && connection.travelToNode.nodeType == ConnectionNode.TOWN_NODE;
				local costForFrom = BuildAirfieldAction.GetAirportCost(connection.travelFromNode, connection.cargoID, isTowntoTown ? true : false);
				local costForTo = BuildAirfieldAction.GetAirportCost(connection.travelToNode, connection.cargoID, true);

				if (costForFrom == -1 || costForTo == -1) {
					isInvalid = true;
					return;
				}
					
				initialCost = costForFrom + costForTo;
			}

			loadingTime = 17;
		} else if (veh_type == AIVehicle.VT_WATER) {
			if (connection.pathInfo.roadList != null && connection.pathInfo.vehicleType == AIVehicle.VT_WATER) {
				initialCost = WaterPathBuilder(connection.pathInfo.roadList).GetCostForRoad();
			}

			if (!connection.pathInfo.build)
				initialCost += BuildShipYardAction.GetCosts();

			// Docks can handle multiple ships so don't check for a maximum number we can handle.
			loadingTime = 0;
		} else if (veh_type == AIVehicle.VT_RAIL) {
			if (connection.pathInfo.roadList != null && connection.pathInfo.vehicleType == AIVehicle.VT_RAIL) {
				if (!connection.pathInfo.build) {
					/// @todo This will give incorrect values when we need to get the costs for the return.
					/// @todo Since we compute the costs for the other track that is already built then so no costs for that.
					initialCost = RailPathBuilder(connection.pathInfo.roadList, transportEngineID).GetCostForRoad(true) * 2;
				//	Log.logWarning("Initial cost (roadList not null): " + initialCost);
				}
			} else {
				local rail_type = TrainConnectionAdvisor.GetBestRailType(transportEngineID);
				if (rail_type == AIRail.RAILTYPE_INVALID) {
					Log.logWarning("No track available for vehicle type: " + AIEngine.GetVehicleType(transportEngineID) + ", Engine: " + AIEngine.GetName(transportEngineID));
					isInvalid = true;
					return;
				}
				// Note: building rail seems to get a lot of overhead costs: often we seem to build quite
				// long bridges and we terraform too sometimes. Thus we increase distance * 3 to distance * 4.
				initialCost = AIRail.GetBuildCost(rail_type, AIRail.BT_TRACK) * distance * 4 +
				              AIRail.GetBuildCost(rail_type, AIRail.BT_SIGNAL) * distance / 5 +
				              AIRail.GetBuildCost(rail_type, AIRail.BT_DEPOT) * 2 +
				              AIRail.GetBuildCost(rail_type, AIRail.BT_STATION) * 6 * 2;
				//Log.logWarning("Initial cost (roadList null): " + initialCost);
			}

			loadingTime = 12; /// @todo Check if we can find out the real loading time. Should also depend on whether we need to use depot every time or not!
		} else {
			Log.logError("Unknown vehicle type: " + AIEngine.GetVehicleType(transportEngineID) + ", Engine: " + AIEngine.GetName(transportEngineID));
			isInvalid = true;
			return;
		}
		InitializeReport(loadingTime, cargoAlreadyTransported, distance);
		
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL) {
			initialCostPerVehicle += AIEngine.GetPrice(holdingEngineID) * nrWagonsPerVehicle;
			// Check if the current rail type of this connection is such that the new
			// train cannot run on it.
			if (connection.pathInfo.build) {
				local railTypeOfConnection = AIRail.GetRailType(connection.pathInfo.depot);
				local foundRailTrack = -1;
				local l = AIRailTypeList();
				// The newest introduced rail types seem to come first
				foreach (railTypeOfTrain, index in l) {
					if (AIRail.IsRailTypeAvailable(railTypeOfTrain) && 
						AIEngine.CanRunOnRail(transportEngineID, railTypeOfTrain) &&
						AIEngine.HasPowerOnRail(transportEngineID, railTypeOfTrain) &&
						AIRail.GetMaxSpeed(railTypeOfTrain) > AIRail.GetMaxSpeed(foundRailTrack) && // Since newest railtypes are encountered first we don't use >= but >
						AIRail.TrainCanRunOnRail(railTypeOfConnection, railTypeOfTrain) &&
						AIRail.TrainHasPowerOnRail(railTypeOfConnection, railTypeOfTrain)) {
						foundRailTrack = railTypeOfTrain;
						//Log.logDebug("Rail upgrade: found track type " + AIRail.GetName(foundRailTrack));
					}
				}
				
				// Make sure we do not DOWNgrade the existing connection.
				if (foundRailTrack > railTypeOfConnection) {
					local upgradeCost = RailPathUpgradeAction.GetCostForUpgrade(connection, foundRailTrack);
					initialCost += upgradeCost;
					upgradeToRailType = foundRailTrack;
					Log.logDebug("Best upgrade rail type: " + AIRail.GetName(foundRailTrack) + " for engine " + AIEngine.GetName(transportEngineID) +
						", cost of upgrading: " + upgradeCost);
				}
				// Else, just build more trains :)
			}
		}
	}
	
	function InitializeReport(loadingTime, cargoAlreadyTransported, distance) {

		Log.logDebug("Report for " + connection.ToString() + " using engine " + AIEngine.GetName(transportEngineID));
		local travelTimeTo = connection.GetEstimatedTravelTime(transportEngineID, holdingEngineID, true);
		local travelTimeFrom = connection.GetEstimatedTravelTime(transportEngineID, holdingEngineID, false);
		
		if (travelTimeTo == null || travelTimeFrom == null) {
			Log.logDebug("Invalid estimation!");
			isInvalid = true;
			return;
		}
		
		Log.logDebug("Estimated travel time to: " + travelTimeTo + ", from: " + travelTimeFrom);
		local travelTime = travelTimeTo + travelTimeFrom;
		if (travelTime == 0) {
			Log.logError("Invalid travel time estimation for connection " + connection.ToString());
			isInvalid = true;
			return;
		}
		else if (travelTime > 300) {
			//Log.logWarning("Travel time too long for connection " + connection.ToString());
			isInvalid = true;
			return;
		}
		
		// Calculate netto income per vehicle.
		local transportedCargoPerVehiclePerMonth = (Date.DAYS_PER_MONTH.tofloat() / travelTime) * AIEngine.GetCapacity(holdingEngineID);
		
		// In case of trains, we have 5 wagons.
		/// @todo The engine itself can also have cargo capacity! Besides that number of wagons can be for if length(engine) == 2.
		nrWagonsPerVehicle = 5;
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL)
			transportedCargoPerVehiclePerMonth *= nrWagonsPerVehicle;
		
		//Log.logDebug("Transported cargo pvm: " + transportedCargoPerVehiclePerMonth);

		// For air transport we decrease expected cargo per month by 0.6 for goods and by 0.3 for anything except passengers/mail
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_AIR && AICargo.HasCargoClass(AIEngine.GetCargoType(holdingEngineID), AICargo.CC_PASSENGERS) && 
		    !AICargo.HasCargoClass(connection.cargoID, AICargo.CC_PASSENGERS) && !AICargo.HasCargoClass(connection.cargoID, AICargo.CC_MAIL)) {
			if (AICargo.GetTownEffect(connection.cargoID) == AICargo.TE_GOODS)
				transportedCargoPerVehiclePerMonth *= 0.6;
			else
				transportedCargoPerVehiclePerMonth *= 0.3;
		}
		nrVehicles = (connection.travelFromNode.GetProduction(connection.cargoID) - cargoAlreadyTransported).tofloat() / transportedCargoPerVehiclePerMonth;
		//Log.logDebug("nrVehicles float: " + nrVehicles);
		
		/// @todo For Air vehicles we should also check if airport can handle the required number of aircraft.

		// Testing for connection is null doesn't make sense here! If it was null we would have crashed already before we came here!
		// Maybe it should be connection.pathInfo == null
		if (nrVehicles > 0.75 && nrVehicles < 1 && (connection.pathInfo == null || connection.pathInfo.build))
			nrVehicles = 1;
		else
			nrVehicles = nrVehicles.tointeger();
		Log.logDebug("Estimated number of vehicles required: " + nrVehicles);
		brutoIncomePerMonth = 0;
		brutoIncomePerMonthPerVehicle = AICargo.GetCargoIncome(connection.cargoID, distance, travelTimeTo.tointeger()) * transportedCargoPerVehiclePerMonth;

		// In case of a bilateral connection we take a pessimistic take on the amount of 
		// vehicles supported by this connection, but we do increase the income by adding
		// the expected income of the other connection to the total.
		if (connection != null && connection.bilateralConnection || connection.travelToNode.nodeType == ConnectionNode.TOWN_NODE && connection.travelFromNode.nodeType == ConnectionNode.TOWN_NODE) {
			// Also calculate the route in the other direction.
			local nrVehiclesOtherDirection = ((connection.travelToNode.GetProduction(connection.cargoID) - cargoAlreadyTransported) / transportedCargoPerVehiclePerMonth).tointeger();

			if (nrVehiclesOtherDirection < nrVehicles)
				nrVehicles = nrVehiclesOtherDirection;

			brutoIncomePerMonthPerVehicle += AICargo.GetCargoIncome(connection.cargoID, distance, travelTimeFrom.tointeger()) * transportedCargoPerVehiclePerMonth;
		}

		// Calculate the maximum number of vehicles this line supports.
		if (loadingTime != 0) {
			maxVehicles = ((travelTimeTo + travelTimeFrom) / loadingTime).tointeger();
			// If this is an already existing route then keep at least 1 vehicle.
			// It may have changed to 0 because of introduction of a new faster vehicle but as long as it is making a profit that's ok.
			if (connection.pathInfo != null && connection.pathInfo.build && maxVehicles == 0)
				maxVehicles = 1;
			
			Log.logDebug("Maximum number of vehicles this route can handle: " + maxVehicles);
			if (nrVehicles > maxVehicles) {
				Log.logDebug("Reduced max nr. vehicles on line " + connection.travelFromNode.GetName() + " " + connection.travelToNode.GetName() + " from " + nrVehicles + " to " + maxVehicles + "{" + AICargo.GetCargoLabel(connection.cargoID));
				nrVehicles = maxVehicles;
			
				if (nrVehicles == 0)
					nrVehicles = 1;
			}
		}

		brutoCostPerMonth = 0;
		brutoCostPerMonthPerVehicle = AIEngine.GetRunningCost(transportEngineID) / Date.MONTHS_PER_YEAR;
		initialCostPerVehicle = AIEngine.GetPrice(transportEngineID);

		runningTimeBeforeReplacementInMonths = AIEngine.GetMaxAge(transportEngineID) / Date.DAYS_PER_MONTH;
	}
	
	function ToString() {
		local result = "";
		if (!connection.pathInfo.build)
			result = "build "
		result = result + "the connection " + connection.ToString();
		if (!connection.pathInfo.build) {
			result = result + ". Route cost: " + initialCost + ", 1 vehicle cost: " + initialCostPerVehicle;
		}

		if (nrRoadStations > 0) {
			// We want to add more road stations.
			result = result + ". Add " + nrRoadStations + " road stations";
		}
		if (upgradeToRailType != null) {
			// We want to upgrade the type of rail used.
			result = result + ". Upgrade rail type to " + AIRail.GetName(upgradeToRailType) + ", cost: " + initialCost;
		}

		local veh_result = "";
		if (nrVehicles > 0)
			veh_result = ". Add " + nrVehicles;
		else
			veh_result = ". Remove " + (-nrVehicles);
		
		if  (nrVehicles != 0)
			result = result + veh_result + " vehicles"

		return result +  ". Cost pm/v: " + brutoCostPerMonthPerVehicle + ". Income pm/v: " +
			brutoIncomePerMonthPerVehicle + ", " + Utility();
	}

	function NettoIncomePerMonthForMoney(money, forecast) {
		
		local oldNrVehicles = nrVehicles;
		if (GetNrVehicles(money, 0) == 0)
			nrVehicles = 0;
		else
			nrVehicles = GetNrVehicles(money, forecast);

		local maxBuildableVehicles = GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(transportEngineID));
		if (nrVehicles > maxBuildableVehicles)
			nrVehicles = maxBuildableVehicles;
		
		local nettoIncome = NettoIncomePerMonth();
		
		nrVehicles = oldNrVehicles;
		return nettoIncome;
	}
	
	function NettoIncomePerMonth() {
		if (runningTimeBeforeReplacementInMonths == 0)
			return 0;

		local maxBuildableVehicles = GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(transportEngineID));
		if (nrVehicles > maxBuildableVehicles)
			nrVehicles = maxBuildableVehicles;

		if (nrVehicles == 0)
			return 0;
			
		local subsidyMultiplier = 1;
		if (Subsidy.IsSubsidised(connection.travelFromNode, connection.travelToNode, connection.cargoID))
			subsidyMultiplier = GameSettings.GetSubsidyMultiplier();
		
		local initialCostPerVehiclePerMonth = initialCostPerVehicle / runningTimeBeforeReplacementInMonths;
		return brutoIncomePerMonth - brutoCostPerMonth + (brutoIncomePerMonthPerVehicle - brutoCostPerMonthPerVehicle - initialCostPerVehiclePerMonth) * nrVehicles;
	}
	
	function NettoIncomePerMonthForOneVehicle() {
		if (runningTimeBeforeReplacementInMonths == 0)
			return 0;

		local subsidyMultiplier = 1;
		if (Subsidy.IsSubsidised(connection.travelFromNode, connection.travelToNode, connection.cargoID))
			subsidyMultiplier = GameSettings.GetSubsidyMultiplier();
		
		local initialCostPerVehiclePerMonth = initialCostPerVehicle / runningTimeBeforeReplacementInMonths;
		return brutoIncomePerMonth - brutoCostPerMonth + (brutoIncomePerMonthPerVehicle - brutoCostPerMonthPerVehicle - initialCostPerVehiclePerMonth);
	}
	
	/**
	 * The utility for a report is the netto profit per month times
 	 * the actual number of months over which this netto profit is 
 	 * gained!
	 */
	function Utility() {
		if (nrVehicles < 0)
			return 2147483647;
		local vehicleType = AIEngine.GetVehicleType(transportEngineID);
		if (vehicleType == AIVehicle.VT_INVALID)
			return 0;
		return NettoIncomePerMonth();
	}

	function GetIncomePerVehicle(distance) {

		if (connection != null && connection.pathInfo.build)
			return 1;

		local capacity = AIEngine.GetCapacity(holdingEngineID);
		if (AIEngine.GetVehicleType(transportEngineID) == AIVehicle.VT_RAIL)
			capacity *= 5;
		local travel_time = distance * Tile.straightRoadLength / AIEngine.GetMaxSpeed(transportEngineID);
		local income = AICargo.GetCargoIncome(connection.cargoID, distance, travel_time.tointeger()) * capacity;
		local costs = AIEngine.GetRunningCost(transportEngineID) / Date.DAYS_PER_YEAR * travel_time;

		income -= costs;

		income /= distance;
		return income;
	}
	
	/**
	 * This utility function is called by the parlement to check what the utility is
	 * if the money available is restricted to 'money' and we take into account the
	 * maximum number of vehicles which can be build.
	 * @param The money to spend, if this value is -1 we have unlimited money to spend.
	 * @return the net income per month for the money to spend.
	 */
	function UtilityForMoney(money) {
		if (money == -1 || nrVehicles < 0)
			return Utility();

		// Now calculate the new utility based on the number of vehicles we can buy.
		local oldNrVehicles = nrVehicles;
		if (GetNrVehicles(money, 0) == 0)
			nrVehicles = 0;
		else
			nrVehicles = GetNrVehicles(money, 24);

		local maxBuildableVehicles = GameSettings.GetMaxBuildableVehicles(AIEngine.GetVehicleType(transportEngineID));
		if (nrVehicles > maxBuildableVehicles)
			nrVehicles = maxBuildableVehicles;
		local utility = Utility();
		
		// Restore values.
		nrVehicles = oldNrVehicles;
		
		// Return the utility;
		return utility;
	}
	
	/**
	 * Get the number of vehicles we can buy given the amount of money.
	 * @param money The money to spend, if this value is -1 we have unlimited money to spend.
	 * @forcast The number of months we want to look ahead. If we construct the construction now,
	 * how many vehicles will we be able to produce in the future? This only applies to unbuild
	 * connections.
	 * @return The maximum number of vehicles we can buy for this money.
	 */
	function GetNrVehicles(money, forecast) {
		if (nrVehicles < 0)
			return nrVehicles;
		money -= initialCost;

		// For the remainder of the money calculate the number of vehicles we could buy.
		if (initialCostPerVehicle == 0)
			return nrVehicles;
		local vehiclesToBuy = (money / initialCostPerVehicle).tointeger();

		// Add the revenue we make on the first {forecast} month(s) to this number.
		if (connection == null || !connection.pathInfo.build) {
			local revenue = (brutoIncomePerMonthPerVehicle - brutoCostPerMonthPerVehicle) * forecast * vehiclesToBuy;
			local extraVehiclesToBuy = (revenue / initialCostPerVehicle).tointeger();
			vehiclesToBuy += extraVehiclesToBuy;
		}
			
		if (vehiclesToBuy > nrVehicles)
			vehiclesToBuy = nrVehicles;

		return vehiclesToBuy;
	}
	
	/**
	 * Get the cost for executing this report given a certain amount of money.
	 * @param money The money to spend, if this value is -1 we have unlimited money to spend.
	 * @return The cost for executing this report given the amount of money.
	 */
	function GetCost(money) {
		if (money == -1)
			return initialCost + initialCostPerVehicle * nrVehicles;
			
		local maxNrVehicles = GetNrVehicles(money, 0);
		return initialCost + initialCostPerVehicle * maxNrVehicles;
	}
}
