class Report
{
	message = null;
	actions = null;
	costs = null;
	profit = null;
	utility = null;
    	
	/**
	 * Constructs a report.
	 */
	constructor(/*string*/ mess, /*int*/ cost, /*int*/ prof, /*int*/ util,/*Action[]*/ act)
	{
		this.message = mess;
		this.costs = cost;
		this.profit = prof;
		this.utility = util;
		this.actions = act;
	}
}
