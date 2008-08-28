class Action
{
	world = null;
	
	/**
	 * Empty constructor.
	 */
	constructor() { }
	
	/**
	 * Constructor with the world.
	 */
	constructor(world) { 
		this.world = world;
	}

	/**
	 * Executes the action.
	 */
	function execute();
}

///////////////////////////////////////////////////////////////////////////////

class BankBalanceAction extends Action
{
	amount = 0;
	
	/**
	 * Constructs a bankbalance transaction.
	 */
	constructor(/* int */ change)
	{
		this.amount = change;
	}
}

function BankBalanceAction::execute()
{
	AICompany.SetLoanAmount(this.amount);
}

///////////////////////////////////////////////////////////////////////////////

class MailTruckNewOrderAction extends Action
{
	startStation = null;
	endStation = null;
	
	constructor(/* station */ start, /* station */ end)
	{
		this.startStation = start;
		this.endStation = end;
	} 
}

function MailTruckNewOrderAction::execute()
{
	// TODO: full load: startStation
	// TODO: unload: endStation
}

///////////////////////////////////////////////////////////////////////////////

class BuildRoadAction extends Action
{
	industryConnection = null;
	roadList = null;
	buildDepot = false;
	buildRoadStations = false;
	
	directions = null;
	
	constructor(industryConnection, roadList, buildDepot, buildRoadStations)
	{
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.industryConnection = industryConnection;
		this.roadList = roadList;
		this.buildDepot = buildDepot;
		this.buildRoadStations = buildRoadStations;
	}
}

function BuildRoadAction::execute()
{
	RoadPathFinding.CreateRoad(roadList);
	industryConnection.build = true;
	
	if (buildRoadStations) {
		local len = roadList.len();
		AIRoad.BuildRoadStation(roadList[0], roadList[1], true, false, true);
		AIRoad.BuildRoadStation(roadList[len - 1], roadList[len - 2], true, false, true);
	}
	
	if (buildDepot) {
		for (local i = 2; i < roadList.len() - 1; i++) {
			
			foreach (direction in directions) {
				if (Tile.IsBuildable(roadList[i] + direction) && AIRoad.CanBuildConnectedRoadPartsHere(roadList[i], roadList[i] + direction, roadList[i + 1])) {
					AIRoad.BuildRoadDepot(roadList[i] + direction, roadList[i]);
					break;
				}
			}
		}
	}
}

///////////////////////////////////////////////////////////////////////////////

class ManageVehiclesAction extends Action {

	vehiclesToSell = null;
	vehiclesToBuy = null;
	
	constructor() { 
		vehiclesToSell = [];
		vehiclesToBuy = [];
	}
	
	function SellVehicle(vehicleID);
	function BuyVehicles(engineID, number, industryConnection);
}

function ManageVehiclesAction::execute()
{

}