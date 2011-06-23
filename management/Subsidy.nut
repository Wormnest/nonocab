/**
 * Handle all issues related with subsidies.
 */
class SubsidyManager extends WorldEventListener {

	/**
	 * Make sure this class receives all relevant calls related to subsidies.
	 */
	constructor(worldEvenManager) {
		// First get all subsidies which are already active:
		local subsidies = AISubsidyList();
		foreach (subsidy, dummy in subsidies)
			WE_SubsidyOffer(subsidy);
		worldEvenManager.AddEventListener(this, AIEvent.AI_ET_SUBSIDY_OFFER);
		worldEvenManager.AddEventListener(this, AIEvent.AI_ET_SUBSIDY_OFFER_EXPIRED);
		worldEvenManager.AddEventListener(this, AIEvent.AI_ET_SUBSIDY_AWARDED);
		worldEvenManager.AddEventListener(this, AIEvent.AI_ET_SUBSIDY_EXPIRED);
	}

	function WE_SubsidyOffer(subsidyID) {

		if (AISubsidy.GetSourceType(subsidyID) == AISubsidy.SPT_TOWN)
			Subsidy.town_subsidies[AISubsidy.GetSourceIndex(subsidyID)] <- subsidyID;
		else if (AISubsidy.GetSourceType(subsidyID) == AISubsidy.SPT_INDUSTRY)
			Subsidy.industry_subsidies[AISubsidy.GetSourceIndex(subsidyID)] <- subsidyID;
	}
	
	function WE_SubsidyExpired(subsidyID) {
		if (AISubsidy.GetSourceType(subsidyID) == AISubsidy.SPT_TOWN)
			Subsidy.town_subsidies.rawdelete(AISubsidy.GetSourceIndex(subsidyID));
		else if (AISubsidy.GetSourceType(subsidyID) == AISubsidy.SPT_INDUSTRY)
			Subsidy.industry_subsidies.rawdelete(AISubsidy.GetSourceIndex(subsidyID));
	}
	
	function WE_SubsidyOfferExpired(subsidyID) {
		WE_SubsidyExpired(subsidyID);	
	}
	
	function WE_SubsidyAwarded(subsidyID) {
		if (AISubsidy.GetAwardedTo(subsidyID) != AICompany.COMPANY_SELF) {
			WE_SubsidyExpired(subsidyID);
		}	
	}
}

class Subsidy {
	
	static town_subsidies = {};
	static industry_subsidies = {};
	
	/**
	 * Check if a certain connection is subsidiced.
	 */
	function IsSubsidised(fromConnectionNode, toConnectionNode, cargoID) {
		return Subsidy.IsSubsidisedDirected(fromConnectionNode, toConnectionNode, cargoID) ||
			Subsidy.IsSubsidisedDirected(toConnectionNode, fromConnectionNode, cargoID);
	}
		
	function IsSubsidisedDirected(fromConnectionNode, toConnectionNode, cargoID) {	
		local subsidyList;
		
		if (fromConnectionNode.nodeType == ConnectionNode.INDUSTRY_NODE)
			subsidyList = Subsidy.industry_subsidies;
		else
			subsidyList = Subsidy.town_subsidies;
			
		// Check if the start node is part of the subsidies.
		if (!subsidyList.rawin(fromConnectionNode.id)) {
			return false;
		}
			
		local subsidyID = subsidyList[fromConnectionNode.id];

		// Check if the end point matches the endpoint of the connection.
		if (toConnectionNode.nodeType == ConnectionNode.INDUSTRY_NODE &&
			AISubsidy.GetDestinationType(subsidyID) != AISubsidy.SPT_INDUSTRY)
			return false;
			
		if (toConnectionNode.nodeType == ConnectionNode.TOWN_NODE &&
			AISubsidy.GetDestinationType(subsidyID) != AISubsidy.SPT_TOWN)
			return false;

		// Check if the cargo matches.
		if (cargoID != AISubsidy.GetCargoType(subsidyID))
			return false;

		// Now check if the ids match.
		//if (toConnectionNode.id != AISubsidy.GetDestinationIndex(subsidyID))
		if (toConnectionNode.id != AISubsidy.GetDestinationIndex(subsidyID))
			return false;

		// Because we need to allow time before the subsidy is awarded (we first need to
		// build and get at least 1 vehicle to the destination), we allow the AI 4 months
		// slack in trying to secure subsidies.
		if (Date.GetDaysBetween(AISubsidy.GetExpireDate(subsidyID), AIDate.GetCurrentDate()) < 4 * Date.DAYS_PER_MONTH)
			return false;
		return true;
	}
}
