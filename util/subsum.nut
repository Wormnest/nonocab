/**
 * Subsum algorithm.
 */
 class SubSum 
 {
 	
 	/**
 	 * This function goes through the items in the list and tries to get the
 	 * best subsum from the list that yield the most profit but doesn't cost
 	 * more then max.
 	 * @param list A sorted data structure which has the following function:
 	 * Pop() which returns the item with the lowest value and removes it from
 	 * the data structure. The content of the list must be an instance of Report.
 	 * @param max The maximum cost all subsum values added together.
 	 * @return A list of reports which yield the maximum utility (or at least as
 	 * close as possible) and which costs doesn't exceed max.
 	 */
 	static function GetSubSum(reportList, max) {
 		local report = null;
 		local subsumList = [];
		while ((report = reportList.Pop()) != null) {
			
			// Check if we can afford it.
			if (max > report.costForRoad + report.costPerVehicle) {
				subsumList.push(report);
				max -= report.costForRoad + report.costPerVehicle * report.nrVehicles;
			}
		}
 		return subsumList;
 	}
 }