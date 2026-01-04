import React from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App.jsx';
import './styles/variables.css';
import './styles/base.css';
import './styles/lobby.css';

const root = createRoot(document.getElementById('root'));
root.render(<App />);
