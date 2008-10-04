/**
 * The planner manages all threads in the AI.
 */
class Planner {

	threads = null;			// List of all threads.
	world = null;			// The world object.
	
	constructor(world) {
		threads = [];
		this.world = world;
	}
	
	/**
	 * Add a thread to this planner.
	 * @thread The thread to add to the planner.
	 * @isCritical Is this thread critical?
	 */
	function AddThread(thread);
	
	/**
	 * Activate the planner which will run the threads one by one until a certain
	 * time periode is due or one of the threads indicates it wants to halt the 
	 * planner.
	 */
	function ScheduleAndExecute();
}

function Planner::AddThread(thread) {
	threads.push(thread);
}

function Planner::ScheduleAndExecute() {
	
	local haltPlanner = false;
	local currentDate = AIDate.GetCurrentDate();
	local loopCounter = 0;
	
	while (!haltPlanner && Date.GetDaysBetween(currentDate, AIDate.GetCurrentDate()) < world.DAYS_PER_MONTH) {
		foreach (thread in threads) {
			thread.Update(loopCounter);
			
			if (thread.HaltPlanner())
				haltPlanner = true;
		}
		loopCounter++;
	}
}
