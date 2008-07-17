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
function FinanceDepartment::getReports()
{
	local reports = array(0);
	
	reports[0] = new Report("Borrow one.",0, 10000, 123, null);
	reports[1] = new Report("Borrow all.",0, 10000, 123, null);
	reports[2] = new Report("Repay one.",11000, 0, -200, null);
	reports[3] = new Report("Repay all.",11000, 0, -200, null);
	
	return reports;
}