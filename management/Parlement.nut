class Parlement
{
	reports = null;
	
	constructor()
	{
		this.reports = array(0);
	}
}
/**
 * Executes reports.
 */
function Parlement::ExecuteReports()
{
}

function Parlement::AddReports(/*Report[]*/ reportlist)
{
	reports.extend(reportList);
}

function Parlement::ClearReports()
{
	reports.clean();
}
