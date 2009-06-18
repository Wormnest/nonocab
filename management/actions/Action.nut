class Action
{
	actionHandlers = null;
	totalCosts = null;		// The total costs of the last constructed road.
	
	/**
	 * Constructor with the world.
	 */
	constructor() { 
		actionHandlers = [];
		totalCosts = 0;
	}

	/**
	 * Executes the action.
	 * @return True if the action was successful, false otherwise.
	 */
	function Execute();

	/**
	 * Get the cost of the action AFTER executing it.
	 */
	function GetExecutionCosts() {
		return totalCosts;
	}
	
	/**
	 * Call this function each time you wish the action handlers to
	 * be informed of your actions.
	 */
	function CallActionHandlers() {
		foreach (actionHandler in actionHandlers) {
			actionHandler.HandleAction(this);
		}
	}
	
	/**
	 * Add an action handler to this action.
	 */
	function AddActionHandlerFunction(handlerFunction) {
		actionHandlers.push(handlerFunction);
	}
	
	/**
	 * Remove an actionahndler from this function.
	 */
	function RemoveActionHandlerFunction(handerFunction) {
		foreach (index, actionHandler in actionHandlers) {
			if (actionHandler == handerFunction)
				actionHanders.remove(index);
		}
	}
}

/**
 * Sometimes after executing an action the effects may need to be propagated to
 * other classes / objects.
 *
 * The state of the action needs to be stored in the action itself.
 */ 
class ActionCallbackHandler
{
	function HandleAction(actionClass);	
}

