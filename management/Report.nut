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
	
	actions = null;						// The list of actions.
	brutoIncomePerMonth = 0;			// The bruto income per month which is invariant of the number of vehicles.
	brutoCostPerMonth = 0;				// The bruto cost per month which is invariant of the number of vehicles.
	initialCost = 0;					// Initial cost, which is only paid once!
	runningTimeBeforeReplacement = 0;	// The running time in which profit can be made.
	
	brutoIncomePerMonthPerVehicle = 0;	// The bruto income per month per vehicle.
	brutoCostPerMonthPerVehicle = 0;	// The bruto cost per month per vehicle.
	initialCostPerVehicle = 0;			// The initial cost per vehicle which is only paid once!
	nrVehicles = 0;						// The total number of vehicles.
	
	/**
	 * The utility for a report is the netto profit per month times
 	 * the actual number of months over which this netto profit is 
 	 * gained!
	 */
	function Utility() {
		local totalBrutoIncomePerMonth = brutoIncomePerMonth + (nrVehicles < 0 ? 0 : nrVehicles * brutoIncomePerMonthPerVehicle);
		local totalBrutoCostPerMonth = brutoCostPerMonth + (nrVehicles < 0 ? 0 : nrVehicles * brutoCostPerMonthPerVehicle);
		local totalInitialCost = initialCost + nrVehicles * initialCostPerVehicle; 
		return (totalBrutoIncomePerMonth - totalBrutoCostPerMonth) * runningTimeBeforeReplacement - totalInitialCost;
	}
	
	/**
	 * This utility function is called by the parlement to check what the utility is
	 * if the money available is restricted to 'money'.
	 * @param The money to spend, if this value is -1 we have unlimited money to spend.
	 * @return the net income per month for the money to spend.
	 */
	function UtilityForMoney(money) {
		if (money == -1)
			return Utility();
		
		// Now calculate the new utility based on the number of vehicles we can buy.
		local oldNrVehicles = nrVehicles;
		nrVehicles = GetNrVehicles(money);
		local utility = Utility();
		
		// Restore values.
		nrVehicles = oldNrVehicles;
		
		// Return the utility;
		return utility;
	}
	
	/**
	 * Get the number of vehicles we can buy given the amount of money.
	 * @param money The money to spend, if this value is -1 we have unlimited money to spend.
	 * @return The maximum number of vehicles we can buy for this money.
	 */
	function GetNrVehicles(money) {
		if (nrVehicles < 0)
			return nrVehicles;
		money -= initialCost;
		

		// For the remainder of the money calculate the number of vehicles we could buy.
		local vehiclesToBuy = (money / initialCostPerVehicle).tointeger();
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
			
		local maxNrVehicles = GetNrVehicles(money);
		return initialCost + initialCostPerVehicle * maxNrVehicles;
	}
	
	function ToString() {
		return "Bruto income: " + brutoIncomePerMonth + "; BrutoCost: " + brutoCostPerMonth + "; Running time: " + runningTimeBeforeReplacement + "; Init cost: " + initialCost + ".";
	}
}
