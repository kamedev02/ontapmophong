import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ontapmophong/features/simulation/widgets/segment_bar.dart';
import 'package:ontapmophong/features/simulation/widgets/slider_theme_data.dart';

class VideoPlayerPanel extends StatelessWidget {
  final String? currentVideoPath;
  final Player player;
  final VideoController playerController;
  final FocusNode playerFocusNode;
  final bool flagAllowed;
  final Duration? flagPosition;
  final bool showSegment;
  final double? dragValue;
  final List<double> scoreSegments;
  final VoidCallback onFlag;
  final ValueChanged<bool> onPlayStateChanged;
  final ValueChanged<bool> onShowSegmentChanged;
  final ValueChanged<bool> onFlagAllowedChanged;
  final ValueChanged<double?> onDragUpdate;
  final ValueChanged<double> onSeek;
  final ValueChanged<int> onScoreChanged;

  const VideoPlayerPanel({
    super.key,
    this.currentVideoPath,
    required this.player,
    required this.playerController,
    required this.playerFocusNode,
    required this.flagAllowed,
    this.flagPosition,
    required this.showSegment,
    this.dragValue,
    required this.scoreSegments,
    required this.onFlag,
    required this.onPlayStateChanged,
    required this.onShowSegmentChanged,
    required this.onFlagAllowedChanged,
    required this.onDragUpdate,
    required this.onSeek,
    required this.onScoreChanged,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final miliSeconds = twoDigits(duration.inMilliseconds.remainder(999));
    return '$minutes:$seconds.$miliSeconds';
  }

  @override
  Widget build(BuildContext context) {
    if (currentVideoPath == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Text(
            'Chọn một bài học để bắt đầu',
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
        ),
      );
    }

    return Focus(
      autofocus: true,
      focusNode: playerFocusNode,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.space) {
          onFlag();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Video(controller: playerController, controls: null),
                ),
              ),
            ),
            StreamBuilder(
              stream: player.stream.completed,
              builder: (context, completed) {
                if (completed.data ?? false) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onPlayStateChanged(false);
                    if (!showSegment) {
                      onShowSegmentChanged(true);
                    }
                  });
                }
                return const SizedBox(height: 16);
              },
            ),
            StreamBuilder<Duration>(
              stream: player.stream.position,
              builder: (context, snapshot) {
                final duration = player.state.duration;
                final position = snapshot.data ?? Duration.zero;

                final String formattedPosition = _formatDuration(position);
                final String formattedDuration = _formatDuration(duration);

                if (position.inSeconds >= 10 &&
                    flagPosition == null &&
                    !flagAllowed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onFlagAllowedChanged(true);
                  });
                }

                return Column(
                  children: [
                    Text("$formattedPosition/$formattedDuration"),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RectangularSliderThumb(
                          width: 10.0,
                          height: 24.0,
                        ),
                        thumbColor: Colors.blue,
                        activeTrackColor: Colors.grey[300],
                        inactiveTrackColor: Colors.grey[300],
                        padding: EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 0,
                        ),
                        overlayColor: Colors.transparent,
                      ),
                      child: Slider(
                        value:
                            (dragValue ?? (position.inMilliseconds.toDouble()))
                                .clamp(0.0, duration.inMilliseconds.toDouble()),
                        min: 0.0,
                        max: duration.inMilliseconds.toDouble(),
                        onChanged: onDragUpdate,
                        onChangeEnd: onSeek,
                      ),
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
              child: SegmentsBar(
                durationMs: player.state.duration,
                height: 16,
                flagPosition: flagPosition,
                showSegments: showSegment,
                segments: scoreSegments,
                onScoreChanged: (value) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    onScoreChanged(value);
                  });
                },
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Học viên ấn phím space khi phát hiện tình huống nguy hiểm",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
