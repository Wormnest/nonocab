/**
 * All advisors are threads and will be scheduled by the planner. This 
 * will call the Update function which is intended to update the internal
 * state of the advisor and prepare future calls of GetReports. If, at any
 * point, the advisor wants to report an important report it will have to
 * return true when the function HaltPlanner is called (see the Planner class).
 */
class Advisor extends Thread {
	world = null;				// Pointer to the World class.
	disabled = null;			// Is this advisor disabled?
	
	/**
	 * Constructor
	 * @param world Pointer to a world instance.
	 */
	constructor(world) {
		this.world = world;
		disabled = false;
	}

	/**
	 * Called by the planner, the advisor is expected to reason over the world
	 * and prepare reports for the parlement.
	 * @param loopCounter The amount of times this advisor has been called in the
	 * same session, i.e. the amount of times called before the parlement is informed.
	 * @note There are more advisors so each advisor must take care not to claim
	 * all time for itself. A good guideline is: return whenever you reached the 
	 * same amount of reports as 'loopCounter'.
	 */
	function Update(loopCounter);

	/**
	 * Analyses the world and returns its reports.
	 * @callingObject The object which requires the reports, this can't be
	 * the thread itself!
	 * @return An array of reports.
	 */	
	function GetReports();
}
