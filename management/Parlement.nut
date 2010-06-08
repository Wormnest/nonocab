import("queue.binary_heap", "BinaryHeap", 1);

class Parlement
{
	reports = null;
	ignoreList = null;
	balance = null;
	mostExpensiveConnectionBuild = null;
	
	constructor() {
		reports = BinaryHeap();
		ignoreList = [];
		mostExpensiveConnectionBuild = 0;
	}
}

/**
 * Executes reports.
 */
function Parlement::ExecuteReports() {

	// Get as much money as possible.
	Finance.GetMaxLoan();

	foreach (report in reports) {

		// Because we planned all reports in advance, we havan't take
		// into account the effects of having less money available for
		// other reports. So it may very well be that the utility becomes
		// negative because we don't have enough money to buy - for instance -
		// a couple of vehicles and can only pay for the road.
		if (report.UtilityForMoney(Finance.GetMaxMoneyToSpend()) <= 0 ||
			!report.connection.pathInfo.build && Finance.GetMaxMoneyToSpend() < 
			mostExpensiveConnectionBuild)
//			(AICompany.GetMaxLoanAmount() / 2 < mostExpensiveConnectionBuild ? mostExpensiveConnectionBuild : AICompany.GetMaxLoanAmount() / 2))
			continue;
			
		ignoreList.push(report);
			
		Log.logInfo(report.ToString());
		local minimalMoneyNeeded = 0;
		foreach (action in report.actions) {
		
			// Break if one of the action fails!
			if (!action.Execute()) {
				Log.logWarning("Execution of raport: " + report.ToString() + " halted!");
				action.CleanupAfterFailure();
				report.isInvalid = true;
				return false;
			}
			minimalMoneyNeeded += action.GetExecutionCosts();
		}

		if (minimalMoneyNeeded > mostExpensiveConnectionBuild)
			mostExpensiveConnectionBuild = minimalMoneyNeeded;
	}
	
	// Pay back as much load as possible.
	Finance.RepayLoan();
	return true;
}

/**
 * Select which reports to execute.
 */
function Parlement::SelectReports(/*Report[]*/ reportlist) {

	local sortedReports = BinaryHeap();
	local orderby = 0;
	local moneyToSpend = Finance.GetMaxMoneyToSpend();
	Log.logDebug("Select reports: " + reportlist.len());

	// Sort all the reports based on their utility.
	/*foreach (report in reportlist) {
		
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

	// Do the selection, by using a greedy subsum algorithm.
	reports = SubSum.GetSubSum(sortedReports, Finance.GetMaxMoneyToSpend());*/
	reports = SubSum.GetSubSum(reportlist);
}

function Parlement::ClearReports() {
	reports = [];
	ignoreList = [];
}
