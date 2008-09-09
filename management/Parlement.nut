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
	foreach (report in reports) {
		foreach (action in report.actions) {
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
	local currentReport = null;
	local money = AICompany.GetBankBalance(AICompany.MY_COMPANY);

	while ((currentReport = sortedReports.Pop()) != null) {
		
		// See if we can afford it.
		if (currentReport.cost < money) {
			reports.push(currentReport);
			money -= currentReport.cost;
		}
	}
}

function Parlement::ClearReports()
{
	reports = [];
}
