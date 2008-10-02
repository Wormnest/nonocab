/**
 * Utility date functions.
 */
class Date {

	/**
	 * Not 100% correct, but I don't care :)
	 */
	static function GetDaysBetween(date1, date2) {
	
		if (date1 < date2) {
			local tmpDate = date1;
			date1 = date2;
			date2 = tmpDate;
		}
		
		local difference = (AIDate.GetYear(date1) * World.DAYS_PER_YEAR + AIDate.GetMonth(date1) * World.DAYS_PER_MONTH + AIDate.GetDayOfMonth(date1)) - (AIDate.GetYear(date2) * World.DAYS_PER_YEAR + AIDate.GetMonth(date2) * World.DAYS_PER_MONTH + AIDate.GetDayOfMonth(date2));	
		return difference;
	}
	
	static function ToString(date) {
		return AIDate.GetDayOfMonth(date) + "/" + AIDate.GetMonth(date) + "/" + AIDate.GetYear(date);
	}
}