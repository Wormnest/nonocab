class Report
{
	message = null;
	actions = null;
	cost = null;
	profitPerMonth = null;
    	
	/**
	 * Constructs a report.
	 */
	constructor(/*string*/ mess, /*int*/ costs, /*int*/ prof, /*Action[]*/ act)
	{
		message = mess;
		cost = costs;
		profitPerMonth = prof;
		actions = act;
	}
	
	/**
	 * The utility for a report is the profit per month divided by the cost.
	 */
	function Utility() {
		
		//return (profitPerMonth * World.GetMonthsRemaining() - cost * World.GetBankInterestRate()) * -cost;
		if(profitPerMonth != null){ return 0; }
		return profitPerMonth / cost;
	}
}
