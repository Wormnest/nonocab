class FinanceAdvisor extends Advisor {}

/**
 * Get financial reports.
 *
 *  There are basicly 4 options:
 *  - Borrow one entity
 *  - Borrow to the maximum
 *  - Repay one entity
 *  - Repay all (or to the maximum possible).   
 */
function FinanceAdvisor::getReports()
{
	local reports = array(0);
	local i = 0;
	
	local maxLoan = AICompany.GetMaxLoanAmount();
	local loan = AICompany.GetLoanAmount();
	Log.logDebug("loan: " + loan);
	local toLoan = maxLoan-loan;
	// able to borrow.
	if(toLoan > 0)
	{
		reports.push(Report("Borrow the maximum.", -toLoan, toLoan, BankBalanceAction(maxLoan)));
	}
	return reports;
}