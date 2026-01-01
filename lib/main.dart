import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const StickRunGame());
}

class StickRunGame extends StatelessWidget {
  const StickRunGame({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stick Hero',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const StartScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  // Game state
  bool isPlaying = false;
  int score = 0;
  
  // Player properties
  static const double playerX = 100.0; // Fixed X position (playhead)
  static const double playerWidth = 30.0;
  static const double playerHeight = 55.0;
  double playerY = 0.0;
  double groundLevel = 0.0;
  double velocityY = 0.0;
  bool isJumping = false;
  bool isSliding = false;
  double slideTimer = 0.0;
  static const double slideDuration = 0.1; // seconds (reduced minimum slide time)
  bool isPressing = false; // Track if user is holding press
  bool isDragging = false; // Track if user is dragging down
  double jumpHoldTime = 0.0; // Track how long jump button is held
  
  // Physics constants
  static const double gravity = 3000.0; // pixels per second squared
  static const double minJumpStrength = -200.0; // Very small initial jump (tiny hop for tap)
  static const double maxJumpStrength = -800.0; // Maximum jump strength when holding
  static const double jumpChargeRate = 2500.0; // How fast jump strength builds per second
  static const double maxJumpHeight = 400.0; // Max height character can rise above ground
  
  // World scrolling
  double scrollOffset = 0.0;
  static const double baseScrollSpeed = 225.0; // starting pixels per second
  static const double maxScrollSpeed = 400.0; // maximum pixels per second
  static const double speedIncreaseRate = 5.0; // pixels per second increase per second (reduced from 10.0)
  double currentScrollSpeed = baseScrollSpeed;
  
  // Obstacles
  final List<Obstacle> obstacles = [];
  final Random random = Random();
  double nextObstacleX = 400.0;
  
  // Clouds
  final List<Cloud> clouds = [];
  
  @override
  void initState() {
    super.initState();
    
    // Initialize clouds
    for (int i = 0; i < 5; i++) {
      clouds.add(Cloud(
        x: random.nextDouble() * 800,
        y: random.nextDouble() * 150 + 50,
        size: random.nextDouble() * 30 + 20,
        speed: random.nextDouble() * 20 + 10,
      ));
    }
    
    // Don't initialize obstacles yet - wait for game to start
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60 FPS
    )..repeat();
    
    _animationController.addListener(() {
      setState(() {
        _updateGame();
      });
    });
    
    // Auto-start the game
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startGame();
    });
  }
  
  void _generateObstacles() {
    for (int i = 0; i < 10; i++) {
      final type = ObstacleType.values[random.nextInt(ObstacleType.values.length)];
      obstacles.add(Obstacle(
        x: nextObstacleX,
        type: type,
      ));
      nextObstacleX += 200 + random.nextDouble() * 150; // Reduced spacing (was 300 + 0-200)
    }
  }
  
  void startGame() {
    setState(() {
      isPlaying = true;
      score = 0;
      scrollOffset = 0.0;
      currentScrollSpeed = baseScrollSpeed;
      playerY = groundLevel;
      velocityY = 0.0;
      isJumping = false;
      isSliding = false;
      slideTimer = 0.0;
      isPressing = false;
      isDragging = false;
      jumpHoldTime = 0.0;
      obstacles.clear();
      nextObstacleX = 400.0;
      _generateObstacles();
    });
    _animationController.repeat();
  }
  
  void _handleTapDown(TapDownDetails details) {
    if (!isPlaying) return;
    isPressing = true;
    _jump();
  }
  
  void _handleTapUp(TapUpDetails details) {
    isPressing = false;
  }
  
  void _handleTapCancel() {
    isPressing = false;
  }
  
  void _handleVerticalDragStart(DragStartDetails details) {
    if (!isPlaying) return;
    isDragging = true;
  }
  
  void _handleVerticalDrag(DragUpdateDetails details) {
    if (!isPlaying) return;
    
    // Check if dragging downward (positive delta Y)
    final bool onGround = !isJumping && playerY >= groundLevel - 0.5;
    if (details.delta.dy > 5 && !isSliding && onGround) {
      _slide();
    }
  }
  
  void _handleVerticalDragEnd(DragEndDetails details) {
    isDragging = false;
  }
  
  void _jump() {
    if (!isJumping) {
      isJumping = true;
      velocityY = minJumpStrength; // Start with minimal jump
      jumpHoldTime = 0.0;
      // Cancel sliding if currently sliding
      if (isSliding) {
        isSliding = false;
        slideTimer = 0.0;
      }
    }
  }
  
  void _slide() {
    final bool onGround = !isJumping && playerY >= groundLevel - 0.5;
    if (!isSliding && onGround) {
      isSliding = true;
      slideTimer = 0.0;
    }
  }
  
  void _updateGame() {
    if (!isPlaying) return;
    
    final deltaTime = 0.016; // ~16ms
    
    // Gradually increase scroll speed over time
    if (currentScrollSpeed < maxScrollSpeed) {
      currentScrollSpeed += speedIncreaseRate * deltaTime;
      if (currentScrollSpeed > maxScrollSpeed) {
        currentScrollSpeed = maxScrollSpeed;
      }
    }
    
    // Update scroll offset
    scrollOffset += currentScrollSpeed * deltaTime;
    
    // Update slide timer
    if (isSliding) {
      // Only increment timer if not actively dragging
      if (!isDragging) {
        slideTimer += deltaTime;
      }
      
      // If in air while sliding, move down quickly
      if (playerY < groundLevel) {
        playerY += 1500.0 * deltaTime; // Fast fall during slide
        if (playerY > groundLevel) {
          playerY = groundLevel;
        }
      }
      
      // End slide when timer expires and not dragging
      if (slideTimer >= slideDuration && !isDragging) {
        isSliding = false;
        slideTimer = 0.0;
      }
    } else if (isDragging) {
      // Reset slide timer if user starts dragging again
      slideTimer = 0.0;
    }
    
    // Update jump physics
    if (isJumping) {
      // If holding press and still going up, add extra upward force
      if (isPressing && velocityY < 0) {
        jumpHoldTime += deltaTime;
        // Add upward force while holding (charge up the jump)
        final chargeBoost = -jumpChargeRate * deltaTime;
        velocityY = (velocityY + chargeBoost).clamp(maxJumpStrength, 0.0);
      }
      
      // Apply gravity (reduced while holding, full when released)
      final effectiveGravity = isPressing && velocityY < 0 ? gravity * 0.4 : gravity;
      final double jumpCeiling = groundLevel - maxJumpHeight;

      // Apply gravity and movement
      velocityY += effectiveGravity * deltaTime;
      playerY += velocityY * deltaTime;

      // If ceiling reached/overshot, clamp and start falling
      if (playerY < jumpCeiling) {
        playerY = jumpCeiling;
        velocityY = 0.0; // next frame gravity will pull down
      }
      
      // Check if landed on ground
      if (playerY >= groundLevel) {
        playerY = groundLevel;
        velocityY = 0.0;
        isJumping = false;
        jumpHoldTime = 0.0;
      }
    }
    
    // Update clouds (parallax scrolling - slower than world)
    for (var cloud in clouds) {
      cloud.x -= cloud.speed * deltaTime;
      if (cloud.x < -100) {
        cloud.x = 900;
        cloud.y = random.nextDouble() * 150 + 50;
      }
    }
    
    // Remove off-screen obstacles and add new ones
    // Count passed obstacles for score
    final passedObstacles = obstacles.where((obstacle) => 
      obstacle.x - scrollOffset < playerX - 50 && !obstacle.counted
    ).toList();
    
    for (var obstacle in passedObstacles) {
      obstacle.counted = true;
      score++;
    }
    
    obstacles.removeWhere((obstacle) => obstacle.x - scrollOffset < -100);
    
    if (obstacles.isNotEmpty && obstacles.last.x - scrollOffset < 600) {
      final type = ObstacleType.values[random.nextInt(ObstacleType.values.length)];
      obstacles.add(Obstacle(
        x: nextObstacleX,
        type: type,
      ));
      nextObstacleX += 200 + random.nextDouble() * 150; // Reduced spacing for more frequent obstacles
    }
    
    // Check collisions
    _checkCollisions();
  }
  
  void _checkCollisions() {
    // Player hitbox (approximate)
    final playerLeft = playerX - 12;
    final playerRight = playerX + 12;
    final playerTop = playerY - 55; // Head is about 55 pixels above feet
    final playerBottom = playerY + 15; // Feet extend down
    
    for (var obstacle in obstacles) {
      final obstacleScreenX = obstacle.x - scrollOffset;
      bool collision = false;
      
      switch (obstacle.type) {
        case ObstacleType.rock:
          // Rock: ~50 pixels wide, ~30 pixels tall
          final rockLeft = obstacleScreenX;
          final rockRight = obstacleScreenX + 50;
          final rockTop = groundLevel + 25 - 30; // groundLevel is where player stands, add 25 to get ground surface
          final rockBottom = groundLevel + 25;
          
          // Check if player hitbox overlaps with rock hitbox
          if (playerRight > rockLeft && playerLeft < rockRight &&
              playerBottom > rockTop && playerTop < rockBottom) {
            collision = true;
          }
          break;
          
        case ObstacleType.spike:
          // Spikes: 45 pixels wide (3 spikes), 35 pixels tall
          final spikeLeft = obstacleScreenX;
          final spikeRight = obstacleScreenX + 45;
          final spikeTop = groundLevel + 25 - 35;
          final spikeBottom = groundLevel + 25;
          
          // Check if player hitbox overlaps with spike hitbox
          if (playerRight > spikeLeft && playerLeft < spikeRight &&
              playerBottom > spikeTop && playerTop < spikeBottom) {
            collision = true;
          }
          break;
          
        case ObstacleType.gap:
          // Gap: 80 pixels wide
          final gapLeft = obstacleScreenX;
          final gapRight = obstacleScreenX + 80;
          
          // Player falls into gap if they're over it and not high enough
          // Check if player's center is over the gap
          if (playerX > gapLeft && playerX < gapRight) {
            // If player is on or near ground level, they fall in
            if (playerBottom >= groundLevel + 10) {
              collision = true;
            }
          }
          // Also check if player lands in the gap (feet touch the gap area)
          else if (playerRight > gapLeft && playerLeft < gapRight &&
                   playerBottom >= groundLevel + 10) {
            collision = true;
          }
          break;
          
        case ObstacleType.lowObstacle:
          // Hovering box: 60 pixels wide, 30 pixels tall, hovering 70 pixels up
          final boxLeft = obstacleScreenX;
          final boxRight = obstacleScreenX + 60;
          final boxTop = groundLevel + 25 - 100; // 70 + 30
          final boxBottom = groundLevel + 25 - 70;
          
          // Check if player hitbox overlaps with box hitbox
          if (playerRight > boxLeft && playerLeft < boxRight &&
              playerBottom > boxTop && playerTop < boxBottom) {
            // Only collision if NOT sliding
            if (!isSliding) {
              collision = true;
            }
          }
          break;

        case ObstacleType.slideBarrier:
          // Tall hanging bar from top, leaving only a small slide gap near ground
          final barLeft = obstacleScreenX;
          final barRight = obstacleScreenX + 90;
          final barTop = 0.0;
          final barBottom = groundLevel - 40; // small clearance for slide

          if (playerRight > barLeft && playerLeft < barRight &&
              playerBottom > barTop && playerTop < barBottom) {
            if (!isSliding) {
              collision = true;
            }
          }
          break;
      }
      
      if (collision) {
        _gameOver();
        break;
      }
    }
  }
  
  void _gameOver() {
    setState(() {
      isPlaying = false;
    });
    _animationController.stop();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          color: Colors.lightBlue[50],
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate ground level
              final groundY = constraints.maxHeight - 100;

              // Initialize player position if not jumping
              if (!isJumping && groundLevel == 0.0) {
                groundLevel = groundY - 25;
                playerY = groundLevel;
              } else if (groundLevel != groundY - 25) {
                // Update ground level if screen size changes
                groundLevel = groundY - 25;
                if (!isJumping) {
                  playerY = groundLevel;
                }
              }

              return Stack(
                children: [
                  // Game canvas with tap detection
                  GestureDetector(
                    onTapDown: _handleTapDown,
                    onTapUp: _handleTapUp,
                    onTapCancel: _handleTapCancel,
                    onVerticalDragStart: _handleVerticalDragStart,
                    onVerticalDragUpdate: _handleVerticalDrag,
                    onVerticalDragEnd: _handleVerticalDragEnd,
                    behavior: HitTestBehavior.opaque,
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: GamePainter(
                        playerX: playerX,
                        playerY: playerY,
                        groundY: groundY,
                        animationValue: _animationController.value,
                        scrollOffset: scrollOffset,
                        obstacles: obstacles,
                        clouds: clouds,
                        isSliding: isSliding,
                      ),
                    ),
                  ),

                  // UI overlay - Score
                  if (isPlaying)
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Score: $score',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),

                  // Game Over overlay
                  if (!isPlaying)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Game Over!',
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Score: $score',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (context) => const StartScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text(
                                'Back to Menu',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final double playerX;
  final double playerY;
  final double groundY;
  final double animationValue;
  final double scrollOffset;
  final List<Obstacle> obstacles;
  final List<Cloud> clouds;
  final bool isSliding;
  
  GamePainter({
    required this.playerX,
    required this.playerY,
    required this.groundY,
    required this.animationValue,
    required this.scrollOffset,
    required this.obstacles,
    required this.clouds,
    required this.isSliding,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw sky background
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.lightBlue[200]!, Colors.lightBlue[50]!],
      ).createShader(Rect.fromLTWH(0, 0, size.width, groundY));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, groundY), skyPaint);
    
    // Draw clouds
    _drawClouds(canvas);
    
    // Draw ground
    _drawGround(canvas, size);
    
    // Draw obstacles
    _drawObstacles(canvas);
    
    // Draw stick figure player
    _drawStickFigure(canvas);
  }
  
  void _drawGround(Canvas canvas, Size size) {
    final groundPaint = Paint()
      ..color = Colors.brown[700]!
      ..style = PaintingStyle.fill;
    
    final grassPaint = Paint()
      ..color = Colors.green[700]!
      ..style = PaintingStyle.fill;
    
    // Draw grass
    canvas.drawRect(
      Rect.fromLTWH(0, groundY - 10, size.width, 10),
      grassPaint,
    );
    
    // Draw ground/dirt
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, size.width, size.height - groundY),
      groundPaint,
    );
  }
  
  void _drawStickFigure(Canvas canvas) {
    if (isSliding) {
      _drawSlidingFigure(canvas);
      return;
    }
    
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final bodyPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    // Improved running animation
    final runCycle = animationValue * 2; // 2 cycles per second (slower, smoother)
    final phase = (runCycle % 1.0) * 2 * pi;
    
    // More pronounced leg movement for forward running
    final frontLegAngle = sin(phase) * 0.5; // Reduced angle for smoother motion
    final backLegAngle = sin(phase + pi) * 0.5; // Opposite phase
    
    // Arm swing opposite to legs
    final frontArmAngle = sin(phase + pi) * 0.3;
    final backArmAngle = sin(phase) * 0.3;
    
    // Body lean forward slightly when running
    final bodyLean = 3.0;
    
    // Vertical bob during run (only affects body and limbs, not head)
    final verticalBob = (sin(phase * 2)).abs() * 2;
    
    final baseY = playerY - verticalBob;
    final headY = playerY; // Head stays at constant height
    
    // Head - positioned forward and stable
    canvas.drawCircle(
      Offset(playerX + bodyLean, headY - 40),
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );
    
    // Body - leaning forward, connects to stable head
    canvas.drawLine(
      Offset(playerX + bodyLean, headY - 32),
      Offset(playerX, baseY - 10),
      bodyPaint,
    );
    
    // Back arm (swinging backward)
    final backArmX = playerX - 8;
    final backArmY = baseY - 24;
    final backArmEndX = backArmX - sin(backArmAngle) * 15;
    final backArmEndY = backArmY + cos(backArmAngle) * 15;
    
    canvas.drawLine(
      Offset(backArmX, backArmY),
      Offset(backArmEndX, backArmEndY),
      paint,
    );
    
    // Front arm (swinging forward)
    final frontArmX = playerX + 2;
    final frontArmY = baseY - 24;
    final frontArmEndX = frontArmX - sin(frontArmAngle) * 15;
    final frontArmEndY = frontArmY + cos(frontArmAngle) * 15;
    
    canvas.drawLine(
      Offset(frontArmX, frontArmY),
      Offset(frontArmEndX, frontArmEndY),
      paint,
    );
    
    // Back leg (with knee bend)
    final backLegHipX = playerX;
    final backLegHipY = baseY - 10;
    final backLegKneeX = backLegHipX + sin(backLegAngle) * 12;
    final backLegKneeY = backLegHipY + 12;
    final backLegFootX = backLegKneeX + sin(backLegAngle) * 10;
    final backLegFootY = baseY + 15;
    
    // Thigh
    canvas.drawLine(
      Offset(backLegHipX, backLegHipY),
      Offset(backLegKneeX, backLegKneeY),
      paint,
    );
    
    // Shin
    canvas.drawLine(
      Offset(backLegKneeX, backLegKneeY),
      Offset(backLegFootX, backLegFootY),
      paint,
    );
    
    // Front leg (with knee bend)
    final frontLegHipX = playerX;
    final frontLegHipY = baseY - 10;
    final frontLegKneeX = frontLegHipX + sin(frontLegAngle) * 12;
    final frontLegKneeY = frontLegHipY + 12;
    final frontLegFootX = frontLegKneeX + sin(frontLegAngle) * 10;
    final frontLegFootY = baseY + 15;
    
    // Thigh
    canvas.drawLine(
      Offset(frontLegHipX, frontLegHipY),
      Offset(frontLegKneeX, frontLegKneeY),
      paint,
    );
    
    // Shin
    canvas.drawLine(
      Offset(frontLegKneeX, frontLegKneeY),
      Offset(frontLegFootX, frontLegFootY),
      paint,
    );
  }
  
  void _drawSlidingFigure(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    final bodyPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    
    // Sliding position - character is horizontal
    final slideY = playerY + 10; // Lower position when sliding
    
    // Head
    canvas.drawCircle(
      Offset(playerX - 15, slideY),
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );
    
    // Body - horizontal
    canvas.drawLine(
      Offset(playerX - 7, slideY),
      Offset(playerX + 15, slideY),
      bodyPaint,
    );
    
    // Front arm - extended forward
    canvas.drawLine(
      Offset(playerX + 5, slideY),
      Offset(playerX + 20, slideY - 8),
      paint,
    );
    
    // Back arm - along body
    canvas.drawLine(
      Offset(playerX - 5, slideY),
      Offset(playerX - 10, slideY + 8),
      paint,
    );
    
    // Front leg - extended
    canvas.drawLine(
      Offset(playerX + 10, slideY),
      Offset(playerX + 25, slideY + 5),
      paint,
    );
    
    // Back leg - bent
    canvas.drawLine(
      Offset(playerX, slideY),
      Offset(playerX - 5, slideY + 10),
      paint,
    );
  }
  
  void _drawClouds(Canvas canvas) {
    final cloudPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    for (var cloud in clouds) {
      // Draw cloud with multiple circles
      canvas.drawCircle(Offset(cloud.x, cloud.y), cloud.size * 0.6, cloudPaint);
      canvas.drawCircle(Offset(cloud.x + cloud.size * 0.5, cloud.y), cloud.size * 0.5, cloudPaint);
      canvas.drawCircle(Offset(cloud.x + cloud.size, cloud.y), cloud.size * 0.4, cloudPaint);
      canvas.drawCircle(Offset(cloud.x + cloud.size * 0.3, cloud.y - cloud.size * 0.3), cloud.size * 0.45, cloudPaint);
    }
  }
  
  void _drawObstacles(Canvas canvas) {
    for (var obstacle in obstacles) {
      final screenX = obstacle.x - scrollOffset;
      
      // Only draw if on screen
      if (screenX > -100 && screenX < 900) {
        switch (obstacle.type) {
          case ObstacleType.rock:
            _drawRock(canvas, screenX, groundY);
            break;
          case ObstacleType.spike:
            _drawSpike(canvas, screenX, groundY);
            break;
          case ObstacleType.gap:
            _drawGap(canvas, screenX, groundY);
            break;
          case ObstacleType.lowObstacle:
            _drawLowObstacle(canvas, screenX, groundY);
            break;
          case ObstacleType.slideBarrier:
            _drawSlideBarrier(canvas, screenX, groundY);
            break;
        }
      }
    }
  }
  
  void _drawRock(Canvas canvas, double x, double y) {
    final rockPaint = Paint()
      ..color = Colors.grey[700]!
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..moveTo(x, y)
      ..lineTo(x + 15, y - 25)
      ..lineTo(x + 35, y - 30)
      ..lineTo(x + 50, y - 15)
      ..lineTo(x + 45, y)
      ..close();
    
    canvas.drawPath(path, rockPaint);
    
    // Shadow/outline
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawSlideBarrier(Canvas canvas, double x, double y) {
    // Hanging bar: thin wires from top, small purple bar near bottom to slide under
    final barWidth = 90.0;
    final barHeight = 18.0;
    final barTop = y - 60; // lower bar closer to ground for clearer slide cue
    final rect = Rect.fromLTWH(x, barTop, barWidth, barHeight);

    final barPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.deepPurple[400]!, Colors.deepPurple[700]!],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      barPaint,
    );

    // Outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Hanging wires from the very top to the bar
    final strapPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x + 10, 0), Offset(x + 10, barTop), strapPaint);
    canvas.drawLine(Offset(x + barWidth - 10, 0), Offset(x + barWidth - 10, barTop), strapPaint);
  }
  
  void _drawSpike(Canvas canvas, double x, double y) {
    final spikePaint = Paint()
      ..color = Colors.red[900]!
      ..style = PaintingStyle.fill;
    
    for (int i = 0; i < 3; i++) {
      final path = Path()
        ..moveTo(x + i * 15, y)
        ..lineTo(x + i * 15 + 7.5, y - 35)
        ..lineTo(x + i * 15 + 15, y)
        ..close();
      
      canvas.drawPath(path, spikePaint);
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }
  
  void _drawGap(Canvas canvas, double x, double y) {
    const gapWidth = 80.0;
    const double depth = 100.0;

    // Gap starts just below grass line (at dirt level)
    final double gapTop = y - 10;
    final gapRect = Rect.fromLTWH(x, gapTop, gapWidth, depth);

    // Dark hole with gradient for depth (fully opaque to block grass)
    canvas.drawRect(
      gapRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.brown[900]!,
            Colors.black,
          ],
        ).createShader(gapRect),
    );

    // Edge shadows to show pit depth
    final edgeShadow = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    // Left edge shadow
    canvas.drawRect(
      Rect.fromLTWH(x, gapTop, 8, depth * 0.6),
      edgeShadow,
    );
    
    // Right edge shadow
    canvas.drawRect(
      Rect.fromLTWH(x + gapWidth - 8, gapTop, 8, depth * 0.6),
      edgeShadow,
    );

    // Spikes at the bottom
    final spikePaint = Paint()
      ..color = Colors.red[900]!
      ..style = PaintingStyle.fill;
    final double spikeBaseY = gapTop + depth;
    const double spikeHeight = 20.0;
    const int spikeCount = 5;
    final double spikeSpacing = gapWidth / spikeCount;

    for (int i = 0; i < spikeCount; i++) {
      final double centerX = x + (i + 0.5) * spikeSpacing;
      final double halfBase = spikeSpacing * 0.4;
      
      final Path spike = Path()
        ..moveTo(centerX - halfBase, spikeBaseY)
        ..lineTo(centerX + halfBase, spikeBaseY)
        ..lineTo(centerX, spikeBaseY - spikeHeight)
        ..close();
      
      canvas.drawPath(spike, spikePaint);
      
      // Spike outline
      canvas.drawPath(
        spike,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }
  
  void _drawLowObstacle(Canvas canvas, double x, double y) {
    final obstaclePaint = Paint()
      ..color = Colors.orange[800]!
      ..style = PaintingStyle.fill;
    
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    // Hovering height above ground
    final hoverHeight = 70.0; // Higher in the air
    final obstacleY = y - hoverHeight;
    final obstacleHeight = 30.0;
    final obstacleWidth = 60.0;
    
    // Draw shadow on ground
    final shadowOffset = 5.0;
    canvas.drawOval(
      Rect.fromLTWH(x + shadowOffset, y - 5, obstacleWidth - shadowOffset * 2, 8),
      shadowPaint,
    );
    
    // Draw box/crate hovering in air
    // Main box
    canvas.drawRect(
      Rect.fromLTWH(x, obstacleY, obstacleWidth, obstacleHeight),
      obstaclePaint,
    );
    
    // 3D effect - top face
    final topPath = Path()
      ..moveTo(x, obstacleY)
      ..lineTo(x + 8, obstacleY - 8)
      ..lineTo(x + obstacleWidth + 8, obstacleY - 8)
      ..lineTo(x + obstacleWidth, obstacleY)
      ..close();
    canvas.drawPath(
      topPath,
      Paint()
        ..color = Colors.orange[600]!
        ..style = PaintingStyle.fill,
    );
    
    // 3D effect - right face
    final rightPath = Path()
      ..moveTo(x + obstacleWidth, obstacleY)
      ..lineTo(x + obstacleWidth + 8, obstacleY - 8)
      ..lineTo(x + obstacleWidth + 8, obstacleY + obstacleHeight - 8)
      ..lineTo(x + obstacleWidth, obstacleY + obstacleHeight)
      ..close();
    canvas.drawPath(
      rightPath,
      Paint()
        ..color = Colors.orange[900]!
        ..style = PaintingStyle.fill,
    );
    
    // Draw X pattern on box
    final patternPaint = Paint()
      ..color = Colors.brown[900]!
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(
      Offset(x + 10, obstacleY + 5),
      Offset(x + obstacleWidth - 10, obstacleY + obstacleHeight - 5),
      patternPaint,
    );
    canvas.drawLine(
      Offset(x + obstacleWidth - 10, obstacleY + 5),
      Offset(x + 10, obstacleY + obstacleHeight - 5),
      patternPaint,
    );
    
    // Outline
    canvas.drawRect(
      Rect.fromLTWH(x, obstacleY, obstacleWidth, obstacleHeight),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
  
  @override
  bool shouldRepaint(GamePainter oldDelegate) {
    return true; // Always repaint for smooth scrolling
  }
}

// Obstacle class
enum ObstacleType { rock, spike, gap, lowObstacle, slideBarrier }

class Obstacle {
  final double x;
  final ObstacleType type;
  bool counted; // Track if obstacle has been counted for score
  
  Obstacle({
    required this.x,
    required this.type,
    this.counted = false,
  });
}

// Cloud class
class Cloud {
  double x;
  double y;
  final double size;
  final double speed;
  
  Cloud({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
  });
}

// Start Screen
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.lightBlue[200]!, Colors.lightBlue[50]!],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'STICK HERO',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  shadows: [
                    Shadow(
                      color: Colors.white,
                      offset: Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Icon(
                Icons.directions_run,
                size: 100,
                color: Colors.black87,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const GameScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 20,
                  ),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('START GAME'),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Tap for a short hop, hold to charge a higher jump (capped at the roof).\nSwipe down and hold to slide under low boxes and hanging bars; release to stand.\nAvoid rocks, spikes, gaps, floating blocks, and hanging bars as the speed ramps up.\nPass obstacles to score.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
