/**
 * Number Guessing Game Logic
 */

// --- DOM Elements Selection ---
const welcomeScreen = document.getElementById('welcome-screen');
const levelScreen = document.getElementById('level-screen');
const gameScreen = document.getElementById('game-screen');
const settingsScreen = document.getElementById('settings-screen');
const prizesScreen = document.getElementById('prizes-screen');

const playBtn = document.getElementById('play-btn');
const settingsBtn = document.getElementById('settings-btn');
const prizesBtn = document.getElementById('prizes-btn');
const backSettingsBtn = document.getElementById('back-settings-btn');
const backPrizesBtn = document.getElementById('back-prizes-btn');
const levelButtons = document.querySelectorAll('.btn-level');

const soundToggle = document.getElementById('sound-toggle');
const prizeCountEl = document.getElementById('prize-count');
const prizeListEl = document.getElementById('prize-list');

const minValEl = document.getElementById('min-val');
const maxValEl = document.getElementById('max-val');
const guessInput = document.getElementById('guess-input');
const guessBtn = document.getElementById('guess-btn');
const feedbackText = document.getElementById('feedback-text');
const attemptsCountEl = document.getElementById('attempts-count');
const actionsContainer = document.querySelector('.actions');
const newGameBtn = document.getElementById('new-game-btn');
const changeLevelBtn = document.getElementById('change-level-btn');

// --- Game State Variables ---
let currentMin = 0;
let currentMax = 10;
let secretNumber = 0;
let maxLives = 3;
let currentLives = 3;
let gameOver = false;
let totalPrizes = parseInt(localStorage.getItem('guessPrizes') || '0');

// --- Sound Logic ---
let soundEnabled = true;
const audioCtx = new (window.AudioContext || window.webkitAudioContext)();

function playSound(type) {
    if (!soundEnabled) return;
    if (audioCtx.state === 'suspended') audioCtx.resume();
    
    const oscillator = audioCtx.createOscillator();
    const gainNode = audioCtx.createGain();
    
    oscillator.connect(gainNode);
    gainNode.connect(audioCtx.destination);
    
    if (type === 'tap') {
        oscillator.type = 'sine';
        oscillator.frequency.setValueAtTime(600, audioCtx.currentTime);
        oscillator.frequency.exponentialRampToValueAtTime(300, audioCtx.currentTime + 0.1);
        gainNode.gain.setValueAtTime(0.1, audioCtx.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.1);
        oscillator.start();
        oscillator.stop(audioCtx.currentTime + 0.1);
    } else if (type === 'win') {
        oscillator.type = 'triangle';
        oscillator.frequency.setValueAtTime(523.25, audioCtx.currentTime); 
        oscillator.frequency.setValueAtTime(659.25, audioCtx.currentTime + 0.1); 
        oscillator.frequency.setValueAtTime(783.99, audioCtx.currentTime + 0.2); 
        oscillator.frequency.setValueAtTime(1046.50, audioCtx.currentTime + 0.3); 
        gainNode.gain.setValueAtTime(0.1, audioCtx.currentTime);
        gainNode.gain.linearRampToValueAtTime(0, audioCtx.currentTime + 0.5);
        oscillator.start();
        oscillator.stop(audioCtx.currentTime + 0.5);
    }
}

// --- Event Listeners ---

// Global tap sound
document.querySelectorAll('button').forEach(btn => {
    btn.addEventListener('click', () => playSound('tap'));
});

// 0. Welcome Screen Buttons
playBtn.addEventListener('click', () => {
    welcomeScreen.classList.remove('active');
    levelScreen.classList.add('active');
});

settingsBtn.addEventListener('click', () => {
    welcomeScreen.classList.remove('active');
    settingsScreen.classList.add('active');
});
backSettingsBtn.addEventListener('click', () => {
    settingsScreen.classList.remove('active');
    welcomeScreen.classList.add('active');
});

prizesBtn.addEventListener('click', () => {
    welcomeScreen.classList.remove('active');
    updatePrizeUI();
    prizesScreen.classList.add('active');
});
backPrizesBtn.addEventListener('click', () => {
    prizesScreen.classList.remove('active');
    welcomeScreen.classList.add('active');
});

soundToggle.addEventListener('change', (e) => {
    soundEnabled = e.target.checked;
});

function updatePrizeUI() {
    prizeCountEl.textContent = `Total Stars: ${totalPrizes}`;
    prizeListEl.innerHTML = '⭐'.repeat(totalPrizes);
}

// 1. Difficulty Level Selection
levelButtons.forEach(button => {
    button.addEventListener('click', () => {
        const level = button.getAttribute('data-level');
        setLevel(level);
        startGame();
    });
});

// 2. Submit Guess
guessBtn.addEventListener('click', processGuess);

// 3. Allow pressing "Enter" key to submit guess for better user experience
guessInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        processGuess();
    }
});

// 4. Restart or Go Back actions
newGameBtn.addEventListener('click', startGame);
changeLevelBtn.addEventListener('click', showLevelScreen);

// --- Game Logic Functions ---

/**
 * Configure the min and max valid bounds based on the selected difficulty
 * @param {string} level - The chosen difficulty ('easy', 'medium', or 'hard')
 */
