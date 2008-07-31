class MailAdvisor extends Advisor {}

/**
 * Controls the mail trucks. We could call this the TNT or UPC advisor aswell.
 *
 *  There are basicly these options:
 *  - Build new mail truck.
 *  - Sell mail truck.
 *  - Add new orders to mail truck.
 */
function MailAdvisor::getReports()
{
	local DELIVERY_PROFIT = 500;
	local reports = array(0);
	
//	// Get all available mail trucks.
//	local trucklist = this.innerWorld.GetTrucks(Mail);
//	// Add orders for all trucks.
//	
//	foreach(truck in trucklist)
//	{
//		// If there are not more than two orders, plan a new delivery.
//		// Search for a mail station neary by that is fully packed.
//		// Search for a delivery station on a 'some' distance.
//		if(truck.orders.count < 2)
//		{
//			local start = null;
//			local end = null;
//			report.add(Report("New delivery.",0 , 0, DELIVERY_PROFIT, DeliverMailAction(start, end)));
//		}
//		// If the first order is done, remove it.
//		else if(TODO)
//		{
//			report.add(TODO
//		}
//	}	
	return reports;
}