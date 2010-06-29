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
/*			local skip = false;
			for (local i = 0; i < ignoreList.len(); i++)
				if (ignoreList[i] == report) {
					skip = true;
					break;
				}
				
			if (skip)
				continue;
*/
	
			local utility = report.UtilityForMoney(moneyToSpend);
			Log.logDebug(utility + " for " + report.ToString());
			// Only add when whe think that they will be profitable in the end.
			// Don't look for things if they are to expensive.
			if(utility > 0)
				sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 : -utility));
		}
		
		return sortedReports;
	}

	static function orderReports(reportlist, moneyToSpend) {
		local sortedReports = BinaryHeap();
		// Sort all the reports based on their utility.
		foreach (entry in reportlist._queue) {
			
			local report = entry[0];
			
/*
			// Check if the report isn't in the ignore list.
			local skip = false;
			for (local i = 0; i < ignoreList.len(); i++)
				if (ignoreList[i] == report) {
					skip = true;
					break;
				}
				
			if (skip)
				continue;
*/
	
			local utility = report.UtilityForMoney(moneyToSpend);
			Log.logDebug(utility + " for " + report.ToString());
			// Only add when whe think that they will be profitable in the end.
			// Don't look for things if they are to expensive.
			if(utility > 0)
				sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 : -utility));
		}
		
		return sortedReports;
	}

	static function GetGreedySubSum(reportlist) {
 		local report = null;
 		local subsumList = [];
 		local moneyToSpend = Finance.GetMaxMoneyToSpend();
		local totalUtility = 0;
 		
 		local reports = SubSum.init(reportlist, moneyToSpend);
 		
		while ((report = reports.Pop()) != null) {
			
			// Check if we can afford it, but always include update reports.
			local cost = report.GetCost(moneyToSpend);
			local utility = report.UtilityForMoney(moneyToSpend);
			
			if (moneyToSpend >= cost && utility > 0 || report.connection.pathInfo.build) {
				subsumList.push(report);
				totalUtility += utility;
				
				if (cost > 0)
					moneyToSpend -= cost;
			}
			
			// Reorder the reports if needed.
			if (reports.Peek() != null && reports.Peek().GetCost(-1) > moneyToSpend)
				reports = SubSum.orderReports(reports, moneyToSpend);
		}
 		return [subsumList, totalUtility];
	}

	/**
	 * Given the report list find for a combination of reports such that the utility
	 * will be higher than min_utility.
	 */
	static function GetRandomSubSum(reportlist, min_utility) {
		Log.logWarning("Get random sub sub with a maximum utilty of: " + min_utility + " len: " + reportlist.len());

		local startTicks = AIController.GetTick();
		local subsumList = [];
		local best_utility = min_utility;

		while (AIController.GetTick() - startTicks < 150) {

			local reportlist_clone = [];
			reportlist_clone.extend(reportlist);

			// Money we have available.
 			local moneyToSpend = Finance.GetMaxMoneyToSpend();

			// The utilty collected so far.
			local utility = 0;

			// The reports collected so far.
			local tmp_subsumList = [];

			// Order this list.
			local sortedReports = BinaryHeap();

			for (local i = reportlist_clone.len() - 1; i > -1; i--) {

				// Keep on picking randon reports and add them to the list.
				local random_number = AIBase.RandRange(reportlist_clone.len());
		 		local report = reportlist_clone[random_number];

				// To prevent this report from being picked multiple times we remove it.
				reportlist_clone.remove(random_number);

				local utility_for_money = report.UtilityForMoney(moneyToSpend);

				// Check if we can afford this report.
				local costs = report.GetCost(moneyToSpend);
				if (moneyToSpend >= (costs = report.GetCost(moneyToSpend)) && utility_for_money > 0 || report.connection.pathInfo.build) {
					tmp_subsumList.push(report);

					if (report.nrVehicles > 0)
						utility += utility_for_money;
					moneyToSpend -= costs;
					sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 : -utility_for_money));
				}
			}

			// Check if we found a better utility.
			if (best_utility < utility) {
				Log.logWarning("Replace " + best_utility + " with " + utility);
				best_utility = utility;
				subsumList.clear();

				while (sortedReports._count != 0) {
					subsumList.push(sortedReports.Pop());
				}
			}

		}

		Log.logWarning("Time's up!");

		return [subsumList, best_utility];
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
 	static function GetSubSum(reportlist_) {

		local reportlist = [];
		reportlist.extend(reportlist_);
		local constructionAllowed = Finance.ConstructionAllowed();

		for (local i = reportlist.len() - 1; i > -1; i--)
		{
			if (!constructionAllowed && !reportlist[i].connection.pathInfo.build)
			{
				reportlist.remove(i);
				continue;
			}

			for (local j = 0; j < ignoreList.len(); j++)
			{
				if (ignoreList[j] == reportlist[i]) {
					reportlist.remove(i);
					break;
				}
			}
		}
				
 		local greedySubSum = SubSum.GetGreedySubSum(reportlist);
		local subsumList = greedySubSum[0];
		local greedyUtility = greedySubSum[1];

		// We now have the utility using the greedy approach, try to find a better solution.
		local randomSubSum = SubSum.GetRandomSubSum(reportlist, greedyUtility);
		local randomSubSumList = randomSubSum[0];
		local randomUtility = randomSubSum[1];

		if (randomSubSumList.len() != 0) {
			Log.logWarning("Return random subsum! " + greedyUtility + " < " + randomUtility);
			Log.logWarning("Greedy:");
			foreach (report in subsumList) {
				Log.logWarning(report.ToString());
			}

			Log.logWarning("Random:");
			foreach (report in randomSubSumList) {
				Log.logWarning(report.ToString());
			}

			return randomSubSumList;
		}

		Log.logWarning("Return greedy subsum!");
 		return subsumList;
 	}
 }
