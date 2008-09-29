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
		Log.logInfo(report.ToString());
		foreach (action in report.actions)
		{
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
	//local exprected_profit = 0;

	// Sort all the reports based on their utility.
	foreach (report in reportlist)
	{
		local utility = report.Utility();
		Log.logDebug(utility + " for " + report.ToString());
		// Only add when whe think that they will be profitable in the end.
		// Don't look for things if they are to expensive.
		if(utility > 0)
		{
			//Log.logDebug(report.message);
			//orderby = exprected_profit * report.cost;
			sortedReports.Insert(report, -utility);
		}
	}

	// Do the selection, by using a greedy subsum algorithm.
	reports = SubSum.GetSubSum(sortedReports, Finance.GetMaxMoneyToSpend());
}

function Parlement::ClearReports()
{
	reports = [];
}
