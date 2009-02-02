/**
 * This class takes care of upgrading existing connections:
 * - Update airports.
 * - Make routes longer.
 * - Updating to newer engines.
 * - Etc.
 */
class UpdateConnectionAdvisor extends Advisor {
	
	constructor(world) {
		Advisor.constructor(world);
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
}