class DemolishAction extends Action {
	connection = null;		// Connection object of the road to build.
	world = null;			// The world.
	destroyFrom = null;		// Destroy the stations from a connection.
	destroyTo = null;
	destroyDepots = null;
	
	constructor(connection, world, destroyFrom, destroyTo, destroyDepots) {
		this.connection = connection;
		this.world = world;
		this.destroyFrom = destroyFrom;
		this.destroyTo = destroyTo;
		this.destroyDepots = destroyDepots;
		Action.constructor();
	}	
}

function DemolishAction::Execute() {
	Log.logWarning("Demolish bla");
	local test = AIExecMode();
	//AISign.BuildSign(connection.travelFromNode.GetLocation(), "Demolish!");
	//AISign.BuildSign(connection.travelToNode.GetLocation(), "Demolish!");	
	connection.Demolish(destroyFrom, destroyTo, destroyDepots);
	CallActionHandlers();
	return true;
}