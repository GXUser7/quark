import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SourceBar — compact horizontal action bar that replaces the GnomeTile row.
//
// Usage in main.dart — swap out the entire Row(...GnomeTile...) with:
//
//   SourceBar(
//     items: [
//       if (lastPlaylist != null)
//         SourceBarItem(
//           label: 'Restore',
//           icon: Icons.restore_rounded,
//           onTap: playlistRestore,
//         ),
//       SourceBarItem(label: 'Folder', icon: Icons.folder_open_rounded, onTap: pickFolder),
//       SourceBarItem(label: 'Yandex', iconAsset: 'assets/ym_w_alt.png',  onTap: ymUpdate),
//       SourceBarItem(label: 'YouTube', iconAsset: 'assets/y_w_alt.png',  onTap: () => setState(() => dragAndDropView = true)),
//       SourceBarItem(label: 'VK',     iconAsset: 'assets/vk_w_alt.png', onTap: ...),
//       SourceBarItem(label: 'Cloud',  iconAsset: 'assets/soundcloud_w.png', onTap: () => setState(() => soundCloudView = true)),
//       SourceBarItem(label: 'Search', icon: Icons.search_rounded, onTap: ...),
//       SourceBarItem(label: 'Delete', icon: Icons.delete_outline_rounded, onTap: ..., isDanger: true),
//     ],
//   ),
// ─────────────────────────────────────────────────────────────────────────────

class SourceBarItem {
  final String label;

  /// Use [icon] for Material icons or [iconAsset] for Image.asset paths.
  /// Exactly one must be provided.
  final IconData? icon;
  final String? iconAsset;

  final VoidCallback onTap;

  /// Red-tinted styling for destructive actions.
  final bool isDanger;

  const SourceBarItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.iconAsset,
    this.isDanger = false,
  }) : assert(
         icon != null || iconAsset != null,
         'Provide either icon or iconAsset',
       );
}

class SourceBar extends StatelessWidget {
  final List<SourceBarItem> items;

  /// Horizontal padding around the scrollable list.
  final EdgeInsets padding;

  const SourceBar({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ScrollConfiguration(
        behavior: _NoGlowBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padding,
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => _SourceChip(item: items[i]),
        ),
      ),
    );
  }
}

// ─── Single chip ─────────────────────────────────────────────────────────────

class _SourceChip extends StatefulWidget {
  final SourceBarItem item;
  const _SourceChip({required this.item});

  @override
  State<_SourceChip> createState() => _SourceChipState();
}

class _SourceChipState extends State<_SourceChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOut,
  );

  static const _bg = Color(0xFF1E1E22);
  static const _bgHover = Color(0xFF27272C);
  static const _bgPressed = Color(0xFF2E2E34);
  static const _border = Color(0x12FFFFFF);
  static const _borderHover = Color(0x22FFFFFF);
  static const _danger = Color(0xFFF09595);
  static const _dangerBg = Color(0x14F09595);

  bool _hovered = false;
  bool _pressed = false;

  Color get _bgColor {
    if (widget.item.isDanger) {
      return _pressed
          ? _dangerBg.withOpacity(0.22)
          : _hovered
          ? _dangerBg.withOpacity(0.18)
          : _dangerBg;
    }
    return _pressed ? _bgPressed : _hovered ? _bgHover : _bg;
  }

  Color get _borderColor =>
      _hovered || _pressed ? _borderHover : _border;

  Color get _contentColor =>
      widget.item.isDanger ? _danger : Colors.white.withOpacity(0.75);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        _ctrl.forward();
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
        _ctrl.reverse();
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.item.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIcon(),
              const SizedBox(width: 7),
              Text(
                widget.item.label,
                style: TextStyle(
                  color: _contentColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final color = _contentColor;
    if (widget.item.iconAsset != null) {
      return SizedBox(
        width: 17,
        height: 17,
        child: Image.asset(
          widget.item.iconAsset!,
          color: color,
          colorBlendMode: BlendMode.srcIn,
        ),
      );
    }
    return Icon(widget.item.icon, size: 17, color: color);
  }
}

// ─── No-glow scroll behaviour ─────────────────────────────────────────────────

class _NoGlowBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}