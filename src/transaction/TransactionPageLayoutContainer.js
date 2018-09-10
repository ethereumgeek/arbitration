import TransactionPageLayout from './TransactionPageLayout'
import { drizzleConnect } from 'drizzle-react'

const mapStateToProps = (state, ownProps) => {
  return {
    accounts: state.accounts,
    TransactionManager: state.contracts.TransactionManager,
    drizzleStatus: state.drizzleStatus,
    web3: state.web3
  }
}

const TransactionPageLayoutContainer = drizzleConnect(TransactionPageLayout, mapStateToProps);
export default TransactionPageLayoutContainer
