/**
 * Interface for all classes which wishes to be notified
 * by the selected events.
 */
class WorldEventListener {
 	/**
 	 * Called when a new engine is added to the world, but only if it
 	 * replaces a previous selected vehicle.
 	 * @param engineID The new engine ID added to the world.
 	 */
 	function WE_EngineReplaced(engineID);
 	
 	/**
 	 * Called when a new industry is added to the world.
 	 * @param industryNode The new industry node added to the world.
 	 */
 	function WE_IndustryOpened(industryNode);
 	
 	/**
 	 * Called when a new industry is added to the world.
 	 * @param industryNode The industry node removed from the world.
 	 */
 	function WE_IndustryClosed(industryID);
 	
 	/**
 	 * Function calls related to subsidies.
 	 * @param subsidyID The subsidy ID related to the offered subsidy.
 	 */ 
	function WE_SubsidyOffer(subsidyID);
	function WE_SubsidyExpired(subsidyID);
	function WE_SubsidyOfferExpired(subsidyID);
	function WE_SubsidyAwarded(subsidyID); 	
}