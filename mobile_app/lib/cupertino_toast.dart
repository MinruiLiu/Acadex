import 'dart:async';

import 'package:flutter/cupertino.dart';

/// Replaces any visible toast when showing a new one.
OverlayEntry? _acadexToastEntry;

enum AcadexToastVariant { success, danger, neutral }

void showAcadexToast(
  BuildContext context,
  String message, {
  AcadexToastVariant variant = AcadexToastVariant.neutral,
}) {
  _acadexToastEntry?.remove();
  _acadexToastEntry = null;
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _AcadexToast(
      overlayEntry: entry,
      message: message,
      variant: variant,
    ),
  );
  _acadexToastEntry = entry;
  overlay.insert(entry);
}

class _AcadexToast extends StatefulWidget {
  const _AcadexToast({
    required this.overlayEntry,
    required this.message,
    required this.variant,
  });

  final OverlayEntry overlayEntry;
  final String message;
  final AcadexToastVariant variant;

  @override
  State<_AcadexToast> createState() => _AcadexToastState();
}

class _AcadexToastState extends State<_AcadexToast> {
  bool _visible = true;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _autoTimer = Timer(const Duration(seconds: 3), _startFadeOut);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _startFadeOut() {
    if (!mounted) return;
    _autoTimer?.cancel();
    _autoTimer = null;
    setState(() => _visible = false);
  }

  void _removeIfCurrent() {
    if (_acadexToastEntry == widget.overlayEntry) {
      widget.overlayEntry.remove();
      _acadexToastEntry = null;
    }
  }

  Color _background() {
    switch (widget.variant) {
      case AcadexToastVariant.success:
        return const Color(0xE6166537);
      case AcadexToastVariant.danger:
        return const Color(0xE6B91C1C);
      case AcadexToastVariant.neutral:
        return const Color(0xE6101630);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      right: 12,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        onEnd: () {
          if (!_visible) {
            _removeIfCurrent();
          }
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _background(),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: _startFadeOut,
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 18,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
