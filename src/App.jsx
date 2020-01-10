import { hot } from 'react-hot-loader';
import React from 'react';
import './App.css';

const message = 'Welcome to codebuild-cypress-demo';
const App = () => (
  <div className="App">
    <h1>{message}</h1>
    <button type="button">hello world</button>
  </div>
);

export default hot(module)(App);
