class Action
{
	world = null;
	actionHandlers = null;
	
	/**
	 * Empty constructor.
	 */
	constructor() { 
		this.actionHandlers = [];
	}
	
	/**
	 * Constructor with the world.
	 */
	constructor(world) { 
		this.world = world;
		this.actionHandlers = [];
	}

	/**
	 * Executes the action.
	 */
	function Execute();
	
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

