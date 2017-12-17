/**
 * Handle all the finance details. Since we only have 1 bank account we make
 * this class singular.
 */
class Finance {

	static minimumBankReserve = 5000;
	
	/**
	 * Returns the maximum amount of money that can be spend.
	 */
	function GetMaxMoneyToSpend();
	
	/**
	 * Get the specified amount of money.
	 * @param AmountNeeded The amount of money we need.
	 * @return true if we got the money needed, false if not.
	 */
	function GetMoney(AmountNeeded);
	
	/**
	 * Checks whether we have less than minimumBankReserve in our balance and if necessary increases our loan.
	 */
	function CheckNegativeBalance();
	
	/**
	 * Get the maximum loan.
	 */
	function GetMaxLoan();
	
	/**
	 * Repay as much as possible.
	 */
	function RepayLoan();

	/**
	 * Check if we are allowed to build with the current amount of money.
	 */
	function ConstructionAllowed();
	
	/**
	 * Get the income we generate per month.
	 */
	 function GetProjectedIncomePerMonth();
}

function Finance::GetMaxMoneyToSpend() {
	local balance = AICompany.GetBankBalance(AICompany.COMPANY_SELF)
	if (balance >= 2147483647)
		return balance;

	return AICompany.GetBankBalance(AICompany.COMPANY_SELF) + AICompany.GetMaxLoanAmount() - AICompany.GetLoanAmount() - Finance.minimumBankReserve;
}

function Finance::GetMoney(AmountNeeded) {
	local loanMode = AIExecMode();
	local Cash = AICompany.GetBankBalance(AICompany.COMPANY_SELF) - Finance.minimumBankReserve;
	
	if (AmountNeeded <= Cash) {
		// We have enough cash on hand
		return true;
	}
	else if (AmountNeeded > Finance.GetMaxMoneyToSpend()) {
		// Not enough cash nor can we loan enough to get the required amount
		/// @todo Maybe we should try to loan as much as we can anyway? Or let the caller handle this situation.
		return false;
	}
	else {
		// We need to loan more money so request the amount we need besides current cash
		local Needed = AmountNeeded - Cash;

		local gotloan = AICompany.SetMinimumLoanAmount(AICompany.GetLoanAmount() + Needed);
		//Log.logDebug("We needed " + AmountNeeded + ", we tried to loan " + Needed + ". Cash now " + AICompany.GetBankBalance(AICompany.COMPANY_SELF));
		return gotloan;
	}
}

function Finance::CheckNegativeBalance() {
	local loanMode = AIExecMode();
	local Cash = AICompany.GetBankBalance(AICompany.COMPANY_SELF);
	// Make sure we have at least some money unless we haven't spent anything yet (0 cash and no loan)
	if (Cash < Finance.minimumBankReserve && (Cash != 0 || AICompany.GetLoanAmount() > 0))
		Finance.GetMoney(Finance.minimumBankReserve);
}

function Finance::GetMaxLoan() {
	local loanMode = AIExecMode();
	AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
}

function Finance::RepayLoan() {
	local loanMode = AIExecMode();
	if (AICompany.GetBankBalance(AICompany.COMPANY_SELF) == AICompany.GetLoanAmount()) {
		// Get rid of the default amount of loan we have at startup.
		AICompany.SetLoanAmount(0);
		return;
	}
	local loanInterval = AICompany.GetLoanInterval();
	while (AICompany.GetBankBalance(AICompany.COMPANY_SELF) - loanInterval > Finance.minimumBankReserve && AICompany.SetLoanAmount(AICompany.GetLoanAmount() - loanInterval));
}

function Finance::ConstructionAllowed() {
	return Finance.GetMaxMoneyToSpend() >= AICompany.GetMaxLoanAmount() * 0.8;
}

function Finance::GetProjectedIncomePerMonth() {

	local tailSize = 6;
	if (AICompany.EARLIEST_QUARTER < 6)
		tailSize = AICompany.EARLIEST_QUARTER;

	local averageGains = 0;
	for (local i = AICompany.CURRENT_QUARTER; i < tailSize; i++) {
		averageGains += AICompany.GetQuarterlyIncome(AICompany.COMPANY_SELF, i) + AICompany.GetQuarterlyExpenses(AICompany.COMPANY_SELF, i);
	}
	return averageGains / (tailSize + 3);
}