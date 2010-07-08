/**
 * Take care of all actions related to local authorities, from bribing, building statues, etc. This class
 * is currently very limited as we are not able to detect what our opponents are doing or where their stations
 * are...
 */
class LocalAuthority
{
	static minimumMoneyForStatue = 1000000;
	static minimumMoneyForRights = 15000000;
	static minimumMoneyForImproving = 100000;
	static minimumMoneyForHQ = 350000;

	improveRelationsEnabled = null;     // Plant trees.
	buildStatuesEnabled = null;         // Build statues.
	secureRightsEnabled = null;         // Secure rights.

	constructor(improveRelations, buildStatues, secureRights)
	{
		improveRelationsEnabled = improveRelations;
		buildStatuesEnabled = buildStatues;
		secureRightsEnabled = secureRights;
	}

	/**
	 * Give the program free reighn in deciding what to do with left over money.
	 */
	function HandlePolitics();

	/**
	 * Build statues in towns to improve our acceptance rate.
	 */
	function BuildStatues();

	/**
	 * Plant trees to please the local authorities.
	 */
	function ImproveRelations();

	/**
	 * Secure exclusive transportation rights, but only if we're very rich ;).
	 */
	function SecureTransportationsRights();

	/**
	 * Build an HQ at the given town.
	 */
	function BuildHQ(town);
}

function LocalAuthority::HandlePolitics()
{

	local exec = AIExecMode();
	if (buildStatuesEnabled)
		BuildStatues();

	if (improveRelationsEnabled)
		ImproveRelations();

	if (secureRightsEnabled)
		SecureTransportationsRights();
}

function LocalAuthority::NulValuator(item)
{
	return 0;
}

function LocalAuthority::GetActiveTowns(town_list)
{
	town_list.Valuate(NulValuator);
	local station_list = AIStationList(AIStation.STATION_ANY);
	station_list.Valuate(AIStation.GetNearestTown);
	foreach (station, town in station_list) {
		if (town_list.HasItem(town)) {
			town_list.SetValue(town, town_list.GetValue(town) + 1);
		}
	}
	town_list.KeepAboveValue(0);
	return town_list;
}


function LocalAuthority::BuildStatues()
{
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < minimumMoneyForStatue)
		return;

	local town_list = AITownList();
	town_list.Valuate(AITown.HasStatue);
	town_list.RemoveValue(1);
	GetActiveTowns(town_list);
	town_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

	foreach (town, index in town_list)
	{
		BuildHQ(town);
		Log.logInfo("Build a statue in " + AITown.GetName(town));
		if (AITown.PerformTownAction(town, AITown.TOWN_ACTION_BUILD_STATUE) && AICompany.GetBankBalance(AICompany.COMPANY_SELF) < minimumMoneyForStatue)
			return;
	}
}

function LocalAuthority::SecureTransportationsRights()
{
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < minimumMoneyForRights)
		return;

	local town_list = AITownList();
	town_list.Valuate(AITown.GetExclusiveRightsCompany);
	town_list.KeepValue(AICompany.COMPANY_INVALID);
	GetActiveTowns(town_list);
	town_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_DESCENDING);

	foreach (town, index in town_list)
	{
		Log.logInfo("Buy all the transportation rights in " + AITown.GetName(town));
		if (AITown.PerformTownAction(town, AITown.TOWN_ACTION_BUY_RIGHTS) && AICompany.GetBankBalance(AICompany.COMPANY_SELF) < minimumMoneyForRights)
			return;
	}
}

function LocalAuthority::ImproveRelations()
{
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) < minimumMoneyForImproving)
		return;

	// Only improve relations with the town most hostile towards us.
	local town_list = AITownList();
	GetActiveTowns(town_list);
	local companyId = AICompany.COMPANY_SELF;//AICompany.ResolveCompanyID(AICompany.COMPANY_SELF);
	town_list.Valuate(AITown.GetRating, companyId);
	town_list.KeepBelowValue(AITown.TOWN_RATING_GOOD);
	town_list.RemoveValue(AITown.TOWN_RATING_NONE);
	town_list.RemoveValue(AITown.TOWN_RATING_INVALID);
	town_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);

	if (town_list.Count() > 0)
	{
		local town = town_list.Begin();
		local tile = AITown.GetLocation(town);

		Log.logInfo("Improve relations with " + AITown.GetName(town) + " [" + AITown.GetRating(town, companyId) + "]");

		// Check how large the town is.
		local maxXSpread = 5;
		while (AITile.IsWithinTownInfluence(tile + maxXSpread, town) || AITile.IsWithinTownInfluence(tile - maxXSpread, town))
			maxXSpread += 5;

		local maxYSpread = 5;
		while (AITile.IsWithinTownInfluence(tile + maxYSpread * AIMap.GetMapSizeX(), town) || AITile.IsWithinTownInfluence(tile - maxYSpread * AIMap.GetMapSizeX(), town))
			maxYSpread += 5;

		maxXSpread += 5;
		maxYSpread += 5;

		local list = Tile.GetRectangle(tile, maxXSpread, maxYSpread);

		// Purge all unnecessary entries from the list.
		list.Valuate(AITile.GetClosestTown);
		list.KeepValue(town);
		list.Valuate(AITile.IsBuildable);
		list.KeepAboveValue(0);
		
		// Start planting trees until we restored our reputation.
		list.Valuate(AIBase.RandItem);
		local exec = AIExecMode();
		foreach (tile, index in list)
		{
			while (AITile.PlantTree(tile));
			// If the rating is good, stop building trees.
			if (AITown.GetRating(town, companyId) == AITown.TOWN_RATING_GOOD)
				break;
		}

		Log.logInfo("[Result] Improve relations with " + AITown.GetName(town) + " [" + AITown.GetRating(town, companyId) + "]");
	}
}

function LocalAuthority::BuildHQ(town)
{
	// Check if we have an HQ.
	if (AICompany.GetCompanyHQ(AICompany.COMPANY_SELF) != AIMap.TILE_INVALID) {
		return;
	}
	Log.logInfo("Build HQ!");
	
	// Find empty 2x2 square as close to town centre as possible
	local maxRange = Sqrt(AITown.GetPopulation(town)/100) + 5; //TODO check value correctness
	local HQArea = AITileList();
	
	HQArea.AddRectangle(AITown.GetLocation(town) - AIMap.GetTileIndex(maxRange, maxRange), AITown.GetLocation(town) + AIMap.GetTileIndex(maxRange, maxRange));
	HQArea.Valuate(AITile.IsBuildableRectangle, 2, 2);
	HQArea.KeepValue(1);
	HQArea.Valuate(AIMap.DistanceManhattan, AITown.GetLocation(town));
	HQArea.Sort(AIList.SORT_BY_VALUE, true);
	
	foreach (tile, value in HQArea) {
		if (AICompany.BuildCompanyHQ(tile)) {
			return;
		}
	}
}
