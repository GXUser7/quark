import 'package:flutter/material.dart';

class AnimatedGlowBackground extends StatefulWidget {
  final Widget child;

  const AnimatedGlowBackground({super.key, required this.child});

  @override
  State<AnimatedGlowBackground> createState() => _AnimatedGlowBackgroundState();
}

class _AnimatedGlowBackgroundState extends State<AnimatedGlowBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final size = 280 + (_glowController.value * 80);
              final opacity = 0.06 + (_glowController.value * 0.05);
              return Positioned(
                top: -80 + (_glowController.value * 30),
                left: -80 + (_glowController.value * 20),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(opacity),
                        theme.colorScheme.primary.withOpacity(0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final size = 320 - (_glowController.value * 60);
              final opacity = 0.04 + ((1.0 - _glowController.value) * 0.04);
              return Positioned(
                bottom: -100 + (_glowController.value * 40),
                right: -100 + (_glowController.value * 30),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF0077FF).withOpacity(opacity),
                        const Color(0xFF0077FF).withOpacity(0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          SafeArea(child: widget.child),
        ],
      ),
    );
  }
}