class Parlement
{
	innerReports = array(0);
	
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
	local length = this.reports.len();
	
	for(local i = 0; i < reportlist.len(); i++)
	{
		this.reports[length] = reportlist[i];
		length++;
	}
}
function Parlement::ClearReports()
{
	this.reports = array(0);
}