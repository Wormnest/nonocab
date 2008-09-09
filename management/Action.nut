class Action
{
	world = null;
	actionHandlers = null;
	
	/**
	 * Empty constructor.
	 */
	constructor() { }
	
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
	function AddActionHandlerFunction(handerFunction) {
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

function BankBalanceAction::Execute()
{
	Log.logInfo("Loan " + this.amount + " from the bank!");
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

function MailTruckNewOrderAction::Execute()
{
	// TODO: full load: startStation
	// TODO: unload: endStation
}

///////////////////////////////////////////////////////////////////////////////

class BuildRoadAction extends Action
{
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

function BuildRoadAction::Execute()
{
	Log.logInfo("Build a road from " + AIIndustry.GetName(industryConnection.travelToIndustryNode.industryID) + " to " + AIIndustry.GetName(industryConnection.travelFromIndustryNode.industryID) + ".");
	local abc = AIExecMode();
	if (!RoadPathFinding.CreateRoad(pathList))
		Log.logError("Failed to build a road");
	
	if (buildRoadStations) {
		local len = pathList.roadList.len();
		local a = pathList.roadList[0];
		AIRoad.BuildRoadStation(pathList.roadList[0].tile, pathList.roadList[1].tile, true, false, true);
		AIRoad.BuildRoadStation(pathList.roadList[len - 1].tile, pathList.roadList[len - 2].tile, true, false, true);
	}
	
	if (buildDepot) {
		for (local i = 2; i < pathList.roadList.len() - 1; i++) {
			
			foreach (direction in directions) {
				if (Tile.IsBuildable(pathList.roadList[i].tile + direction) && AIRoad.CanBuildConnectedRoadPartsHere(pathList.roadList[i].tile, pathList.roadList[i].tile + direction, pathList.roadList[i + 1].tile)) {
					if (AIRoad.BuildRoadDepot(pathList.roadList[i].tile + direction, pathList.roadList[i].tile)) {
						pathList.depot = pathList.roadList[i].tile + direction;
						return;
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

function ManageVehiclesAction::SellVehicle(vehicleID)
{
	vehiclesToSell.push(vehicleID);
}

function ManageVehiclesAction::BuyVehicles(engineID, number, industryConnection)
{
	vehiclesToBuy.push([engineID, number, industryConnection]);
}

function ManageVehiclesAction::Execute()
{
	Log.logInfo("Buy " + vehiclesToBuy.len() + " and sell " + vehiclesToSell.len() + " vehicles.");
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
			local vehicleID = AIVehicle.BuildVehicle(engineNumber[2].pathInfo.depot, engineNumber[0]);
			if (!AIVehicle.IsValidVehicle(vehicleID))
				Log.logError("Error building vehicle: " + AIError.GetLastErrorString() + "!");
			vehicleGroup.vehicleIDs.push(vehicleID);
		}
		
		engineNumber[2].vehiclesOperating.push(vehicleGroup);
	}
	
	foreach (vehicleID in vehiclesToSell) {
		AIVehicle.SellVehicle(vehicleID);
	}
}