function setLevel(level) {
    if (level === 'easy') {
        currentMin = 0;
        currentMax = 10;
        maxLives = 3;
    } else if (level === 'medium') {
        currentMin = 1;
        currentMax = 50;
        maxLives = 5;
    } else if (level === 'hard') {
        currentMin = 1;
        currentMax = 100;
        maxLives = 7;
    }
}

/**
 * Initialize or reset a game session with current min/max settings
 */
function startGame() {
    // Generate a random number (inclusive of both min and max bounds)
    secretNumber = Math.floor(Math.random() * (currentMax - currentMin + 1)) + currentMin;

    // Reset state variables
    currentLives = maxLives;
    gameOver = false;
    feedbackText.classList.remove('pulse-win');
    guessInput.classList.remove('shake');

    // Update DOM UI elements
    minValEl.textContent = currentMin;
    maxValEl.textContent = currentMax;
    attemptsCountEl.textContent = currentLives;
    feedbackText.textContent = '';
    feedbackText.className = 'feedback-text'; // Reset feedback classes

    // Reset and enable inputs
    guessInput.value = '';
    guessInput.disabled = false;
    guessBtn.disabled = false;

    // Hide game-over actions menu
    actionsContainer.classList.remove('visible');

    // Switch active screens
    levelScreen.classList.remove('active');
    gameScreen.classList.add('active');

    // Automatically focus the input box after transitioning
    setTimeout(() => guessInput.focus(), 100);
}

/**
 * Main game loop to process the player's inputted guess
 */
function processGuess() {
    if (gameOver) return; // Ignore if the game has ended

    const guessValue = guessInput.value.trim();

    // Validation 1: Input must not be completely empty
    if (guessValue === '') {
        showFeedback('Please enter a number.', 'error');
        return;
    }

    const guess = Number(guessValue);

    // Validation 2: Ensure the input converts to a valid number
    if (isNaN(guess)) {
        showFeedback('Invalid input. Only numbers are allowed.', 'error');
        return;
    }

    // Validation 3: Value must reside strictly within the difficulty level's range
    if (guess < currentMin || guess > currentMax) {
        showFeedback(`Please guess between ${currentMin} and ${currentMax}.`, 'error');
        return;
    }

    // Determine the result
    if (guess === secretNumber) {
        totalPrizes++;
        localStorage.setItem('guessPrizes', totalPrizes);
        playSound('win');
        showFeedback('You Win! ⭐', 'success');
        feedbackText.classList.add('pulse-win');
        
        // Firecrackers! (Confetti)
        if (typeof confetti === 'function') {
            confetti({
                particleCount: 150,
                spread: 100,
                origin: { y: 0.6 },
                colors: ['#14b8a6', '#f59e0b', '#ef4444', '#10B981']
            });
        }
        
        endGame();
    } else {
        guessInput.classList.remove('shake');
        void guessInput.offsetWidth; // trigger reflow
        guessInput.classList.add('shake');
        
        currentLives--;
        attemptsCountEl.textContent = currentLives;
        
        if (currentLives === 0) {
            showFeedback(`Game Over! It was ${secretNumber}.`, 'error');
            endGame();
        } else {
            let direction = guess > secretNumber ? "Too High" : "Too Low";
            let diff = Math.abs(secretNumber - guess);
            let hint = "";
            let hintColor = "";
            
            if (diff <= 2) {
                hint = "Boiling Hot! 🌋";
                hintColor = "#dc2626"; // red
            } else if (diff <= 6) {
                hint = "Hot! 🔥";
                hintColor = "#ea580c"; // dark orange
            } else if (diff <= 15) {
                hint = "Warm ☀️";
                hintColor = "#eab308"; // yellow
            } else if (diff <= 30) {
                hint = "Cool 🧊";
                hintColor = "#3b82f6"; // blue
            } else {
                hint = "Freezing Cold ❄️";
                hintColor = "#1e3a8a"; // dark blue
            }
            
            showFeedback(`${hint} (${direction})`, 'custom', hintColor);
        }
    }

    // Prepare for the next guess
    guessInput.value = '';
    if (!gameOver) {
        guessInput.focus();
    }
}

/**
 * Helper to display styled messages
 * @param {string} message - Text to show
 * @param {string} type - Class identifier ('error', 'warning', or 'success')
 * @param {string} customColor - Optional hex color
 */
function showFeedback(message, type, customColor = null) {
    feedbackText.textContent = message;
    feedbackText.className = `feedback-text ${type}`;
    if (customColor) {
        feedbackText.style.color = customColor;
    } else {
        feedbackText.style.color = '';
    }
}

/**
 * Process end-of-game tasks when user wins
 */
function endGame() {
    gameOver = true;

    // Lock the input
    guessInput.disabled = true;
    guessBtn.disabled = true;

    // Show additional menu options
    actionsContainer.classList.add('visible');
}

/**
 * Transition back to the initial screen
 */
function showLevelScreen() {
    gameScreen.classList.remove('active');
    levelScreen.classList.add('active');
}

// --- Splash Screen Timer ---
setTimeout(() => {
    const splashScreen = document.getElementById('splash-screen');
    if (splashScreen) {
        splashScreen.classList.remove('active');
        welcomeScreen.classList.add('active');
    }
}, 2500);
