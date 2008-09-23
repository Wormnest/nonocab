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
	{
		local loanMode = AIExecMode();
		AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
	}
	foreach (report in reports)
	{
		Log.logInfo(report.message);
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
	{
		local loanMode = AIExecMode();
		local loanInterval = AICompany.GetLoanInterval();
		while (AICompany.SetLoanAmount(AICompany.GetLoanAmount() - loanInterval));
	}	
}

/**
 * Select which reports to execute.
 */
function Parlement::SelectReports(/*Report[]*/ reportlist)
{

	local sortedReports = BinaryHeap();
	local orderby = 0;
	//local exprected_profit = 0;

	UpdateFinance();
	local potentinal_balance = balance + AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount()
	// Sort all the reports based on their utility.
	foreach (report in reportlist)
	{
		local utility = report.Utility();
		Log.logDebug(utility + " for " + report.message);
		// Only add when whe think that they will be profitable in the end.
		// Don't look for things if they are to expensive.
		if(utility > 0)
		{
			//Log.logDebug(report.message);
			//orderby = exprected_profit * report.cost;
			sortedReports.Insert(report, -utility);
		}
		else
		{
			Log.logWarning("Util: " + utility + ", cost: " + report.cost + ", " + report.message);
		}
	}
	UpdateFinance();
	// Do the selection, by using a greedy subsum algorithm.
	reports = SubSum.GetSubSum(sortedReports, potentinal_balance);
}
function Parlement::UpdateFinance()
{
	balance = AICompany.GetBankBalance(AICompany.MY_COMPANY);
}
function Parlement::ClearReports()
{
	reports = [];
}
