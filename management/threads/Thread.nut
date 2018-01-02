/**
 * Basic class for all 'threads'. This means a class that can run a certain
 * piece of code multiple times during the run of the AI. The idea is that
 * the class stores its initial state and incrementally updates and extends this.
 */
class Thread {
	
	/**
	 * Create a new thread which is aware of its planner.
	 */
	constructor() {

	}
	
	/**
	 * Run this thread.
	 */
	function Update();
	
	/**
	 * If the thread has a very serious report to deliver, signal a halt to the planner.
	 * @return True if the planner must halt, false otherwise. 
	 */
	function HaltPlanner() {
		return false;
	} 
}