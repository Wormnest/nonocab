/**
 * World holds the current status of the world as the AI sees it.
 */
class World
{

	industry_list = null;				// List with all industries.
	town_list = null;				// List with all towns.
	connection_list = null;			// List with all active connections.
	industry_tree = null;				// Tree with all industries and their interconnections.

	/**
	 * Initializes a repesentation of the 'world'.
	 */
	constructor()
	{
		industry_list = AIIndustryList();
		town_list = AITownList();
		connection_list = [];
	}


	//
	// Primary economies -> Secondary economies -> Towns
	// Town <-> town
	//
	//
}
