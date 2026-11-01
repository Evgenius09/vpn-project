import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

class ModePage {
  const ModePage({required this.title, required this.child});

  final String title;
  final Widget child;
}

class _AllPointersScrollBehavior extends MaterialScrollBehavior {
  const _AllPointersScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// Horizontal pager of mode screens. Swipes, mouse drags, and the arrow keys
/// only report a new index. They never touch the tunnel (tech.md 2.1).
class ModePager extends StatefulWidget {
  const ModePager({
    required this.pages,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final List<ModePage> pages;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  State<ModePager> createState() => _ModePagerState();
}

class _ModePagerState extends State<ModePager> {
  late final PageController _controller = PageController(
    initialPage: widget.index,
  );

  @override
  void didUpdateWidget(ModePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _controller.hasClients ? _controller.page?.round() : null;
    if (widget.index != oldWidget.index && page != widget.index) {
      _controller.animateToPage(
        widget.index,
        duration: AppDurations.normal,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => widget.index - 1,
      LogicalKeyboardKey.arrowRight => widget.index + 1,
      _ => null,
    };
    if (next == null) {
      return KeyEventResult.ignored;
    }
    if (next >= 0 && next < widget.pages.length) {
      widget.onChanged(next);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: ScrollConfiguration(
        behavior: const _AllPointersScrollBehavior(),
        child: PageView(
          controller: _controller,
          onPageChanged: (page) {
            if (page != widget.index) {
              widget.onChanged(page);
            }
          },
          children: [for (final page in widget.pages) page.child],
        ),
      ),
    );
  }
}
