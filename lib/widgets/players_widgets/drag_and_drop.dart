import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'package:quark/services/yandex_music_singleton.dart';
// pubspec.yaml:
//   desktop_drop: ^0.4.4

class GlassDropZone extends StatefulWidget {
  final void Function(List<XFile>) onFileDropped;
  final void Function() closeView;
  final List<XFile> files;

  const GlassDropZone({
    super.key,
    required this.onFileDropped,
    required this.closeView,
    this.files = const [],
  });

  @override
  State<GlassDropZone> createState() => _GlassDropZoneState();
}

class _GlassDropZoneState extends State<GlassDropZone>
    with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.18, end: 0.32).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          widget.onFileDropped(details.files);
          print("COOKIE ENTRY: ${details.files.first.path}");
        },
        child: SizedBox(
          width: MediaQuery.widthOf(context) - 200,
          height: MediaQuery.heightOf(context) - 300,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: widget.files.isEmpty ? 110 : null,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _isDragging
                        ? Colors.white.withOpacity(_pulseAnim.value)
                        : const Color.fromRGBO(44, 44, 44, 0.45),
                    border: Border.all(
                      color: _isDragging
                          ? Colors.white.withOpacity(0.55)
                          : Colors.white.withOpacity(0.2),
                      width: _isDragging ? 1.5 : 1,
                    ),
                    gradient: _isDragging
                        ? null
                        : LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                  ),
                  child: child,
                ),
              ),
            ),

            child: widget.files.isEmpty
                ? _EmptyState(isDragging: _isDragging)
                : _FilledState(files: widget.files, isDragging: _isDragging),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDragging;
  const _EmptyState({required this.isDragging});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isDragging
                  ? Icons.file_download_rounded
                  : Icons.upload_file_rounded,
              key: ValueKey(isDragging),
              color: Colors.white.withOpacity(isDragging ? 0.9 : 0.4),
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDragging ? 'Release to add' : 'Drop cookie file here',
            style: TextStyle(
              color: Colors.white.withOpacity(isDragging ? 0.9 : 0.5),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isDragging) ...[
            const SizedBox(height: 2),
            Text(
              'To obtain cookies, use the browser extension "Get cookies.txt LOCALLY"',
              style: TextStyle(
                color: Colors.white.withOpacity(0.28),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilledState extends StatelessWidget {
  final List<XFile> files;
  final bool isDragging;
  const _FilledState({required this.files, required this.isDragging});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Icon(
                isDragging
                    ? Icons.file_download_rounded
                    : Icons.folder_open_rounded,
                color: Colors.white.withOpacity(0.45),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                isDragging
                    ? 'Drop to add more'
                    : '${files.length} file${files.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        ...files.asMap().entries.map(
          (e) => _FileRow(file: e.value, isLast: e.key == files.length - 1),
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  final XFile file;
  final bool isLast;
  const _FileRow({required this.file, required this.isLast});

  String get _ext {
    final parts = file.name.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : '—';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        border: Border(
          bottom: isLast
              ? BorderSide.none
              : BorderSide(color: Colors.white.withOpacity(0.07), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _ext,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file.name,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 12,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// List<XFile> _files = [];
//
// GlassDropZone(
//   files: _files,
//   onFilesDropped: (files) => setState(() => _files = [..._files, ...files]),
// )