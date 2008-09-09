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