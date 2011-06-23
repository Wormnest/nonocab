class WorldEventManager {
	
	world = null;
	eventListeners = null;
	
	/**
	 * Enable all events we're interested in.
	 */
	constructor(world) {
		this.world = world;
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

function WorldEventManager::AddEventListener(listener, event) {
	local listeners;
	if (!eventListeners.rawin("" + event))
		eventListeners.rawset("" + event, []);
	listeners = eventListeners.rawget("" + event);
	listeners.push(listener);
}

/**
 * Check all events which are waiting and handle them properly.
 */
function WorldEventManager::ProcessEvents() {
	while (AIEventController.IsEventWaiting()) {
		
		local e = AIEventController.GetNextEvent();
		local functionCall;
		
		if (eventListeners.rawin("" + e.GetEventType())) {
			switch (e.GetEventType()) {
				
				case AIEvent.AI_ET_ENGINE_PREVIEW:
					AIEventEnginePreview.AcceptPreview();
					break;

				case AIEvent.AI_ET_ENGINE_AVAILABLE:
					local newEngineID = AIEventEngineAvailable.Convert(e).GetEngineID();
					
					foreach (listener in eventListeners.rawget("" + e.GetEventType()))
						listener.WE_EngineReplaced(newEngineID);
					break;
					
				case AIEvent.AI_ET_INDUSTRY_OPEN:
					local industryID = AIEventIndustryOpen.Convert(e).GetIndustryID();
					local industryNode = world.ProcessIndustryOpenedEvent(industryID);
					
					foreach (listener in eventListeners.rawget("" + e.GetEventType())) 
						listener.WE_IndustryOpened(industryNode);
					break;
					
				case AIEvent.AI_ET_INDUSTRY_CLOSE:
					local industryID = AIEventIndustryClose.Convert(e).GetIndustryID();
					local industryNode = world.ProcessIndustryClosedEvent(industryID);
					
					// TODO: In some cases we fail to remove an industry...
					if (industryNode != null)
						foreach (listener in eventListeners.rawget("" + e.GetEventType())) 
							listener.WE_IndustryClosed(industryNode);
					break;

				// Subsidy:
				case AIEvent.AI_ET_SUBSIDY_OFFER:
					local subsidyID = AIEventSubsidyOffer.Convert(e).GetSubsidyID();
					foreach (listener in eventListeners.rawget("" + e.GetEventType())) 
						listener.WE_SubsidyOffer(subsidyID);
					break;
					
				case AIEvent.AI_ET_SUBSIDY_EXPIRED:
					local subsidyID = AIEventSubsidyExpired.Convert(e).GetSubsidyID();
					foreach (listener in eventListeners.rawget("" + e.GetEventType()))
						listener.WE_SubsidyExpired(subsidyID);
					break;
				
				case AIEvent.AI_ET_SUBSIDY_OFFER_EXPIRED:
					local subsidyID = AIEventSubsidyOfferExpired.Convert(e).GetSubsidyID();
					foreach (listener in eventListeners.rawget("" + e.GetEventType()))
						listener.WE_SubsidyOfferExpired(subsidyID);
					break;
				
				case AIEvent.AI_ET_SUBSIDY_AWARDED:
					local subsidyID = AIEventSubsidyAwarded.Convert(e).GetSubsidyID();
					foreach (listener in eventListeners.rawget("" + e.GetEventType()))
						listener.WE_SubsidyAwarded(subsidyID);
					break;
				
			}	
		}		
	}
}
