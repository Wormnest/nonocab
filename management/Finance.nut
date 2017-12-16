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

function Finance::GetMaxLoan() {
	local loanMode = AIExecMode();
	AICompany.SetLoanAmount(AICompany.GetMaxLoanAmount());
}

function Finance::RepayLoan() {
	local loanMode = AIExecMode();
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