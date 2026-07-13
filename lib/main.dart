import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';

void main() {
  runApp(const GuessNumberApp());
}

class GuessNumberApp extends StatelessWidget {
  const GuessNumberApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Number Guessing Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: Colors.tealAccent,
          surface: const Color(0xFF1e293b),
        ),
        useMaterial3: true,
      ),
      home: const MainGameScreen(),
    );
  }
}

class MainGameScreen extends StatefulWidget {
  const MainGameScreen({super.key});

  @override
  State<MainGameScreen> createState() => _MainGameScreenState();
}

enum GameState { splash, welcome, levelSelection, playing, settings, prizes }
enum Difficulty { easy, medium, hard }

class _MainGameScreenState extends State<MainGameScreen> with TickerProviderStateMixin {
  GameState _gameState = GameState.splash;
  Difficulty? _selectedDifficulty;
  late int _minRange;
  late int _maxRange;
  late int _secretNumber;
  int _maxLives = 3;
  int _currentLives = 3;
  bool _gameOver = false;
  
  bool _soundEnabled = true;
  int _totalPrizes = 0;
  
  final TextEditingController _guessController = TextEditingController();
  String _feedbackMessage = '';
  Color _feedbackColor = Colors.transparent;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  late AnimationController _winController;
  late Animation<double> _winAnimation;
  
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    // Shake Animation Setup
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: -10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10, end: 10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    // Win Pulsing Setup
    _winController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _winAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _winController, curve: Curves.easeInOut));
    
    // Confetti Setup
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));

    // Splash Screen Timer
    _winController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _winController.stop();
        setState(() {
          _gameState = GameState.welcome;
        });
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _winController.dispose();
    _confettiController.dispose();
    _guessController.dispose();
    super.dispose();
  }

  // --- Sound Logic ---
  void _playSound(bool isWin) {
    if (!_soundEnabled) return;
    if (isWin) {
      HapticFeedback.heavyImpact();
    } else {
      SystemSound.play(SystemSoundType.click);
    }
  }

  // --- Game Logic Functions ---

  void _startGame(Difficulty difficulty) {
    setState(() {
      _gameState = GameState.playing;
      _selectedDifficulty = difficulty;
      
      // 1. Configure bounds based on difficulty
      switch (difficulty) {
        case Difficulty.easy:
          _minRange = 0;
          _maxRange = 10;
          _maxLives = 3;
          break;
        case Difficulty.medium:
          _minRange = 1;
          _maxRange = 50;
          _maxLives = 5;
          break;
        case Difficulty.hard:
          _minRange = 1;
          _maxRange = 100;
          _maxLives = 7;
          break;
      }
      
      // 2. Generate random number
      _secretNumber = Random().nextInt(_maxRange - _minRange + 1) + _minRange;
      
      // 3. Reset game states
      _currentLives = _maxLives;
      _gameOver = false;
      _feedbackMessage = '';
      _feedbackColor = Colors.transparent;
      _guessController.clear();
      _winController.stop();
      _confettiController.stop();
    });
  }

  void _changeLevel() {
    setState(() {
      _gameState = GameState.levelSelection;
      _selectedDifficulty = null;
    });
  }

  void _submitGuess() {
    if (_gameOver) return;

    final String input = _guessController.text.trim();
    
    // Validation 1: Check if empty
    if (input.isEmpty) {
      _playSound(false);
      _shakeController.forward(from: 0.0);
      setState(() {
        _feedbackMessage = 'Please enter a number.';
        _feedbackColor = Colors.redAccent;
      });
      return;
    }

    final int? guess = int.tryParse(input);
    
    // Validation 2: Check if valid integer
    if (guess == null) {
      _playSound(false);
      _shakeController.forward(from: 0.0);
      setState(() {
        _feedbackMessage = 'Invalid input. Only numbers.';
        _feedbackColor = Colors.redAccent;
      });
      return;
    }

    // Validation 3: Check range bounds
    if (guess < _minRange || guess > _maxRange) {
      _playSound(false);
      _shakeController.forward(from: 0.0);
      setState(() {
        _feedbackMessage = 'Guess between $_minRange and $_maxRange.';
        _feedbackColor = Colors.orangeAccent;
      });
      return;
    }

    // Process valid guess
    setState(() {
      if (guess == _secretNumber) {
        _playSound(true);
        _totalPrizes++;
        _feedbackMessage = 'You Win! ⭐';
        _feedbackColor = Colors.greenAccent;
        _gameOver = true;
        _winController.repeat(reverse: true);
        _confettiController.play();
      } else {
        _playSound(false);
        _shakeController.forward(from: 0.0);
        _currentLives--;
        
        if (_currentLives == 0) {
          _feedbackMessage = 'Game Over! It was $_secretNumber.';
          _feedbackColor = Colors.redAccent;
          _gameOver = true;
        } else {
          final int diff = (_secretNumber - guess).abs();
          final String direction = guess > _secretNumber ? 'Too High' : 'Too Low';
          String hint;
          
          if (diff <= 2) {
            hint = 'Boiling Hot! 🌋';
            _feedbackColor = Colors.redAccent;
          } else if (diff <= 6) {
            hint = 'Hot! 🔥';
            _feedbackColor = Colors.orangeAccent;
          } else if (diff <= 15) {
            hint = 'Warm ☀️';
            _feedbackColor = Colors.yellowAccent;
          } else if (diff <= 30) {
            hint = 'Cool 🧊';
            _feedbackColor = Colors.lightBlueAccent;
          } else {
            hint = 'Freezing Cold ❄️';
            _feedbackColor = Colors.indigoAccent;
          }
          
          _feedbackMessage = '$hint ($direction)';
        }
      }
      
      _guessController.clear();
    });
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            // Modern dark mode gradient background
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0f172a), Color(0xFF000000)],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    // Smooth fade and scale transition
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: _gameState == GameState.splash
                      ? _buildSplashScreen()
                      : _gameState == GameState.welcome 
                          ? _buildWelcomeScreen() 
                          : _gameState == GameState.levelSelection 
                          ? _buildLevelSelection() 
                          : _gameState == GameState.settings
                              ? _buildSettingsScreen()
                              : _gameState == GameState.prizes
                                  ? _buildPrizeScreen()
                                  : _buildGameScreen(),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.directional,
              blastDirection: pi / 2, // downwards
              maxBlastForce: 20,
              minBlastForce: 5,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.2,
              colors: const [Colors.tealAccent, Colors.yellowAccent, Colors.greenAccent, Colors.pinkAccent],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplashScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _winAnimation, // Re-use the pulse animation!
            builder: (context, child) {
              return Transform.scale(
                scale: _winAnimation.value,
                child: child,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: Image.asset(
                'assets/logo.png',
                width: 180,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Number Guessy',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 12),
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        key: const ValueKey('welcome_screen'),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: const Color(0xFF1e293b),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.asset(
                  'assets/logo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Number Guessing Game',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Ready to test your luck?',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.tealAccent.shade400,
                    foregroundColor: Colors.black87,
                  ),
                  onPressed: () {
                    _playSound(false);
                    setState(() {
                      _gameState = GameState.levelSelection;
                    });
                  },
                  child: const Text('Play', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Settings'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF475569)),
                    ),
                    onPressed: () {
                      _playSound(false);
                      setState(() => _gameState = GameState.settings);
                    },
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.star, size: 18),
                    label: const Text('Prizes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF475569)),
                    ),
                    onPressed: () {
                      _playSound(false);
                      setState(() => _gameState = GameState.prizes);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        key: const ValueKey('settings_screen'),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: const Color(0xFF1e293b),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: SwitchListTile(
                  title: const Text('Sound Effects', style: TextStyle(color: Colors.white)),
                  activeColor: Colors.tealAccent,
                  value: _soundEnabled,
                  onChanged: (val) {
                    setState(() => _soundEnabled = val);
                    if (val) _playSound(false);
                  },
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  _playSound(false);
                  setState(() => _gameState = GameState.welcome);
                },
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrizeScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        key: const ValueKey('prize_screen'),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: const Color(0xFF1e293b),
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('My Prizes', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              Text('Total Stars: $_totalPrizes', style: const TextStyle(fontSize: 18, color: Colors.white)),
              const SizedBox(height: 24),
              if (_totalPrizes > 0)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_totalPrizes, (index) => const Text('⭐', style: TextStyle(fontSize: 32))),
                )
              else
                const Text('Win games to collect stars!', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  _playSound(false);
                  setState(() => _gameState = GameState.welcome);
                },
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelSelection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        key: const ValueKey('level_selection'),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: const Color(0xFF1e293b),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Number Guessing Game',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select your difficulty level:',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              _buildLevelButton('Easy (0 - 10)', Difficulty.easy),
              const SizedBox(height: 12),
              _buildLevelButton('Medium (1 - 50)', Difficulty.medium),
              const SizedBox(height: 12),
              _buildLevelButton('Hard (1 - 100)', Difficulty.hard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelButton(String title, Difficulty difficulty) {
    return SizedBox(
      width: 240,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: const Color(0xFF334155),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        onPressed: () {
          _playSound(false);
          _startGame(difficulty);
        },
        child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildGameScreen() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        key: const ValueKey('game_screen'),
        elevation: 12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: const Color(0xFF1e293b),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Guess the Number',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Guess a number between $_minRange and $_maxRange',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.tealAccent.shade400),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _shakeAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: child,
                          );
                        },
                        child: TextField(
                          controller: _guessController,
                          enabled: !_gameOver,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: InputDecoration(
                            hintText: 'Enter guess',
                            hintStyle: const TextStyle(color: Colors.white38),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF475569)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF475569)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.tealAccent.shade400, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            filled: true,
                            fillColor: const Color(0xFF0f172a),
                          ),
                          onSubmitted: (_) => _submitGuess(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 19),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.tealAccent.shade400,
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: _gameOver ? null : _submitGuess,
                      child: const Text('Guess', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: AnimatedBuilder(
                    key: ValueKey(_feedbackMessage),
                    animation: _winAnimation,
                    builder: (context, child) {
                      final bool isWin = _gameOver && _feedbackMessage.contains('Win');
                      return Transform.scale(
                        scale: isWin ? _winAnimation.value : 1.0,
                        child: child,
                      );
                    },
                    child: Text(
                      _feedbackMessage,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _feedbackColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lives left: $_currentLives',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
                if (_gameOver) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: Colors.greenAccent.shade400,
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: () {
                        _playSound(false);
                        _startGame(_selectedDifficulty!);
                      },
                      child: const Text('New Game', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF475569)),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        _playSound(false);
                        _changeLevel();
                      },
                      child: const Text('Change Level', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
