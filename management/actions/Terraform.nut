/**
 * Handle terraform activities.
 */
class Terraform {
	
	/**
	 * Perform terraforming on a rectangle, we choose the
	 * cheapest action to do this.
	 * @param startTyle The top left tile to start from.
	 * @param width The width of the rectangle.
	 * @param height The height of the rectangle.
	 * @return True if completed, false otherwise.
	 */
	function Terraform(startTile, width, height);
	
	/**
	 * Get the number of tiles that will be changed due to terraforming.
	 * @param startTyle The top left tile to start from.
	 * @param width The width of the rectangle.
	 * @param height The height of the rectangle.
	 * @return The number of tiles that will be affected by terraforming.
	 */
	function GetAffectedTiles(startTile, width, height);


	/**
	 * Check it the nearby towns aren't going to stop the terraforming.
	 * @param startTyle The top left tile to start from.
	 * @param width The width of the rectangle.
	 * @param height The height of the rectangle.
	 * @return True if the local authoraties aren't going to complain,
	 * false otherwise.
	 */
	function CheckTownRatings(startTile, width, height);
	
	/**
	 * This function explores the terrain and determines the
	 * best height at which all land must be terraformed to.
	 * @param startType The top left tile to start from.
	 * @param width The width of the rectangle.
	 * @param height The height of the rectangle.
	 * @return An integer of the best height to terraform to.
	 */
	function CalculatePreferedHeight(startTile, width, height);
}

function Terraform::Terraform(startTile, width, height) {
	local preferedHeight = Terraform.CalculatePreferedHeight(startTile, width, height);
	if (preferedHeight == 0)
		preferedHeight = 1;
	else if (preferedHeight == -1)
		return false;

	local mapSizeX = AIMap.GetMapSizeX();
	
        for (local i =0; i < width; i++) {
		for (local j = 0; j < height; j++) {
			local tileToSearch = startTile + i + j * mapSizeX;
			if (AITile.GetHeight(tileToSearch) == preferedHeight) {

				AISign.BuildSign(tileToSearch, "HERE");
				AISign.BuildSign(startTile, "S");
				AISign.BuildSign(startTile + width, "W");
				AISign.BuildSign(startTile + height * mapSizeX, "H");
				AISign.BuildSign(startTile + width + height * mapSizeX, "WH");
				if ((tileToSearch == startTile || AITile.LevelTiles(tileToSearch, startTile)) &&
				    (tileToSearch == startTile + width || AITile.LevelTiles(tileToSearch, startTile + width)) &&
				    (tileToSearch == startTile + width + height * mapSizeX || AITile.LevelTiles(tileToSearch, startTile + width + height * mapSizeX)) &&
				    (tileToSearch == startTile + height * mapSizeX || AITile.LevelTiles(tileToSearch, startTile + height * mapSizeX)))
					return true;
				AISign.BuildSign(tileToSearch, "FAILZZZZ");
				return false;
			}
		}
	}

	return false;
}

function Terraform::GetAffectedTiles(startTile, width, height) {
	local preferedHeight = Terraform.CalculatePreferedHeight(startTile, width, height);
	if (preferedHeight == 0)
		preferedHeight = 1;
	else if (preferedHeight == -1)
		return 0;
		
	local affectedTiles = 0;
	
	for (local x = 0; x < width; x++) {
		for (local y = 0; y < height; y++) {
			local tile = startTile + x + AIMap.GetMapSizeX() * y;
			
			if (AITile.GetSlope(tile) == AITile.SLOPE_FLAT &&
				AITile.GetHeight(tile) == preferedHeight)
					continue;
			affectedTiles++;
		}
	}
	
	return affectedTiles;
}

