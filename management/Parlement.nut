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
	// Get as much money as possible.
	{
		local loan = AIExecMode();
		AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
	}	
	foreach (report in reports)
	{
		Log.logInfo(report.message);
		foreach (action in report.actions)
		{
			// Break if one of the action fails!
			if (!action.Execute())
				return;
		}
	}
	
	// Pay back as much load as possible.
	{
		local loan = AIExecMode();
		local loanInterval = AICompany.GetLoanInterval();
		while (AICompany.SetLoanAmount(AICompany.GetLoanAmount() - loanInterval));
		//AICompany.SetLoanAmount(AICompany.GetLoanAmount() - (AICompany.GetBankBalance(AICompany.MY_COMPANY) / AICompany.GetLoanInterval()));
	}	
}

/**
 * Select which reports to execute.
 */
function Parlement::SelectReports(/*Report[]*/ reportlist)
{

	local sortedReports = BinaryHeap();
	local orderby = 0;
	local exprected_profit = 0;

	// Sort all the reports based on their utility.
	foreach (report in reportlist)
	{
		exprected_profit = report.profitPerMonth * World.GetMonthsRemaining() - report.cost * World.GetBankInterestRate();
		
		Log.logDebug(exprected_profit + " for " + report.message);
		// Only add when whe think that they will be profitable in the end.
		if(exprected_profit > 0)
		{
			//Log.logDebug(report.message);
			orderby = exprected_profit * report.cost;
			sortedReports.Insert(report, orderby);
		}
	}
	
	// Do the selection, by using a greedy subsum algorithm.
	reports = SubSum.GetSubSum(sortedReports, AICompany.GetBankBalance(AICompany.MY_COMPANY));
}

function Parlement::ClearReports()
{
	reports = [];
}
