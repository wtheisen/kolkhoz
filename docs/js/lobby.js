// Lobby entry point - handles game creation

import { GameState } from './core/GameState.js';
import { GameStorage } from './storage/GameStorage.js';

const VARIANT_SETTINGS_KEY = 'kolkhoz_last_variant_settings';

function saveVariantSettings(settings) {
  try {
    localStorage.setItem(VARIANT_SETTINGS_KEY, JSON.stringify(settings));
  } catch (e) {
    console.warn('Failed to save variant settings:', e);
  }
}

function loadVariantSettings() {
  try {
    const saved = localStorage.getItem(VARIANT_SETTINGS_KEY);
    if (saved) {
      return JSON.parse(saved);
    }
  } catch (e) {
    console.warn('Failed to load variant settings:', e);
  }
  return null;
}

function applyVariantSettings(settings) {
  if (!settings) return;
  
  // Apply deck type first
  const deckType = settings.deckType || '36';
  const deckTypeRadio = document.querySelector(`input[name="deckType"][value="${deckType}"]`);
  if (deckTypeRadio) {
    deckTypeRadio.checked = true;
  }
  
  // Apply checkboxes
  if (settings.northernStyle !== undefined) {
    document.getElementById('northern-style').checked = settings.northernStyle;
  }
  if (settings.nomenclature !== undefined) {
    document.getElementById('nomenclature').checked = settings.nomenclature;
  }
  if (settings.miceVariant !== undefined) {
    document.getElementById('mice-variant').checked = settings.miceVariant;
  }
  // ordenNachalniku only valid for 36-card deck
  if (deckType === '36') {
    if (settings.ordenNachalniku !== undefined) {
      document.getElementById('orden-nachalniku').checked = settings.ordenNachalniku;
    }
    // If undefined, leave it as HTML default (checked)
  } else {
    document.getElementById('orden-nachalniku').checked = false;
  }
  if (settings.medalsCount !== undefined) {
    document.getElementById('medals-count').checked = settings.medalsCount;
  }
  // accumulateUnclaimedJobs only valid for 52-card deck
  if (settings.accumulateUnclaimedJobs !== undefined && deckType === '52') {
    document.getElementById('accumulate-jobs').checked = settings.accumulateUnclaimedJobs;
  } else {
    document.getElementById('accumulate-jobs').checked = false;
  }
  if (settings.allowSwap !== undefined) {
    document.getElementById('allow-swap').checked = settings.allowSwap;
  }
}

window.addEventListener('DOMContentLoaded', () => {
  // Check if localStorage is supported
  if (!GameStorage.isSupported()) {
    alert('Your browser does not support game saving. Progress will not be saved.');
  }

  // Show continue button if saved game exists
  const continueBtn = document.getElementById('continue-game');
  if (GameStorage.exists()) {
    continueBtn.style.display = 'inline-block';
  }

  // Get modal elements
  const modal = document.getElementById('variant-modal');
  const startGameBtn = document.getElementById('start-game');
  const modalClose = document.getElementById('modal-close');
  const modalCancel = document.getElementById('modal-cancel');
  const variantForm = document.getElementById('variant-form');

  // Show modal when Start Game is clicked
  startGameBtn.addEventListener('click', () => {
    modal.style.display = 'flex';
  });

  // Close modal handlers
  const closeModal = () => {
    modal.style.display = 'none';
  };

  modalClose.addEventListener('click', closeModal);
  modalCancel.addEventListener('click', closeModal);

  // Close modal when clicking backdrop
  modal.querySelector('.modal-backdrop').addEventListener('click', closeModal);

  // Show/hide 36-card deck specific options
  const deckTypeRadios = document.querySelectorAll('input[name="deckType"]');
  const ordenOption = document.getElementById('orden-nachalniku-option');
  const accumulateJobsOption = document.getElementById('accumulate-jobs');
  const accumulateJobsContainer = accumulateJobsOption.closest('.variant-option');
  
  const updateVariantVisibility = () => {
    const selectedDeck = document.querySelector('input[name="deckType"]:checked').value;
    if (selectedDeck === '36') {
      ordenOption.style.display = 'block';
      // Disable and hide accumulate unclaimed jobs option for 36-card deck
      accumulateJobsContainer.style.display = 'none';
      accumulateJobsOption.checked = false;
    } else {
      ordenOption.style.display = 'none';
      document.getElementById('orden-nachalniku').checked = false;
      // Show accumulate unclaimed jobs option for 52-card deck
      accumulateJobsContainer.style.display = 'block';
    }
  };
  
  deckTypeRadios.forEach(radio => {
    radio.addEventListener('change', updateVariantVisibility);
  });
  
  // Load and apply saved variant settings
  const savedSettings = loadVariantSettings();
  if (savedSettings) {
    applyVariantSettings(savedSettings);
  }
  
  // Initial visibility update (after loading settings)
  updateVariantVisibility();

  // Handle form submission
  variantForm.addEventListener('submit', (e) => {
    e.preventDefault();

    // Read deck type selection
    const deckType = document.querySelector('input[name="deckType"]:checked').value;
    
    // Read variant selections
    const northernStyle = document.getElementById('northern-style').checked;
    const nomenclature = document.getElementById('nomenclature').checked;
    const miceVariant = document.getElementById('mice-variant').checked;
    const ordenNachalniku = document.getElementById('orden-nachalniku').checked;
    const medalsCount = document.getElementById('medals-count').checked;
    const accumulateUnclaimedJobs = document.getElementById('accumulate-jobs').checked;
    const allowSwap = document.getElementById('allow-swap').checked;

    // Save variant settings for next time
    saveVariantSettings({
      deckType: deckType,
      northernStyle: northernStyle,
      nomenclature: nomenclature,
      miceVariant: miceVariant,
      ordenNachalniku: ordenNachalniku,
      medalsCount: medalsCount,
      accumulateUnclaimedJobs: accumulateUnclaimedJobs,
      allowSwap: allowSwap
    });

    // Create game with selected variants
    // Note: deckType '52' = Колхоз, deckType '36' = Колхозик (game name)
    const game = new GameState(4, {
      deckType: deckType,
      northernStyle: northernStyle,
      nomenclature: nomenclature,
      miceVariant: miceVariant,
      ordenNachalniku: ordenNachalniku && deckType === '36',  // Only valid for 36-card deck (Колхозик)
      medalsCount: medalsCount,
      accumulateUnclaimedJobs: accumulateUnclaimedJobs,
      allowSwap: allowSwap
    });
    game.setTrump();
    GameStorage.save(game);
    
    // Close modal and navigate to game
    closeModal();
    window.location.href = 'game.html';
  });

  // Continue existing game
  continueBtn.addEventListener('click', () => {
    window.location.href = 'game.html';
  });
});
