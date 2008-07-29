class Report
{
	message = "";
	actions = array(0);
	costs = 0;
	profit = 0;
	utility = 0;
    	
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
