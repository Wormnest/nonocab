import("queue.binary_heap", "BinaryHeap", 1);

class Parlement
{
	reports = null;
	balance = null;
	
	constructor()
	{
		reports = BinaryHeap();
	}
}
/**
 * Executes reports.
 */
function Parlement::ExecuteReports()
{
	// Get as much money as possible.
	Finance.GetMaxLoan();

	foreach (report in reports)
	{
		// Because we planned all reports in advance, we havan't take
		// into account the effects of having less money available for
		// other reports. So it may very well be that the utility becomes
		// negative because we don't have enough money to buy - for instance -
		// a couple of vehicles and can only pay for the road.
		if (report.UtilityForMoney(Finance.GetMaxMoneyToSpend()) <= 0)
			continue;
			
		Log.logInfo(report.ToString());
		foreach (action in report.actions) {
		
			// Break if one of the action fails!
			if (!action.Execute()) {
				Log.logWarning("Execution of raport halted!");
				break;
			}
		}
	}
	
	// Pay back as much load as possible.
	Finance.RepayLoan();	
}

/**
 * Select which reports to execute.
 */
function Parlement::SelectReports(/*Report[]*/ reportlist)
{

	local sortedReports = BinaryHeap();
	local orderby = 0;
	local moneyToSpend = Finance.GetMaxMoneyToSpend();

	// Sort all the reports based on their utility.
	foreach (report in reportlist)
	{
		local utility = report.UtilityForMoney(moneyToSpend);
		Log.logDebug(utility + " for " + report.ToString());
		// Only add when whe think that they will be profitable in the end.
		// Don't look for things if they are to expensive.
		if(utility > 0)
			sortedReports.Insert(report, (report.initialCost > 0 ? -utility / (report.initialCost + report.nrVehicles * report.initialCostPerVehicle) : -2147483648));
	}

	// Do the selection, by using a greedy subsum algorithm.
	reports = SubSum.GetSubSum(sortedReports, Finance.GetMaxMoneyToSpend());
}

function Parlement::ClearReports() {
	reports = [];
}
