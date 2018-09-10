import React, { Component } from 'react'
import PropTypes from 'prop-types';
import './TransactionPageLayout.css';

class TransactionPageLayout extends Component {

  constructor(props, context) {
      super(props)

      // This binding is necessary to make `this` work in the callback
      this.selectPage = this.selectPage.bind(this);
  }
  
  componentDidMount() {
  }

  selectPage(page) {
  }
  
  render() {
    
    return (
        <div>
            Test page
        </div>
    )
  }
}

TransactionPageLayout.contextTypes = {
  drizzle: PropTypes.object
}

export default TransactionPageLayout
