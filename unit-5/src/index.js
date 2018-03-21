import React from 'react';
import ReactDOM from 'react-dom';
import '../node_modules/material-components-web/dist/material-components-web.min.css';
import App from './App';
import registerServiceWorker from './registerServiceWorker';

ReactDOM.render(<App />, document.getElementById('root'));
registerServiceWorker();
