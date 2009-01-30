/**
 * Handle terraform activities.
 */
class Terraform {
	
	/**
	 * Perform terraforming on a rectangle, we choose the
	 * cheapest action to do this.
	 * @param startType The top left tile to start from.
	 * @param width The width of the rectangle.
	 * @param height The height of the rectangle.
	 * @return True if completed, false otherwise.
	 */
	function Terraform(startTile, width, height);
	
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
	
	// With the prefered height in hand, lets get busy!
	// Make the first tile flat and the correct level and make the other tiles
	// the same height.
	local slope = AITile.GetSlope(startTile);
	local tileHeight = AITile.GetHeight(startTile);
	local raiseSlope = false;
	
	Log.logWarning("Prefered height: " + preferedHeight);
	
	// Rules to lower a tile.
	if (tileHeight > preferedHeight ||
	slope != AITile.SLOPE_N &&
	slope != AITile.SLOPE_NE &&
	slope != AITile.SLOPE_NW &&
	slope != AITile.SLOPE_NWS &&
	slope != AITile.SLOPE_SEN &&
	slope != AITile.SLOPE_ENW &&
	slope != AITile.SLOPE_NS &&
	tileHeight == preferedHeight) {
		
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
		AITile.LowerTile(startTile, slope);
	}
	
	// Rules to make a tile higher.
	else if (tileHeight < preferedHeight ||
		(slope == AITile.SLOPE_N ||
		slope == AITile.SLOPE_NE ||
		slope == AITile.SLOPE_NW ||
		slope == AITile.SLOPE_NWS ||
		slope == AITile.SLOPE_SEN ||
		slope == AITile.SLOPE_ENW ||
		slope == AITile.SLOPE_NS) &&
		tileHeight == preferedHeight) {
		
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
		
		
		AITile.RaiseTile(startTile, AITile.GetComplementSlope(slope));
		raiseSlope = true;
	}
	
	AITile.LevelTiles(startTile, startTile + width + height * AIMap.GetMapSizeX());
}

function Terraform::CalculatePreferedHeight(startTile, width, height) {
	
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
							
			if (slope == AITile.SLOPE_N ||
				slope == AITile.SLOPE_NE ||
				slope == AITile.SLOPE_NW ||
				slope == AITile.SLOPE_NWS ||
				slope == AITile.SLOPE_SEN ||
				slope == AITile.SLOPE_ENW ||
				slope == AITile.SLOPE_NS) 
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