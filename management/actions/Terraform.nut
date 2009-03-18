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
	
	// With the prefered height in hand, lets get busy!
	// Make the first tile flat and the correct level and make the other tiles
	// the same height.
	local slope = AITile.GetSlope(startTile);
	local tileHeight = AITile.GetHeight(startTile);
	local raiseSlope = false;
	
	//AISign.BuildSign(startTile, "T");
	
	// Rules to lower a tile.
	if (tileHeight > preferedHeight ||
	!(slope & AITile.SLOPE_N) && tileHeight == preferedHeight) {
		
		local slopeTip = AITile.SLOPE_INVALID;
		if (slope == AITile.SLOPE_STEEP_N)
			slopeTip = AITile.SLOPE_N;
		else if (slope == AITile.SLOPE_STEEP_W)
			slopeTip = AITile.SLOPE_W;
		else if (slope == AITile.SLOPE_STEEP_S)
			slopeTip = AITile.SLOPE_S;
		else if (slope == AITile.SLOPE_STEEP_E)
			slopeTip = AITile.SLOPE_E;
		
		if (slopeTip != AITile.SLOPE_INVALID)		
			AITile.LowerTile(startTile, slopeTip);
			
		if (slopeTip == AITile.SLOPE_INVALID || slopeTip != AITile.SLOPE_N)
			AITile.LowerTile(startTile, slope);
		else
			AITile.RaiseTile(startTile, AITile.GetComplementSlope(slope));
		
		for (local i = AITile.GetHeight(startTile); i > preferedHeight; i--)
			AITile.LowerTile(startTile, AITile.SLOPE_ELEVATED);
	}
	
	// Rules to make a tile higher.
	else if (tileHeight < preferedHeight ||
		slope & AITile.SLOPE_N && tileHeight == preferedHeight) {
		
		local slopeTip = AITile.SLOPE_INVALID;
		if (slope == AITile.SLOPE_STEEP_N)
			slopeTip = AITile.SLOPE_S;
		else if (slope == AITile.SLOPE_STEEP_W)
			slopeTip = AITile.SLOPE_E;
		else if (slope == AITile.SLOPE_STEEP_S)
			slopeTip = AITile.SLOPE_N;
		else if (slope == AITile.SLOPE_STEEP_E)
			slopeTip = AITile.SLOPE_W;
		
		if (slopeTip != AITile.SLOPE_INVALID) {		
			AITile.RaiseTile(startTile, slopeTip);
			
			// Reevaluate the slope since it has changed now.
			slope = AITile.GetSlope(startTile);
		}		
		
		if (slopeTip == AITile.SLOPE_INVALID || slopeTip != AITile.SLOPE_N)
			AITile.RaiseTile(startTile, AITile.GetComplementSlope(slope));
		else
			AITile.LowerTile(startTile, slope);
//		AITile.RaiseTile(startTile, AITile.GetComplementSlope(slope));
		raiseSlope = true;
		
		for (local i = AITile.GetHeight(startTile); i < preferedHeight; i++)
			AITile.RaiseTile(startTile, AITile.SLOPE_ELEVATED);
	}
	
//	AISign.BuildSign(startTile, "Raise to height: " + preferedHeight);
//	AISign.BuildSign(startTile + width + height * AIMap.GetMapSizeX(), "Level to here!");
	
	if (AITile.GetHeight(startTile) != preferedHeight)
		return false;
	
	if (!AITile.LevelTiles(startTile, startTile + width + height * AIMap.GetMapSizeX()))
		return false;
	return true;
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