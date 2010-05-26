/**
 * Take care of all actions related to local authorities, from bribing, building statues, etc. This class
 * is currently very limited as we are not able to detect what our opponents are doing or where their stations
 * are...
 */
class LocalAuthority
{
	static minimumMoneyForStatue = 2000000;
	static minimumMoneyForRights = 25000000;
	static minimumMoneyForImproving = 100000;

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
	town_list.Valuate(AITown.GetRating, AICompany.COMPANY_SELF);
	town_list.Sort(AIAbstractList.SORT_BY_VALUE, AIAbstractList.SORT_ASCENDING);

	if (town_list.Count() > 0)
	{
		local town = town_list.Begin();

		// If the rating is below 0, start building trees.
		if (AITown.GetRating(town, AICompany.COMPANY_SELF) > 0)
			return;

		Log.logInfo("Improve relations with " + AITown.GetName(town));

		// Check how large the town is.
		local maxXSpread = 20;
		while (AITile.IsWithinTownInfluence(tile + maxXSpread, id) || AITile.IsWithinTownInfluence(tile - maxXSpread, id))
			maxXSpread += 10;

		local maxYSpread = 20;
		while (AITile.IsWithinTownInfluence(tile + maxYSpread * AIMap.GetMapSizeX(), id) || AITile.IsWithinTownInfluence(tile - maxYSpread * AIMap.GetMapSizeX(), id))
			maxYSpread += 10;

		maxXSpread += 20;
		maxYSpread += 20;

		local list = Tile.GetRectangle(tile, maxXSpread, maxYSpread);

		// Purge all unnecessary entries from the list.
		list.Valuate(AITile.IsWithinTownInfluence, id);
		list.KeepAboveValue(0);
		list.Valuate(AITile.IsBuildable);
		list.KeepAboveValue(0);
		
		// Start building trees until we restored our reputation.
		foreach (tile, index in list)
		{
			AITile.PlantTree(tile);
			// If the rating is below 0, start building trees.
			if (AITown.GetRating(town, AICompany.COMPANY_SELF) > 200)
				return;
		}
	}
}

