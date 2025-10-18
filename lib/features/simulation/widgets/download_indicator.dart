// widgets/download_indicator.dart
import 'package:flutter/material.dart';

class DownloadIndicator extends StatelessWidget {
  final String downloadStatus;
  final double downloadProgress;

  const DownloadIndicator({
    super.key,
    required this.downloadStatus,
    required this.downloadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(downloadStatus, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: downloadProgress),
            const SizedBox(height: 8),
            Text('${(downloadProgress * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}
