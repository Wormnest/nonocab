class Action
{
	/**
	 * Empty constructor.
	 */
	constructor() { }
}
/**
 * Executes the action.
 */
function Action::execute() { }

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
