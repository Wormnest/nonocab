/**
 * Subsum algorithm.
 */
 class SubSum 
 {
	static function init(reportlist, moneyToSpend) {
		local sortedReports = BinaryHeap();
		// Sort all the reports based on their utility.
		foreach (report in reportlist) {
			
			// Check if the report isn't in the ignore list.
			local skip = false;
			for (local i = 0; i < ignoreList.len(); i++)
				if (ignoreList[i] == report) {
					skip = true;
					break;
				}
				
			if (skip)
				continue;
	
			local utility = report.UtilityForMoney(moneyToSpend);
			Log.logDebug(utility + " for " + report.ToString());
			// Only add when whe think that they will be profitable in the end.
			// Don't look for things if they are to expensive.
			if(utility > 0)
				//sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 : -utility / (report.initialCost + report.utilityForMoneyNrVehicles * report.initialCostPerVehicle)));
				sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 : -utility));
		}
		
		return sortedReports;
	}

	static function orderReports(reportlist, moneyToSpend) {
		local sortedReports = BinaryHeap();
		// Sort all the reports based on their utility.
		foreach (entry in reportlist._queue) {
			
			local report = entry[0];
			
			// Check if the report isn't in the ignore list.
			local skip = false;
			for (local i = 0; i < ignoreList.len(); i++)
				if (ignoreList[i] == report) {
					skip = true;
					break;
				}
				
			if (skip)
				continue;
	
			local utility = report.UtilityForMoney(moneyToSpend);
			Log.logDebug(utility + " for " + report.ToString());
			// Only add when whe think that they will be profitable in the end.
			// Don't look for things if they are to expensive.
			if(utility > 0)
				//sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 : -utility / (report.initialCost + report.utilityForMoneyNrVehicles * report.initialCostPerVehicle)));
				sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 : -utility));
		}
		
		return sortedReports;
	}

 	/**
 	 * This function goes through the items in the list and tries to get the
 	 * best subsum from the list that yield the most profit but doesn't cost
 	 * more then max.
 	 * @param list A sorted data structure which has the following function:
 	 * Pop() which returns the item with the lowest value and removes it from
 	 * the data structure. The content of the list must be an instance of Report.
 	 * @param max The maximum cost all subsum values added together.
 	 * @return A list of reports which yield the maximum utility (or at least as
 	 * close as possible) and which costs doesn't exceed max.
 	 */
 	//static function GetSubSum(reportList, max) {
 	static function GetSubSum(reportlist) {
 		local report = null;
 		local subsumList = [];
 		local moneyToSpend = Finance.GetMaxMoneyToSpend();
 		
 		local reports = SubSum.init(reportlist, moneyToSpend);
 		
		while ((report = reports.Pop()) != null) {
			
			// Check if we can afford it, but always include update reports.
			local cost;
			if (moneyToSpend >= (cost = report.GetCost(moneyToSpend)) && report.UtilityForMoney(moneyToSpend) > 0 || report.connection.pathInfo.build) {
				subsumList.push(report);
				
				if (cost > 0)
					moneyToSpend -= cost;
			}
			
			// Reorder the reports if needed.
			if (reports.Peek() != null && reports.Peek().GetCost(-1) > moneyToSpend)
				reports = SubSum.orderReports(reports, moneyToSpend);
		}
 		return subsumList;
 	}
 }
