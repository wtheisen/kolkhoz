// Game constants for Kolkhoz

export const SUITS = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

// Work hours threshold to complete a job
export const THRESHOLD = 40;

// Maximum years in the game (Five-Year Plan)
export const MAX_YEARS = 5;

// Russian names for AI players
export const PLAYER_NAMES = [
  'Иван',
  'Дмитрий',
  'Алёша',
  'Фёдор',
  'Грушенька',
  'Катерина'
];

// Default game variants
export const DEFAULT_VARIANTS = {
  deckType: 52,           // 36 or 52 card deck
  nomenclature: true,     // Face card special effects
  allowSwap: true,        // Swap hand/plot at year start
  northernStyle: false,   // No job rewards, all vulnerable
  miceVariant: false,     // All reveal during requisition
  ordenNachalniku: false, // Stack cards (36-card only)
  medalsCount: false,     // Tricks contribute to score
  accumulateJobs: false,  // Unclaimed jobs carry over (52-card)
};
