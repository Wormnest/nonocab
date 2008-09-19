class Advisor
{
	static LOAD_UNLOAD_PENALTY_IN_DAYS = 1.2;
	/** Gets and sets the inner representation of the 'world'. */
	innerWorld = null;
	
	/**
	 * Constructor
	 * @param world
	 *
	 */
	constructor(/*World*/ world)
	{
		this.innerWorld = world;
	}
}

/**
 * Analyses the world an returns its reports.
 *
 * @return A list of reports.
 * 
 */
function Advisor::getReports()
{
//	local reports = array(0);
//	reports[0] = new Report();
//	return reports;	
}