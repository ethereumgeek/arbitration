import TransactionManager from './../build/contracts/TransactionManager.json'

const drizzleOptions = {
  web3: {
    block: false,
    fallback: {
      type: 'ws',
      url: 'ws://127.0.0.1:8545'
    }
  },
  contracts: [
    TransactionManager
  ],
  events: {
  },
  syncAlways: true,
  polls: {
    accounts: 1500,
    blocks: 3000
  }
}

export default drizzleOptions