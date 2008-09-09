class BuildIndustryRoadAction extends BuildRoadAction 
{
	industryConnection = null;
	
	constructor(industryConnection, buildDepot, buildRoadStations) {
		BuildRoadAction.constructor(industryConnection.pathInfo, buildDepot, buildRoadStations);
		this.industryConnection = industryConnection;
	}
	
	function Execute() {
		Log.logInfo("Build a road from " + AIIndustry.GetName(industryConnection.travelToIndustryNode.industryID) + " to " + AIIndustry.GetName(industryConnection.travelFromIndustryNode.industryID) + ".");
		BuildRoadAction.Execute();
	}
}