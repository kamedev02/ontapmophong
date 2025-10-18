import 'package:flutter/material.dart';
import 'package:ontapmophong/features/simulation/widgets/custom_flag.dart';

class SegmentsBar extends StatefulWidget {
  final Duration durationMs;
  final List<double> segments;
  final Duration? flagPosition;
  final bool showSegments;
  final double height;
  final ValueChanged<int>? onScoreChanged;

  const SegmentsBar({
    super.key,
    required this.durationMs,
    required this.segments,
    this.flagPosition,
    this.showSegments = false,
    this.height = 8,
    this.onScoreChanged,
  });

  @override
  State<SegmentsBar> createState() => _SegmentsBarState();
}

class _SegmentsBarState extends State<SegmentsBar> {
  int _currentScore = 0;

  @override
  void didUpdateWidget(covariant SegmentsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _calculateScore();
  }

  void _calculateScore() {
    if (widget.flagPosition == null || widget.segments.length != 2) {
      _updateScore(0);
      return;
    }

    final durationMs = widget.durationMs.inMilliseconds.toDouble();
    final flagMs = widget.flagPosition!.inMilliseconds.toDouble();

    final startMs = (widget.segments[0] * 1000).toDouble().clamp(
      0.0,
      durationMs.toDouble(),
    );
    final endMs = (widget.segments[1] * 1000).toDouble().clamp(
      0.0,
      durationMs.toDouble(),
    );

    if (endMs <= startMs || durationMs <= 0) {
      _updateScore(0);
      return;
    }

    final step = (endMs - startMs) / 5.0;
    int score = 0;

    for (int j = 0; j < 5; j++) {
      final segStart = startMs + j * step;
      final segEnd = (j == 4) ? endMs : startMs + (j + 1) * step;

      if (flagMs >= segStart && flagMs < segEnd) {
        score = 5 - j;
        break;
      }
    }

    _updateScore(score);
  }

  void _updateScore(int newScore) {
    if (_currentScore != newScore) {
      _currentScore = newScore;
      if (widget.onScoreChanged != null) {
        widget.onScoreChanged!(newScore);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const palette = <Color>[
      Colors.green,
      Colors.lime,
      Colors.yellow,
      Colors.orange,
      Colors.redAccent,
    ];

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final durationMs = widget.durationMs.inMilliseconds.toDouble();
          final children = <Widget>[];

          if (widget.showSegments && widget.segments.length == 2) {
            final startMs = (widget.segments[0] * 1000).toDouble().clamp(
              0.0,
              durationMs,
            );
            final endMs = (widget.segments[1] * 1000).toDouble().clamp(
              0.0,
              durationMs,
            );

            if (endMs > startMs && durationMs > 0) {
              final step = (endMs - startMs) / 5.0;

              for (int j = 0; j < 5; j++) {
                final segStart = startMs + j * step;
                final segEnd = (j == 4) ? endMs : startMs + (j + 1) * step;

                final left = (segStart / durationMs) * w;
                final right = (segEnd / durationMs) * w;
                final segWidth = (right - left).clamp(0.0, w);

                children.add(
                  Positioned(
                    left: left,
                    width: segWidth,
                    height: widget.height,
                    child: Container(color: palette[j % palette.length]),
                  ),
                );
              }
            }
          }

          if (widget.flagPosition != null && durationMs > 0) {
            final flagMs = widget.flagPosition!.inMilliseconds.toDouble();
            final x = (flagMs / durationMs).clamp(0.0, 1.0) * w;

            children.add(
              Positioned(
                left: x,
                top: widget.height / 3,
                child: CustomFlag(
                  height: widget.height * 1.75,
                  color: Colors.red,
                ),
              ),
            );
          }

          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: widget.showSegments
                  ? Colors.black.withAlpha(10)
                  : Colors.transparent,
            ),
            child: Stack(clipBehavior: Clip.none, children: children),
          );
        },
      ),
    );
  }
}
