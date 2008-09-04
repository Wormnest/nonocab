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
	pathList = null;
	buildDepot = false;
	buildRoadStations = false;
	
	directions = null;
	
	constructor(pathList, buildDepot, buildRoadStations)
	{
		this.directions = [1, -1, AIMap.GetMapSizeX(), -AIMap.GetMapSizeX()];
		this.pathList = pathList;
		this.buildDepot = buildDepot;
		this.buildRoadStations = buildRoadStations;
	}
}

function BuildRoadAction::execute()
{
	RoadPathFinding.CreateRoad(pathList);
	
	if (buildRoadStations) {
		local len = roadList.len();
		AIRoad.BuildRoadStation(pathList.roadList[0], roadList[1], true, false, true);
		AIRoad.BuildRoadStation(pathList.roadList[len - 1], roadList[len - 2], true, false, true);
	}
	
	if (buildDepot) {
		for (local i = 2; i < pathList.roadList.len() - 1; i++) {
			
			foreach (direction in directions) {
				if (Tile.IsBuildable(pathList.roadList[i] + direction) && AIRoad.CanBuildConnectedRoadPartsHere(pathList.roadList[i], pathList.roadList[i] + direction, pathList.roadList[i + 1])) {
					if (AIRoad.BuildRoadDepot(pathList.roadList[i] + direction, pathList.roadList[i])) {
						pathList.depot = pathList.roadList[i] + direction;
						break;
					}
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

function ManageVehicleAction::SellVehicle(vehicleID)
{
	vehiclesToSell.push(vehicleID);
}

function ManageVehiclesAction::BuyVehicles(engineID, number, industryConnection)
{
	for (local i = 0; i < number; i++) {
		vehiclesToBuy.push([engineID, number, industryConnection]);
	}
}

function ManageVehiclesAction::execute()
{
	foreach (engineNumber in vehiclesToBuy) {
		
		local vehicleGroup = null;
		
		// Search if there are already have a vehicle group with this engine ID.
		foreach (vGroup in engineNumber[2].vehiclesOperating) {
			if (vGroup.engineID == engineNumber[0]) {
				vehicleGroup = vGroup;
				break;
			}
		}
		
		if (vehicleGroup == null) {
			vehicleGroup = VehicleGroup();
			vehicleGroup.industryConnection = engineNumber[2];
		}
		
		for (local i = 0; i < engineNumber[1]; i++) {
			local vehicleID = AIVehicle.BuildVehicle(engineNumber[0], engineNumber[2].pathList.depot);
			vehicleGroup.vehicleIDs.push(vehicleID);
		}
		
		engineNumber[2].vehiclesOperating.push(vehicleGroup);
	}
	
	foreach (vehicleID in vehiclesToSell) {
		AIVehicle.SellVehicle(vehicleID);
	}
}