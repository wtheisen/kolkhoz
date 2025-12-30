// Game constants for Kolkhoz

export const SUITS = ['Hearts', 'Diamonds', 'Clubs', 'Spades'];

// Card values: 6-10 are number cards, 11=Jack, 12=Queen, 13=King
export const VALUES = [6, 7, 8, 9, 10, 11, 12, 13];

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

// Job names (Russian) mapped to suits
export const JOB_NAMES = {
  Hearts: 'Пахота',      // Plowing
  Diamonds: 'Жатва',     // Harvesting
  Clubs: 'Мастерская',   // Workshop
  Spades: 'Зерно'        // Grain
};

// Default game variants
export const DEFAULT_VARIANTS = {
  deckType: 36,           // 36 or 52 card deck
  nomenclature: true,     // Face card special effects
  allowSwap: false,       // Swap hand/plot at year start
  northernStyle: false,   // No job rewards, all vulnerable
  miceVariant: false,     // All reveal during requisition
  ordenNachalniku: false, // Stack cards (36-card only)
  medalsCount: false,     // Tricks contribute to score
  accumulateJobs: false,  // Unclaimed jobs carry over (52-card)
};
