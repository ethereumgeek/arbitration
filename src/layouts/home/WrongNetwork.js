import React, { Component } from 'react';
import './WrongNetwork.css';

class WrongNetwork extends Component {
    constructor(props) {
        super(props);
        this.state = {
        };
    }

    componentDidMount() {
    }

    render() {

        return (
            <div className="loadingCnt">
                 <h1>🦊</h1>
                <p>Please check and make sure Metamask is using Rinkeby Test Network...</p>
            </div>
        );
    }
  }
  
  export default WrongNetwork;