function Terraform::CheckTownRatings(startTile, width, height) {
	local preferedHeight = Terraform.CalculatePreferedHeight(startTile, width, height);
	if (preferedHeight == 0)
		preferedHeight = 1;
	else if (preferedHeight == -1)
		return 0;
		
	local ratings = [];
	
	for (local x = 0; x < width; x++) {
		for (local y = 0; y < height; y++) {
			local tile = startTile + x + AIMap.GetMapSizeX() * y;
			
			if (AITile.GetSlope(tile) == AITile.SLOPE_FLAT &&
				AITile.GetHeight(tile) == preferedHeight)
					continue;

			if (!AITile.HasTreeOnTile(tile))
				continue;

			// Check which town this belongs to.
			local townID = AITile.GetClosestTown(tile);
			local townFound = false;
			foreach (pair in ratings) {
				if (pair[0] == townID) {
					if ((pair[1] -= 35) < -200) {
						local a = AIExecMode();
						AISign.BuildSign(tile, "TOWN FAILZZZ!");
						return false;
					}
					townFound = true;
					break;
				}
			}

			if (!townFound)
				ratings.push([townID, AITown.GetRating(townID, AICompany.COMPANY_SELF)]);
		}
	}
	
	return true;
}

function Terraform::CalculatePreferedHeight(startTile, width, height) {
	
	// Check if we have any choice; If the surrounding tiles are build we must
	// adhere to that height because we won't be able to terraform.
	local dictatedHeight = -1;
	local tilesToCheck = [];
	for (local i = -1; i < width + 1; i++) {
		tilesToCheck.push(startTile - AIMap.GetMapSizeX() + i);
		tilesToCheck.push(startTile + height * AIMap.GetMapSizeX() + i);
	}
	
	for (local i = 0; i < height; i++) {
		tilesToCheck.push(startTile - 1 + i * AIMap.GetMapSizeX());
		tilesToCheck.push(startTile + height + 1 + i * AIMap.GetMapSizeX());
	}
	
	foreach (tile in tilesToCheck) {
		local test = AIExecMode();
		if (AITile.IsBuildable(tile) || AITile.IsWaterTile(tile))
			continue;
		
		local slopeHeight = AITile.GetHeight(tile);
		local slope = AITile.GetSlope(tile);
		local neededHeight = 0;
		if (slope & AITile.SLOPE_N || slope == AITile.SLOPE_FLAT)
			neededHeight = slopeHeight;
		else
			neededHeight = slopeHeight + 1;
		
		//AISign.BuildSign(tile, "NH: " + neededHeight);	
		if (dictatedHeight == -1)
			dictatedHeight = neededHeight;
		else if (dictatedHeight != neededHeight)
			return -1;
	}
	
	if (dictatedHeight != -1)
		return dictatedHeight;
	
	// The first thing we do is try to estimate the average height
	// and use this height to determine how to terraform each square.
	local totalHeight = 0.0;
	for (local i = 0; i <= width; i++) {
		for (local j = 0; j <= height; j++) {
			local tileID = startTile + i + j * AIMap.GetMapSizeX();
			totalHeight += AITile.GetHeight(tileID);
			
			// Check slope, the slopes effect the actual height (h) as follows:
			//             N
			//             ^
			//             |
			//
			//          h | h | h
			//         ---+---+---                 
			//   W <-- h+1|h+1| h  --> E
			//         ---+---+---
			//         h+1|h+1| h
			//
			//              |
			//              v
			//              S
			
			// Steep slopes
			//             N
			//             ^
			//             |
			//
			//         h+1|   | h
			//         ---+---+---                 
			//   W <--    |h+2|      --> E
			//         ---+---+---
			//         h+2|   |h+1
			//
			//              |
			//              v
			//              S			
			local slope = AITile.GetSlope(tileID);
			if (slope == AITile.SLOPE_FLAT)
				continue;

			if (slope & AITile.SLOPE_N) 
			    totalHeight -= 0.5;
			else if (!(slope & AITile.SLOPE_STEEP))
				totalHeight += 0.5
			else if (slope == AITile.SLOPE_STEEP_S)
				totalHeight++;
			else if (slope == AITile.SLOPE_STEEP_N)
				totalHeight--;
		}
	}
	
	// Because Squirrel rounds integers by removing all numbers
	// after the comma we round it properly.
	local mean = (totalHeight / ((width + 1) * (height + 1)));
	local meanInt = mean.tointeger();
	local meanFrac = mean - meanInt;
	if (meanFrac <= 0.5)
		return meanInt;
	else
		return meanInt + 1;
}
