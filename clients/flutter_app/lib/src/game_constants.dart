const kolkhozPlayerCount = 4;
const finalGameYear = 5;
const displaySuitOrder = ['wheat', 'sunflower', 'potato', 'beet'];
const wreckerSuit = 'wrecker';
const jobRequiredHours = 40;

const controllerHuman = 'human';
const controllerRemoteHuman = 'remoteHuman';
const controllerHeuristicAI = 'heuristicAI';
const controllerMediumAI = 'mediumAI';
const controllerNeuralAI = 'neuralAI';

const viewerPrivacyNone = 'none';
const viewerPrivacyHotSeatHidden = 'hotSeatHidden';

const plotZoneHidden = 'hidden';
const plotZoneRevealed = 'revealed';

const phasePlanning = 'planning';
const phaseSwap = 'swap';
const phaseTrick = 'trick';
const phaseAssignment = 'assignment';
const phaseRequisition = 'requisition';
const phaseGameOver = 'gameOver';

const panelBrigade = 'brigade';
const panelJobs = 'jobs';
const panelPlot = 'plot';
const panelNorth = 'north';
const panelLog = 'log';
const panelOptions = 'options';
const availableGamePanels = [
  panelBrigade,
  panelJobs,
  panelPlot,
  panelNorth,
  panelLog,
  panelOptions,
];

const actionSetTrump = 'setTrump';
const actionSwap = 'swap';
const actionConfirmSwap = 'confirmSwap';
const actionPlayCard = 'playCard';
const actionAssign = 'assign';
const actionSubmitAssignments = 'submitAssignments';
const actionContinueAfterRequisition = 'continueAfterRequisition';
const actionUndoSwap = 'undoSwap';
const actionUnknown = 'unknown';
