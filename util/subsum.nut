/**
 * Subsum algorithm.
 */
 class SubSum 
 {
	static function init(reportlist, moneyToSpend) {
		local sortedReports = BinaryHeap();
		// Sort all the reports based on their utility.
		foreach (report in reportlist) {
			
			local utility = report.UtilityForMoney(moneyToSpend);
			Log.logDebug(utility + " for " + report.ToString());
			// Only add when whe think that they will be profitable in the end.
			// Don't look for things if they are to expensive.
			if(utility > 0)
				sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 + utility : -utility));
		}
		
		return sortedReports;
	}

	static function orderReports(reportlist, moneyToSpend) {
		local sortedReports = BinaryHeap();
		// Sort all the reports based on their utility.
		foreach (entry in reportlist._queue) {
			
			local report = entry[0];
			
			local utility = report.UtilityForMoney(moneyToSpend);
			Log.logDebug(utility + " for " + report.ToString());
			// Only add when whe think that they will be profitable in the end.
			// Don't look for things if they are to expensive.
			if(utility > 0)
				sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 + utility : -utility));
		}
		
		return sortedReports;
	}

	static function GetGreedySubSum(reportlist, moneyToSpend) {
 		local report = null;
 		local subsumList = [];
		local totalUtility = 0;
 		
 		local reports = SubSum.init(reportlist, moneyToSpend);
 		
		while ((report = reports.Pop()) != null) {
			
			// Check if we can afford it, but always include update reports.
			local cost = report.GetCost(moneyToSpend);
			local utility = report.UtilityForMoney(moneyToSpend);
			
			if (moneyToSpend >= cost && utility > 0 || report.connection.pathInfo.build) {
				subsumList.push(report);

				if (report.nrVehicles > 0)
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
		Log.logWarning("Get random sub sub with a minimum utilty of: " + min_utility + " len: " + reportlist.len());

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
				if ((moneyToSpend >= (costs = report.GetCost(moneyToSpend)) || report.connection.pathInfo.build) && utility_for_money > 0) {
					tmp_subsumList.push(report);

					if (report.nrVehicles > 0)
						utility += utility_for_money;
					moneyToSpend -= costs;
					sortedReports.Insert(report, (report.nrVehicles < 0 ? -2147483647 + utility_for_money : -utility_for_money));
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

 	static function GetSubSum(reportList) {

		local reportListClone = [];
		reportListClone.extend(reportList);

 		local moneyToSpend = Finance.GetMaxMoneyToSpend();
		local maxLoan = AICompany.GetMaxLoanAmount() * 0.8;

		local mandantoryReports = [];

		local constructionAllowed = maxLoan < moneyToSpend;

		// Allow the construction of new connections if we can afford the best connection returned by the subsum.
		if (!constructionAllowed) {
	 		local greedySubSum = SubSum.GetGreedySubSum(reportList, maxLoan);


			local testList = SubSum.GetGreedySubSum(reportList, maxLoan);
			local firstBuildReport = null;
			foreach (report in testList[0]) {
				if (report.connection != null && !report.connection.pathInfo.build) {
					firstBuildReport = report;
					break;
				}
			}

			if (firstBuildReport != null && firstBuildReport.UtilityForMoney(moneyToSpend) > 0)
				constructionAllowed = true;
		}

		// Filter the results.
		for (local i = reportListClone.len() - 1; i > -1; i--)
		{
			// Do not include reports which build a connection if we do not have enough money.
			if ((reportList[i].connection == null || !reportList[i].connection.pathInfo.build) && !constructionAllowed) {
				reportListClone.remove(i);
				continue;
			}

			// Do not include reports which have been put in the ignore list.
			local deleted = false;
			for (local j = 0; j < ignoreList.len(); j++)
			{
				if (ignoreList[j] == reportListClone[i]) {
					reportListClone.remove(i);
					deleted = true;
					break;
				}
			}
			if (deleted)
				continue;

			// Keep reports which sell vehicles in a separate list, these reports will be included anyways.
			if (reportListClone[i].nrVehicles < 0) {
				mandantoryReports.push(reportList[i]);
				reportListClone.remove(i);
				continue;
			}

			// Do not include reports with 0 or negative utility.
			if (reportListClone[i].UtilityForMoney(moneyToSpend) <= 0) {
				reportListClone.remove(i);
				continue;
			}
		}

		if (reportListClone.len() == 0)
			return mandantoryReports;
		
		local currentBestSubSum = SubSum.GetLimitedSubSum(reportListClone, moneyToSpend);

		local forecast = 3;
		
		// Project the expected money to make in the next year and check if it is better to wait.
		local incomePerMonth = Finance.GetProjectedIncomePerMonth();
		local futureBestSubSum = SubSum.GetLimitedSubSum(reportListClone, moneyToSpend + forecast * incomePerMonth);

		Log.logWarning("Current income per month: " + incomePerMonth);
		
		// Check which one is the best.
		// If the current sub sum is better than the future one we're done!
		if (currentBestSubSum[1] >= futureBestSubSum[1]) {
			Log.logWarning("- Current and Future subsums are the same; Return the current sub sum!");
			currentBestSubSum[0].extend(mandantoryReports);
			return currentBestSubSum[0];
		}
		
		//local currentIncomePerMonth = SubSum.GetIncomePerMonth(currentBestSubSum[0], [], moneyToSpend);
		local currentIncomePerMonth = 0;
		local availableMoney = moneyToSpend;
		foreach (report in currentBestSubSum[0]) {
			currentIncomePerMonth += report.NettoIncomePerMonthForMoney(availableMoney, forecast);
			availableMoney -= report.GetCost(availableMoney);
			Log.logWarning(report.ToString());
		}
		Log.logWarning("Current best subsum! " + currentIncomePerMonth);

		//local currentIncomePerMonth = SubSum.GetIncomePerMonth(futureBestSubSum[0], [], moneyToSpend + forecast * incomePerMonth);
		local futureIncomePerMonth = 0;
		availableMoney = moneyToSpend + forecast * incomePerMonth;
		foreach (report in futureBestSubSum[0]) {
			futureIncomePerMonth += report.NettoIncomePerMonthForMoney(availableMoney, forecast);
			availableMoney -= report.GetCost(availableMoney);
			Log.logWarning(report.ToString());
		}
		Log.logWarning("Future best subsum! " + futureIncomePerMonth);

		// Calculate how long till the future best sub sum will break even, given the current best sub sum's
		// ahead start of forecast months.
		local delta =  (currentIncomePerMonth + incomePerMonth) - (futureIncomePerMonth + incomePerMonth);
		local breakEven = (forecast * incomePerMonth - forecast * (futureIncomePerMonth + incomePerMonth)) / delta;
		
		Log.logWarning("Break even point: " + breakEven + " months");

		// Given that we go with the currentBestSubSum: Calculate the money we would earn before the break even point.
		local moneyMadeTillBreakEven = breakEven * (incomePerMonth + currentIncomePerMonth);
		Log.logWarning("Money made till break even: " + moneyMadeTillBreakEven);

		// Check what connections we can build with this money. If the total income per month is higher than what
		// we would gain by just waiting go with the current report.
		local spinoffIncomePerMonth = SubSum.GetIncomePerMonth(reportListClone, currentBestSubSum[0], moneyMadeTillBreakEven);
		Log.logWarning("Spinoff income per month: " + spinoffIncomePerMonth);

		// Similarly for the connections we can build after /forecast/ months. The money made between construction and
		// the break even point is used to check what can be build at that point in time.
		local futureMoneyTillBreakEven = (breakEven - forecast) * (incomePerMonth + futureIncomePerMonth);
		local spinoffFutureIncomePerMonth = SubSum.GetIncomePerMonth(reportListClone, futureBestSubSum[0], futureMoneyTillBreakEven);
		Log.logWarning("Future spinoff income per month: " + spinoffFutureIncomePerMonth);

		// If the gradient of the function corresponding with the income per month generated by the reports we can currently build +
		// the reports we will be able to build in the future provided by the income generated by the former reports is lower than
		// the gradient of those if we decide to wait than we postpone construction (except if the best reports are the same), 
		// otherwise we decide to build now. 
		local bestSubSumList = [];
		if (spinoffIncomePerMonth + currentIncomePerMonth < futureIncomePerMonth + spinoffFutureIncomePerMonth) {
			
			Log.logWarning("- Return the future sub sum and return the common reports!");
			foreach (futureReport in futureBestSubSum[0]) {
				local found = false;
				foreach (currentReport in currentBestSubSum[0]) {
					if (currentReport == futureReport) {
						bestSubSumList.push(futureReport);
						found = true;
						break;
					}
				}
				if (!found)
					break;
			}

		} else {
			bestSubSumList = currentBestSubSum[0];
			Log.logWarning("- Return the current sub sum!");
		}
		
 		bestSubSumList.extend(mandantoryReports);
 		return bestSubSumList;
 	}
 	
 	static function GetIncomePerMonth(reportList, closedReportList, moneyToSpend) {
		// Check what connections we can build with this money. If the total income per month is higher than what
		// we would gain by just waiting go with the current report.
		local reportListClone;
		
		if (closedReportList.len() > 0) {
			reportListClone = [];
			reportListClone.extend(reportList);
	
			// Remove those reports which we are already going to build.
			for (local i = reportListClone.len() - 1; i > -1; i--) {
				foreach (report in closedReportList) {
					if (report == reportListClone[i]) {
						reportListClone.remove(i);
						break;
					}
				}
			}
		} else {
			reportListClone = reportList;
		}

		local bestSubSet = SubSum.GetLimitedSubSum(reportListClone, moneyToSpend);
		local incomePerMonth = 0;
		local availableMoney = moneyToSpend;
		foreach (report in bestSubSet[0]) {
			incomePerMonth += report.NettoIncomePerMonthForMoney(availableMoney, 0);
			availableMoney -= report.GetCost(availableMoney);
			Log.logWarning(report.ToString());
		}
		return incomePerMonth;
 	}
 	
 	static function GetLimitedSubSum(reportList, moneyToSpend) {
				
 		local greedySubSum = SubSum.GetGreedySubSum(reportList, moneyToSpend);
		local subsumList = greedySubSum[0];
		local greedyUtility = greedySubSum[1];

		// We now have the utility using the greedy approach, try to find a better solution.
		if (reportList.len() > reportList.len()) {
			local randomSubSum = SubSum.GetRandomSubSum(reportList, greedyUtility);
			local randomSubSumList = randomSubSum[0];
			local randomUtility = randomSubSum[1];

			if (randomSubSumList.len() != 0) {
//				Log.logWarning("Return random subsum! " + greedyUtility + " < " + randomUtility);
//				Log.logWarning("Greedy:");
//				foreach (report in reportList) {
//					Log.logWarning(report.ToString());
//				}

//				Log.logWarning("Random:");
//				foreach (report in randomSubSumList) {
//					Log.logWarning(report.ToString());
//				}

//				randomSubSumList.extend(sellVehiclesReports);
				return randomSubSum;
			}
		}

//		Log.logWarning("Return greedy subsum!");
		return greedySubSum;
 	}
 }
