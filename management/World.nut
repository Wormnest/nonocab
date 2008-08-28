/**
 * World holds the current status of the world as the AI sees it.
 */
class World
{

	town_list = null;				// List with all towns.
	connection_list = null;				// List with all active connections.
	industry_list = null;				// List with all industries.

	/**
	 * Initializes a repesentation of the 'world'.
	 */
	constructor()
	{
		town_list = AITownList();
		industry_list = AIIndustryList();
		connection_list = [];
	}
}


