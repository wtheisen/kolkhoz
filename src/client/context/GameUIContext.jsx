import React, { createContext, useContext, useState, useRef, useCallback } from 'react';

const GameUIContext = createContext(null);

export function GameUIProvider({ children }) {
  // Panel state
  const [activePanel, setActivePanel] = useState(null);
  const togglePanel = useCallback((panel) => {
    setActivePanel(prev => prev === panel ? null : panel);
  }, []);

  // Language state (persisted to localStorage)
  const [language, setLanguage] = useState(() =>
    localStorage.getItem('kolkhoz-lang') || 'ru'
  );
  const toggleLanguage = useCallback(() => {
    setLanguage(lang => {
      const newLang = lang === 'en' ? 'ru' : 'en';
      localStorage.setItem('kolkhoz-lang', newLang);
      return newLang;
    });
  }, []);

  // Drag states
  const [dragState, setDragState] = useState(null);
  const [swapDragState, setSwapDragState] = useState(null);
  const [assignDragState, setAssignDragState] = useState(null);

  // Refs for drag targets
  const trickAreaRef = useRef(null);
  const plotCardRefs = useRef({});
  const handCardRefs = useRef({});
  const plotDropRefs = useRef({});
  const assignCardRefs = useRef({});
  const jobDropRefs = useRef({});

  const value = {
    // Panel
    activePanel,
    setActivePanel,
    togglePanel,
    // Language
    language,
    setLanguage,
    toggleLanguage,
    // Drag states
    dragState,
    setDragState,
    swapDragState,
    setSwapDragState,
    assignDragState,
    setAssignDragState,
    // Refs
    trickAreaRef,
    plotCardRefs,
    handCardRefs,
    plotDropRefs,
    assignCardRefs,
    jobDropRefs,
  };

  return (
    <GameUIContext.Provider value={value}>
      {children}
    </GameUIContext.Provider>
  );
}

export function useGameUI() {
  const context = useContext(GameUIContext);
  if (!context) {
    throw new Error('useGameUI must be used within a GameUIProvider');
  }
  return context;
}

export default GameUIContext;
