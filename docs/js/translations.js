// Centralized Russian-English translations
// Edit this file to update all translations throughout the application

export const translations = {
  // Game variant names
  'Колхоз': 'Kolkhoz (Collective Farm)',
  'Колхозик': 'Kolkhozik (Little Collective Farm)',
  'Зонский режим': 'Zonsky Regime (Zone Regime)',
  
  // Variant options
  'по-северному': 'The northern way',
  'Номенклатура живёт по своим законам': 'The nomenklatura lives by its own laws',
  'Разговоры вели даже с мышами': 'They had conversations with even the mice',
  'Орден — начальнику, работа — нам': 'The medal goes to the boss, the work goes to us',
  'Поменять шило на мыло': 'Swap an Awl for Soap',
  
  // Game terms
  'года': 'Year',
  'поля': 'Fields',
  'Наша главная задача:': 'Our Main Task:',
  'ГУЛАГ:': 'GULAG:',
  'Бригадир': 'Brigade Leader',
  'работа': 'Field',
  'поле': 'Field',
  'подвал': 'Cellar',
  'отправить на Север': 'Sent to the North',
  
  // Face card names
  'Пьяница': 'Drunkard',
  'Информатор': 'Informant',
  'партийец': 'Party Member'
};

/**
 * Get translation for a Russian text
 * @param {string} russianText - The Russian text to translate
 * @returns {string} The English translation, or the original text if not found
 */
export function getTranslation(russianText) {
  return translations[russianText] || russianText;
}

/**
 * Get all translations as an object
 * @returns {Object} All translations
 */
export function getAllTranslations() {
  return translations;
}
