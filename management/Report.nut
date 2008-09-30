/**
 * This class is the base class for all reports which can be constructed and
 * presented to the Parlement for selection and execution. A report consists 
 * of a list of actions which must be executed if this reports is selecte for
 * execution. 
 *
 * All reports in this framework calculate their Utility as the netto profit
 * per month times the actual number of months over which this netto profit 
 * is gained!
 */
class Report
{
	
	actions = null;						// The list of actions.
	brutoIncomePerMonth = 0;			// The bruto income per month.
	brutoCostPerMonth = 0;				// The bruto cost per month.
	initialCost = 0;					// Initial cost, which is only paid once!
	runningTimeBeforeReplacement = 0;	// The running time in which profit can be made.
	
	/**
	 * The utility for a report is the netto profit per month times
 	 * the actual number of months over which this netto profit is 
 	 * gained!
	 */
	function Utility() {
		return (brutoIncomePerMonth - brutoCostPerMonth) * runningTimeBeforeReplacement - initialCost;
	}
	
	function ToString() {
		return "Bruto income: " + brutoIncomePerMonth + "; BrutoCost: " + brutoCostPerMonth + "; Running time: " + runningTimeBeforeReplacement + "; Init cost: " + initialCost + ".";
	}
}
