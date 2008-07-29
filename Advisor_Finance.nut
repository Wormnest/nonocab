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
	// able to borrow.
	if(maxLoan > 0)
	{
		//reports[i++] = Report("Borrow one.",0, maxLoan, 1000, BankBalanceAction(maxLoan));
	}
	//reports[0] = new Report("Borrow one.",0, 10000, 123, null);
	//reports[1] = new Report("Borrow all.",0, 10000, 123, null);
	//reports[2] = new Report("Repay one.",11000, 0, -200, null);
	//reports[3] = new Report("Repay all.",11000, 0, -200, null);
	
	return reports;
}