require("pathfinding.nut");
require("utils.nut");
require("industry.nut");
require("collections.nut");
require("tiles.nut");

class NoCAB extends AIController {
      	stop = false;
      	company = null;

      	constructor() {	
		this.company = AICompany();
	}

	function Start();
	function Stop();
}

function NoCAB::Start()
{
	/**
	 * Set the name of our AI :)
	 */
	this.Sleep(1);

	print("Lets go!");

	if(!this.company.SetCompanyName("NoCAB")) 
	{
		local i = 2;
		while(!this.company.SetCompanyName("NoCAB #" + i))
		{
			i = i + 1;
		}
	}

	// Get max loan!
	//while(true) {
		local comp = AICompany();
		comp.SetLoanAmount(comp.GetMaxLoanAmount());

		local indus = IndustryManager();
		indus.UpdateIndustry();
        	this.Sleep(500);
	//}
	print("Done! :)");
}

function NoCAB::Stop()
{
	this.stop = true;
}

