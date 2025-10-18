import 'package:flutter/material.dart';
import 'package:ontapmophong/core/services/file_downloader.dart';

class DownloadIndicator extends StatelessWidget {
  const DownloadIndicator({
    super.key,
    required this.downloadStatus,
    required this.progressInfo,
  });

  final String downloadStatus;
  final DownloadProgressInfo? progressInfo;

  @override
  Widget build(BuildContext context) {
    final progress = (progressInfo?.progress ?? 0.0).clamp(0.0, 1.0);
    final extractionPhaseProgress =
        (progressInfo?.extractionProgress ?? 0.0).clamp(0.0, 1.0);
    final downloadedBytes = progressInfo?.downloadedBytes ?? 0;
    final totalBytes = progressInfo?.totalBytes;
    final remainingBytes = progressInfo?.remainingBytes;
    final isExtracting = progressInfo?.isExtracting ?? false;
    final speed = progressInfo?.speedBytesPerSecond ?? 0.0;

    final hasTotal = totalBytes != null;
    final indicatorValue = progressInfo == null ? null : progress;
    final percentLabel =
        '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%';
    final sizeLabel = hasTotal
        ? '${_formatBytes(downloadedBytes)} / ${_formatBytes(totalBytes)}'
        : '${_formatBytes(downloadedBytes)} / ?';
    final remainingLabel = remainingBytes != null
        ? 'Còn lại: ${_formatBytes(remainingBytes)}'
        : null;
    final speedLabel = isExtracting
        ? 'Đang giải nén dữ liệu... (${(extractionPhaseProgress * 100).clamp(0, 100).toStringAsFixed(0)}%)'
        : 'Tốc độ: ${_formatSpeed(speed)}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 50.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              downloadStatus,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: indicatorValue),
            const SizedBox(height: 8),
            Text(
              percentLabel,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Dung lượng: $sizeLabel',
              textAlign: TextAlign.center,
            ),
            if (remainingLabel != null)
              Text(
                remainingLabel,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Text(
              speedLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }

  static String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) {
      return '0 B/s';
    }
    const units = ['B/s', 'KB/s', 'MB/s', 'GB/s', 'TB/s'];
    var value = bytesPerSecond;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = value >= 10 || unitIndex == 0 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }
}
