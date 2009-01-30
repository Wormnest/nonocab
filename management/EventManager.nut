class EventManager {
	
	eventListeners = null;
	
	/**
	 * Enable all events we're interested in.
	 */
	constructor() {
		eventListeners = {};
	}
	
	/**
	 * Add an event listener.
	 * @param listener The event listener to add.
	 * @param event The event to listen to.
	 */
	function AddEventListener(listener, event);
	
	/**
	 * Check if there are any events on the queue, if so
	 * call the registered listeners.
	 */
	function ProcessEvents();
}

function EventManager::AddEventListener(listener, event) {
	local listeners;
	if (!eventListeners.rawin("" + event))
		eventListeners.rawset("" + event, []);
	listeners = eventListeners.rawget("" + event);
	listeners.push(listener);
}

/**
 * Check all events which are waiting and handle them properly.
 */
function EventManager::ProcessEvents() {
	while (AIEventController.IsEventWaiting()) {
		
		local e = AIEventController.GetNextEvent();
		local functionCall;
		
		if (eventListeners.rawin("" + e.GetEventType())) {
			switch (e.GetEventType()) {
				
				case AIEvent.AI_ET_ENGINE_AVAILABLE:
					local newEngineID = AIEventEngineAvailable.Convert(e).GetEngineID();
					
					foreach (listener in eventListeners.rawget("" + e.GetEventType())) {
						listener.ProcessNewEngineAvailableEvent(newEngineID);
					}
					break;
					
				case AIEvent.AI_ET_INDUSTRY_OPEN:
					local industryID = AIEventIndustryOpen.Convert(e).GetIndustryID();
					
					foreach (listener in eventListeners.rawget("" + e.GetEventType())) 
						listener.ProcessIndustryOpenedEvent(industryID);
					break;
					
				case AIEvent.AI_ET_INDUSTRY_CLOSE:
					local industryID = AIEventIndustryClose.Convert(e).GetIndustryID();
					
					foreach (listener in eventListeners.rawget("" + e.GetEventType())) 
						listener.ProcessIndustryClosedEvent(industryID);
					break;
			}	
		}		
	}
}
