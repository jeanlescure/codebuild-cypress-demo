import { hot } from 'react-hot-loader';
import React, { useState } from 'react';
import './App.css';

const App = () => {
  const [message, setMessage] = useState('Welcome to codebuild-cypress-demo');
  return (
    <div className="App">
      <h1>{message}</h1>
      <button
        type="button"
        onClick={() => {
          setMessage('Button clicked!');
        }}
      >
        hello world
      </button>
    </div>
  );
};

export default hot(module)(App);
