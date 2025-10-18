import 'package:flutter/material.dart';
import 'package:ontapmophong/core/services/content_manager.dart';

class DownloadQueueFab extends StatelessWidget {
  const DownloadQueueFab({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.downloads,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final List<PackDownloadState> downloads;

  @override
  Widget build(BuildContext context) {
    if (downloads.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = List<PackDownloadState>.from(downloads)
      ..sort(
        (a, b) => _stagePriority(a.stage).compareTo(_stagePriority(b.stage)),
      );

    final icon = expanded ? Icons.close : Icons.download;
    final badgeText = downloads.length.toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (expanded)
          Container(
            constraints: const BoxConstraints(maxWidth: 240),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                  color: Colors.black.withOpacity(0.15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sorted
                  .map((state) => _DownloadQueueRow(state: state))
                  .toList(),
            ),
          ),
        if (expanded) const SizedBox(height: 12),
        FloatingActionButton(
          onPressed: onToggle,
          mini: true,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon),
              Positioned(
                top: -12,
                right: -12,
                child: _DownloadBadge(label: badgeText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _stagePriority(PackDownloadStage stage) {
    switch (stage) {
      case PackDownloadStage.downloading:
      case PackDownloadStage.extracting:
        return 0;
      case PackDownloadStage.queued:
        return 1;
      case PackDownloadStage.idle:
        return 2;
      case PackDownloadStage.failed:
        return 3;
      case PackDownloadStage.completed:
        return 4;
    }
  }
}

class _DownloadQueueRow extends StatelessWidget {
  const _DownloadQueueRow({required this.state});

  final PackDownloadState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = state.progress;

    double? progressValue;
    if (info != null) {
      progressValue = info.progress.clamp(0.0, 1.0);
    } else if (state.stage == PackDownloadStage.extracting) {
      progressValue = 1.0;
    }

    Widget? progressIndicator;
    if (state.stage == PackDownloadStage.downloading ||
        state.stage == PackDownloadStage.extracting) {
      progressIndicator = LinearProgressIndicator(value: progressValue);
    } else if (state.stage == PackDownloadStage.queued ||
        state.stage == PackDownloadStage.idle) {
      progressIndicator = const LinearProgressIndicator();
    }

    String? percentLabel;
    if (state.stage == PackDownloadStage.failed) {
      percentLabel = null;
    } else if (progressValue != null) {
      percentLabel = '${(progressValue * 100).toStringAsFixed(0)}%';
    }

    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final subtitleStyle = theme.textTheme.bodySmall;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(state.pack.title, style: titleStyle)),
              if (state.stage == PackDownloadStage.failed)
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 18,
                ),
              // else if (percentLabel != null)
              //   Text(percentLabel, style: subtitleStyle),
            ],
          ),
          const SizedBox(height: 4),
          Text(state.message, style: subtitleStyle),
          if (progressIndicator != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(height: 6, child: progressIndicator),
            ),
          ],
        ],
      ),
    );
  }
}

class _DownloadBadge extends StatelessWidget {
  const _DownloadBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onError,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
