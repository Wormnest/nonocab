/**
 * Interface for all classes which wishes to be notified
 * by the selected events.
 */
 class EventListener {
 	function ProcessNewEngineAvailableEvent(engineID);
 	function ProcessIndustryOpenedEvent(industryID);
 	function ProcessIndustryClosedEvent(industryID);
 }