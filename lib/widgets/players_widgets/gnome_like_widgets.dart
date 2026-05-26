import 'dart:math';
import 'package:flutter/material.dart';

class GnomeButton extends StatefulWidget {
  final VoidCallback onTap;
  final String text;
  final Color? color;
  final double? width;
  final double? borderRadius;
  final double? height;
  final bool isLoading;

  const GnomeButton({
    super.key,
    required this.onTap,
    required this.text,
    required this.isLoading,
    this.color,
    this.width,
    this.borderRadius,
    this.height,
  });

  @override
  State<GnomeButton> createState() => _GnomeButtonState();
}

class _GnomeButtonState extends State<GnomeButton>
    with TickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );
  late final AnimationController _press = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );
  late final Animation<double> _hoverAnim = Tween(
    begin: 0.0,
    end: 0.1,
  ).animate(_hover);
  late final Animation<double> _pressAnim = Tween(
    begin: 0.0,
    end: 0.2,
  ).animate(_press);
  late final Listenable _combined = Listenable.merge([_hover, _press]);

  @override
  void dispose() {
    _hover.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.color ?? const Color.fromARGB(185, 88, 88, 88);
    final radius = widget.borderRadius ?? 30.0;

    return InkWell(
      onTap: widget.isLoading ? null : widget.onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      mouseCursor: MouseCursor.uncontrolled,
      borderRadius: BorderRadius.circular(radius),
      onHover: (v) => v ? _hover.forward() : _hover.reverse(),
      onHighlightChanged: (v) => v ? _press.forward() : _press.reverse(),
      child: AnimatedBuilder(
        animation: _combined,
        builder: (_, __) => Container(
          width: widget.width ?? double.infinity,
          height: widget.height ?? 45,
          decoration: BoxDecoration(
            color: Color.lerp(
              base,
              Colors.white,
              max(_hoverAnim.value, _pressAnim.value),
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class GnomeTile extends StatefulWidget {
  final VoidCallback onTap;
  final String label;

  final IconData? icon;
  final Widget? iconWidget;

  final Color? color;
  final double size;
  final bool isLoading;
  final bool showBadge;
  final int badgeCount;

  const GnomeTile({
    super.key,
    required this.onTap,
    required this.label,
    this.icon,
    this.iconWidget,
    this.color,
    this.size = 88,
    this.isLoading = false,
    this.showBadge = false,
    this.badgeCount = 0,
  }) : assert(
         icon != null || iconWidget != null,
         'Provide either icon or iconWidget',
       );

  @override
  State<GnomeTile> createState() => _GnomeTileState();
}

class _GnomeTileState extends State<GnomeTile> with TickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    duration: const Duration(milliseconds: 180),
    vsync: this,
  );

  late final AnimationController _press = AnimationController(
    duration: const Duration(milliseconds: 120),
    vsync: this,
  );

  late final Animation<double> _hoverBright = Tween(
    begin: 0.0,
    end: 0.12,
  ).animate(CurvedAnimation(parent: _hover, curve: Curves.easeOut));

  late final Animation<double> _pressScale = Tween(
    begin: 1.0,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _press, curve: Curves.easeInOut));

  late final Animation<double> _pressOverlay = Tween(
    begin: 0.0,
    end: 0.18,
  ).animate(CurvedAnimation(parent: _press, curve: Curves.easeIn));

  late final Listenable _combined = Listenable.merge([_hover, _press]);

  @override
  void dispose() {
    _hover.dispose();
    _press.dispose();
    super.dispose();
  }

  static const double _borderRadius = 18;
  static const double _iconFraction = 0.62; // icon container vs tile size

  @override
  Widget build(BuildContext context) {
    final tileSize = widget.size;
    final iconBoxSize = tileSize * _iconFraction;
    final base = widget.color ?? const Color(0xFF3D3D3D);

    return InkWell(
      onTap: widget.isLoading ? null : widget.onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      mouseCursor: MouseCursor.uncontrolled,
      borderRadius: BorderRadius.circular(_borderRadius + 4),
      onHover: (v) => v ? _hover.forward() : _hover.reverse(),
      onHighlightChanged: (v) {
        if (v) {
          _press.forward();
        } else {
          _press.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _combined,
        builder: (_, __) {
          final overlayOpacity = max(_hoverBright.value, _pressOverlay.value);

          return Transform.scale(
            scale: _pressScale.value,
            child: SizedBox(
              width: tileSize,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: iconBoxSize,
                        height: iconBoxSize,
                        decoration: BoxDecoration(
                          color: Color.lerp(base, Colors.white, overlayOpacity),
                          borderRadius: BorderRadius.circular(_borderRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                0.35 - _pressOverlay.value * 0.15,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                            BoxShadow(
                              color: Colors.white.withOpacity(0.06),
                              blurRadius: 0,
                              offset: const Offset(0, 1),
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(_borderRadius),
                          child: Stack(
                            children: [
                              // Glass-like top sheen
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: iconBoxSize * 0.45,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.white.withOpacity(0.09),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Icon / custom widget
                              Center(
                                child: widget.isLoading
                                    ? SizedBox(
                                        width: iconBoxSize * 0.38,
                                        height: iconBoxSize * 0.38,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      )
                                    : (widget.iconWidget ??
                                          Icon(
                                            widget.icon,
                                            size: iconBoxSize * 0.48,
                                            color: Colors.white,
                                          )),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (widget.showBadge && widget.badgeCount > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: _Badge(count: widget.badgeCount),
                        ),
                    ],
                  ),

                  const SizedBox(height: 7),

                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(
                        0.88 + _hoverBright.value * 0.12,
                      ),
                      shadows: const [
                        Shadow(
                          color: Colors.black54,
                          blurRadius: 6,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE74C3C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black26, width: 1),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

class GnomeTileGrid extends StatelessWidget {
  final List<GnomeTile> tiles;
  final double tileSize;
  final double spacing;
  final EdgeInsets padding;

  const GnomeTileGrid({
    super.key,
    required this.tiles,
    this.tileSize = 88,
    this.spacing = 24,
    this.padding = const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Wrap(spacing: spacing, runSpacing: spacing + 4, children: tiles),
    );
  }
}

void main() => runApp(const _DemoApp());

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF1E1E2E),
        body: Center(
          child: GnomeTileGrid(
            tiles: [
              GnomeTile(
                icon: Icons.terminal,
                label: 'Terminal',
                color: const Color(0xFF2D2D2D),
                onTap: () {},
              ),
              GnomeTile(
                icon: Icons.folder_open,
                label: 'Files',
                color: const Color(0xFF1B5E97),
                onTap: () {},
                showBadge: true,
                badgeCount: 3,
              ),
              GnomeTile(
                icon: Icons.settings,
                label: 'Settings',
                color: const Color(0xFF4A4A4A),
                onTap: () {},
              ),
              GnomeTile(
                icon: Icons.web,
                label: 'Firefox',
                color: const Color(0xFFE05C2B),
                onTap: () {},
              ),
              GnomeTile(
                icon: Icons.music_note,
                label: 'Music',
                color: const Color(0xFF6B3FA0),
                onTap: () {},
              ),
              GnomeTile(
                icon: Icons.mail_outline,
                label: 'Mail',
                color: const Color(0xFF2E7D32),
                onTap: () {},
                showBadge: true,
                badgeCount: 12,
              ),
              GnomeTile(
                icon: Icons.calendar_month,
                label: 'Calendar',
                color: const Color(0xFFB71C1C),
                onTap: () {},
              ),
              GnomeTile(
                icon: Icons.code,
                label: 'Text Editor',
                color: const Color(0xFF1A237E),
                onTap: () {},
              ),
              GnomeTile(
                icon: Icons.calculate_outlined,
                label: 'Calculator',
                color: const Color(0xFF37474F),
                onTap: () {},
              ),
              GnomeTile(
                icon: Icons.image_outlined,
                label: 'Photos',
                color: const Color(0xFF4CAF50),
                onTap: () {},
                isLoading: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GnomeStyleAuthButton extends StatefulWidget {
  final bool isLoggedIn;
  final VoidCallback onTap;

  const GnomeStyleAuthButton({required this.isLoggedIn, required this.onTap});

  @override
  State<GnomeStyleAuthButton> createState() => _GnomeStyleAuthButtonState();
}

class _GnomeStyleAuthButtonState extends State<GnomeStyleAuthButton>
    with TickerProviderStateMixin {
  late final AnimationController _hover = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );
  late final AnimationController _press = AnimationController(
    duration: const Duration(milliseconds: 200),
    vsync: this,
  );

  @override
  void dispose() {
    _hover.dispose();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // final baseColor = const Color.fromARGB(
    //   185,
    //   88,
    //   88,
    //   88,
    // );

    final baseColor = const Color.from(alpha: 0, red: 0, green: 0, blue: 0);
    final radius = 30.0;

    return InkWell(
      onTap: widget.onTap,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      onHover: (v) => v ? _hover.forward() : _hover.reverse(),
      onHighlightChanged: (v) => v ? _press.forward() : _press.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_hover, _press]),
        builder: (_, __) {
          final brightness = max(_hover.value, _press.value) * 0.5;
          final currentColor = Color.lerp(baseColor, Colors.white, brightness);

          return Container(
            decoration: BoxDecoration(
              color: currentColor,
              borderRadius: BorderRadius.circular(radius),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.isLoggedIn ? Icons.logout : Icons.person,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isLoggedIn ? 'Logout' : 'Login',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'noto',
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
