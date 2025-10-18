import 'package:flutter/material.dart';
import 'package:ontapmophong/core/constants/app_strings.dart';
import 'package:ontapmophong/models/chapter.dart';
import 'package:ontapmophong/models/situation.dart';

class LeftPanel extends StatelessWidget {
  final String selectedOption;
  final List<Chapter> chapters;
  final String? selectedSituationId;
  final bool isPlay;
  final ValueChanged<String?> onModeChanged;
  final Function(Chapter chapter, Situation situation) onSituationSelected;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onRefresh;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onCapture;

  const LeftPanel({
    super.key,
    required this.selectedOption,
    required this.chapters,
    this.selectedSituationId,
    required this.isPlay,
    required this.onModeChanged,
    required this.onSituationSelected,
    required this.onPlay,
    required this.onPause,
    required this.onRefresh,
    required this.onPrev,
    required this.onNext,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<String>(
            isExpanded: true,
            autofocus: false,
            hint: const Text('Chọn một'),
            value: selectedOption,
            items: <String>['Ôn tập', 'Thi thử'].map<DropdownMenuItem<String>>((
              String value,
            ) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: onModeChanged,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AbsorbPointer(
              absorbing: selectedOption == 'Thi thử',
              child: Opacity(
                opacity: selectedOption == 'Thi thử' ? 0.5 : 1.0,
                child: ListView.builder(
                  itemCount: chapters.length,
                  itemBuilder: (context, chapterIndex) {
                    final chapter = chapters[chapterIndex];
                    return ExpansionTile(
                      title: Text(chapter.title.split(":").first),
                      children: chapter.situations.map((situation) {
                        return RadioListTile<String>(
                          title: Text(situation.title.split(":").first),
                          value: situation.id,
                          groupValue: selectedSituationId,
                          onChanged: (_) =>
                              onSituationSelected(chapter, situation),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
          const Divider(),
          _buildMediaControls(),
        ],
      ),
    );
  }

  Widget _buildMediaControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: isPlay ? null : onPlay,
              style: controlButtonStyle(),
              child: const Icon(Icons.play_arrow, color: Colors.white),
            ),
            ElevatedButton(
              onPressed: !isPlay ? null : onPause,
              style: controlButtonStyle(),
              child: const Icon(Icons.pause, color: Colors.white),
            ),
            ElevatedButton(
              onPressed: onRefresh,
              style: controlButtonStyle(),
              child: const Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: onPrev,
              style: controlButtonStyle(),
              child: const Icon(Icons.skip_previous, color: Colors.white),
            ),
            // const SizedBox(width: 16),
            ElevatedButton(
              onPressed: onNext,
              style: controlButtonStyle(),
              child: const Icon(Icons.skip_next, color: Colors.white),
            ),
            // const SizedBox(width: 16),
            ElevatedButton(
              onPressed: onCapture,
              style: controlButtonStyle(),
              child: const Icon(
                Icons.screenshot_monitor_rounded,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
