import("queue.binary_heap", "BinaryHeap", 1);

class Parlement
{
	reports = null;
	
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
	foreach (report in reports)
	{
		Log.logInfo(report.message);
		foreach (action in report.actions)
		{
			action.Execute();
		}
	}
}

/**
 * Select which reports to execute.
 */
function Parlement::SelectReports(/*Report[]*/ reportlist)
{

	local sortedReports = BinaryHeap();

	// Sort all the reports based on their utility.
	foreach (report in reportlist) {
		sortedReports.Insert(report, -report.Utility());
	}
	
	// Do the selection, by using a greedy subsum algorithm.
	reports = SubSum.GetSubSum(sortedReports, AICompany.GetBankBalance(AICompany.MY_COMPANY));
}

function Parlement::ClearReports()
{
	reports = [];
}
