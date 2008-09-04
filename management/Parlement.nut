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
}

/**
 * Select which reports to execute.
 */
function Parlement::SelectReports(/*Report[]*/ reportlist)
{
	foreach (report in reportList) {
		reports.Insert(report, -report.Utility());
	}
	
	// Do the selection...
}

function Parlement::ClearReports()
{
	reports = BinaryHeap();
}
