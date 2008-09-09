class Report
{
	message = null;
	actions = null;
	cost = null;
	profitPerMonth = null;
    	
	/**
	 * Constructs a report.
	 */
	constructor(/*string*/ mess, /*int*/ cost, /*int*/ prof, /*Action[]*/ act)
	{
		this.message = mess;
		this.cost = cost;
		this.profitPerMonth = prof;
		this.actions = act;
	}
	
	/**
	 * The utility for a report is the profit per month divided by the cost.
	 */
	function Utility() {
		return profitPerMonth / cost;
	}
}
