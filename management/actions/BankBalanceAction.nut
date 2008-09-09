class BankBalanceAction extends Action
{
	amount = 0;
	
	/**
	 * Constructs a bankbalance transaction.
	 */
	constructor(/* int */ change)
	{
		this.amount = change;
		Action.constructor(null);
	}
}

function BankBalanceAction::Execute()
{
	Log.logInfo("Loan " + this.amount + " from the bank!");
	AICompany.SetLoanAmount(this.amount);
	CallActionHandlers();
}