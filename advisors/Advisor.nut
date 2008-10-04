/**
 * All advisors are threads and will be scheduled by the planner. This 
 * will call the Update function which is intended to update the internal
 * state of the advisor and prepare future calls of GetReports. If, at any
 * point, the advisor wants to report an important report it will have to
 * return true when the function HaltPlanner is called (see the Planner class).
 */
class Advisor extends Thread
{
	world = null;				// Pointer to the World class.
	
	/**
	 * Constructor
	 * @param world Pointer to a world instance.
	 */
	constructor(world)
	{
		this.world = world;
	}

	/**
	 * Analyses the world an returns its reports.
	 * @callingObject The object which requires the reports, this can't be
	 * the thread itself!
	 * @return An array of reports.
	 */	
	function GetReports();
}
