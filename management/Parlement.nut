import("queue.binary_heap", "BinaryHeap", 1);

class Parlement
{
	reports = null;
	ignoreList = null;

	// The next two seem not to be used: commented out
	//balance = null;
	//mostExpensiveConnectionBuild = null;
	
	constructor() {
		reports = BinaryHeap();
		ignoreList = [];
		//mostExpensiveConnectionBuild = 0;
	}
}

/**
 * Executes reports.
 */
function Parlement::ExecuteReports() {

	// Get as much money as possible.
	Finance.GetMaxLoan();

	local canBuild = Finance.ConstructionAllowed();
	local mostExpensiveBuild = 0;

	foreach (report in reports) {
		if (report.isInvalid) {
			Log.logError("Parlement: Invalid report!");
			continue;
		}
		// Because we planned all reports in advance, we havan't take
		// into account the effects of having less money available for
		// other reports. So it may very well be that the utility becomes
		// negative because we don't have enough money to buy - for instance -
		// a couple of vehicles and can only pay for the road.
		if (report.UtilityForMoney(Finance.GetMaxMoneyToSpend()) < 0) {
			if (report.nrVehicles < 0) {
				Log.logError(report.ToString());
				Log.logWarning(report.UtilityForMoney(Finance.GetMaxMoneyToSpend()));
				quit();
			}
			continue;
		}
			
		// Allow building so long we have at least as much money as the most expensive build in this session.
		if (report.connection == null || !report.connection.pathInfo.build && mostExpensiveBuild > Finance.GetMaxMoneyToSpend())
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

		if (minimalMoneyNeeded > mostExpensiveBuild)
			mostExpensiveBuild = minimalMoneyNeeded;
		
		AISign.BuildSign(report.connection.pathInfo.roadList[0].tile, "Month: " + (report.brutoIncomePerMonthPerVehicle - report.brutoCostPerMonthPerVehicle) + "; year: " + (report.brutoIncomePerMonthPerVehicle - report.brutoCostPerMonthPerVehicle) * 12);
	}
	
	// Pay back as much load as possible.
	Finance.RepayLoan();
	return true;
}

/**
 * Select which reports to execute.
 */
function Parlement::SelectReports(/*Report[]*/ reportlist) {

	local moneyToSpend = Finance.GetMaxMoneyToSpend();
	Log.logDebug("Select reports: " + reportlist.len());

	// Sort all the reports based on their utility.
	reports = SubSum.GetSubSum(reportlist);
}

function Parlement::ClearReports() {
	reports = [];
	ignoreList = [];
}
