import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadProgressInfo {
  final double progress;
  final int downloadedBytes;
  final int? totalBytes;
  final double speedBytesPerSecond;
  final bool isExtracting;
  final double? extractionProgress;

  const DownloadProgressInfo({
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.speedBytesPerSecond,
    this.isExtracting = false,
    this.extractionProgress,
  });

  int? get remainingBytes =>
      totalBytes != null ? totalBytes! - downloadedBytes : null;
}

class DownloadFailure {
  final String message;
  final bool canRetry;

  const DownloadFailure(this.message, {this.canRetry = true});
}

class FileDownloader {
  FileDownloader(this._zipUrl, this._zipFileName, this._extractionDirName);

  final String _zipUrl;
  final String _zipFileName;
  final String _extractionDirName;

  double _downloadProgress = 0.0;
  String _downloadStatus = 'Idle';
  int _downloadedBytes = 0;
  int? _totalBytes;
  double _downloadSpeed = 0.0;
  int _resumeAttempts = 0;

  static const int _maxResumeAttempts = 3;

  bool _isDownloading = false;
  bool _waitingForNetwork = false;
  bool _isDisposed = false;

  DateTime? _lastSpeedSample;
  int _bytesSinceLastSample = 0;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<List<int>>? _downloadSubscription;
  IOSink? _fileSink;
  http.Client? _httpClient;

  String? _zipFilePath;
  String? _extractionPath;

  final _progressStreamController =
      StreamController<DownloadProgressInfo>.broadcast();
  final _statusStreamController = StreamController<String>.broadcast();
  final _failureStreamController =
      StreamController<DownloadFailure>.broadcast();

  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;
  int get downloadedBytes => _downloadedBytes;
  int? get totalBytes => _totalBytes;
  double get downloadSpeed => _downloadSpeed;

  Stream<DownloadProgressInfo> get progressStream =>
      _progressStreamController.stream;
  Stream<String> get statusStream => _statusStreamController.stream;
  Stream<DownloadFailure> get failureStream => _failureStreamController.stream;

  Future<void> downloadAndExtract({bool force = false}) async {
    if (_isDisposed || _isDownloading || _waitingForNetwork) {
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      _zipFilePath = p.join(directory.path, _zipFileName);
      _extractionPath = p.join(directory.path, _extractionDirName);
      final extractionDir = Directory(_extractionPath!);

      if (force && _zipFilePath != null) {
        final zipFile = File(_zipFilePath!);
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
      }

      final extractionExists = await extractionDir.exists();
      if (force && extractionExists) {
        await extractionDir.delete(recursive: true);
      }

      if (!await extractionDir.exists()) {
        await extractionDir.create(recursive: true);
      }

      final isEmpty = await extractionDir.list(followLinks: false).isEmpty;
      if (!isEmpty && !force) {
        _totalBytes = null;
        _downloadedBytes = 0;
        _downloadSpeed = 0;
        _updateStatus('Đã tải và giải nén');
        _emitProgress(forceComplete: true);
        return;
      }

      _resumeAttempts = 0;
      _ensureConnectivityListener();
      await _startDownload(resumeFromExisting: await _hasPartialZip());
    } catch (e) {
      debugPrint('Download start error: $e');
      _emitFailure('Lỗi khởi tạo tải xuống: $e');
    }
  }

  Future<void> restart() async {
    if (_isDisposed) {
      return;
    }
    await _cancelOngoingDownload();

    if (_zipFilePath != null) {
      final zipFile = File(_zipFilePath!);
      if (await zipFile.exists()) {
        await zipFile.delete();
      }
    }

    if (_extractionPath != null) {
      final extractionDir = Directory(_extractionPath!);
      if (await extractionDir.exists()) {
        await extractionDir.delete(recursive: true);
        await extractionDir.create(recursive: true);
      }
    }

    _resetMetrics();
    await downloadAndExtract();
  }

  Future<bool> _hasPartialZip() async {
    if (_zipFilePath == null) {
      return false;
    }
    final zipFile = File(_zipFilePath!);
    if (await zipFile.exists()) {
      final length = await zipFile.length();
      return length > 0;
    }
    return false;
  }

  Future<void> _startDownload({required bool resumeFromExisting}) async {
    if (_zipFilePath == null || _extractionPath == null) {
      return;
    }

    await _cancelOngoingDownload();

    final file = File(_zipFilePath!);
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    var existingLength = resumeFromExisting ? await file.length() : 0;
    if (!resumeFromExisting || existingLength == 0) {
      await file.writeAsBytes([]);
      existingLength = 0;
    }

    _downloadedBytes = existingLength;
    _downloadSpeed = 0;
    _lastSpeedSample = DateTime.now();
    _bytesSinceLastSample = 0;
    final request = http.Request('GET', Uri.parse(_zipUrl));
    if (existingLength > 0) {
      request.headers['Range'] = 'bytes=$existingLength-';
    }

    _httpClient = http.Client();

    http.StreamedResponse response;
    try {
      response = await _httpClient!.send(request);
    } on Exception catch (error) {
      _httpClient?.close();
      _httpClient = null;
      _handleNetworkError(error);
      return;
    }

    if (response.statusCode == 200 && existingLength > 0) {
      await file.writeAsBytes([]);
      existingLength = 0;
      _downloadedBytes = 0;
      final retryRequest = http.Request('GET', Uri.parse(_zipUrl));
      response = await _httpClient!.send(retryRequest);
    }

    if (response.statusCode != 200 && response.statusCode != 206) {
      _httpClient?.close();
      _httpClient = null;
      _emitFailure('Máy chủ phản hồi lỗi: ${response.statusCode}');
      return;
    }

    _totalBytes = response.contentLength != null
        ? ((existingLength > 0 && response.statusCode == 206)
              ? existingLength + response.contentLength!
              : response.contentLength)
        : _totalBytes;

    _fileSink = file.openWrite(
      mode: existingLength > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly,
    );

    _isDownloading = true;
    _waitingForNetwork = false;
    _updateStatus('Đang tải tài nguyên...');
    _emitProgress();

    _downloadSubscription = response.stream.listen(
      (chunk) {
        _fileSink?.add(chunk);
        _handleChunk(chunk.length);
      },
      onDone: _handleDownloadComplete,
      onError: (error, __) => _handleStreamError(error),
      cancelOnError: true,
    );
  }

  void _handleChunk(int bytes) {
    _downloadedBytes += bytes;
    _bytesSinceLastSample += bytes;

    final now = DateTime.now();
    _lastSpeedSample ??= now;

    final elapsed = now.difference(_lastSpeedSample!);
    if (elapsed.inMilliseconds >= 500) {
      _downloadSpeed = elapsed.inMilliseconds == 0
          ? 0
          : _bytesSinceLastSample / (elapsed.inMilliseconds / 1000);
      _bytesSinceLastSample = 0;
      _lastSpeedSample = now;
    }

    _emitProgress();
  }

  Future<void> _handleDownloadComplete() async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;

    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    _httpClient?.close();
    _httpClient = null;

    _isDownloading = false;
    _downloadSpeed = 0;
    _waitingForNetwork = false;
    _resumeAttempts = 0;

    if (_totalBytes != null) {
      _downloadedBytes = _totalBytes!;
    }

    _updateStatus('Tải xong, đang giải nén...');
    _emitProgress(isExtracting: true, extractionProgress: 0.0);

    if (_zipFilePath == null || _extractionPath == null) {
      return;
    }

    try {
      await _extractZipFile(_zipFilePath!, _extractionPath!);
      // ignore: body_might_complete_normally_catch_error
      await File(_zipFilePath!).delete().catchError((_) {});
      _updateStatus('Hoàn thành!');
      _emitProgress(forceComplete: true);
    } catch (e) {
      debugPrint('Extraction error: $e');
      _emitFailure('Lỗi khi giải nén: $e');
    }
  }

  Future<void> _handleStreamError(Object error) async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;

    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    _httpClient?.close();
    _httpClient = null;

    _isDownloading = false;
    _handleNetworkError(error);
  }

  void _handleNetworkError(Object error) {
    debugPrint('Download error: $error');

    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      _waitingForNetwork = true;
      _downloadSpeed = 0;
      _emitProgress();
      _resumeAttempts += 1;
      _updateStatus('Mất kết nối mạng. Đang chờ kết nối để tiếp tục...');
      if (_resumeAttempts > _maxResumeAttempts) {
        _waitingForNetwork = false;
        _emitFailure('Không thể tiếp tục tải sau nhiều lần thử.');
      }
      return;
    }

    _emitFailure('Lỗi tải xuống: $error');
  }

  void _ensureConnectivityListener() {
    _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (_isDisposed) return;

      // results là List<ConnectivityResult>
      final isOffline = results.contains(ConnectivityResult.none);
      if (isOffline) {
        // đang mất mạng: cứ để cơ chế _handleNetworkError thiết lập _waitingForNetwork
        return;
      }

      if (_waitingForNetwork && !_isDownloading) {
        _updateStatus('Đã kết nối lại, tiếp tục tải...');
        _waitingForNetwork = false;
        _resumeDownload();
      }
    });
  }

  Future<void> _resumeDownload() async {
    if (_isDownloading || _isDisposed) {
      return;
    }
    await _startDownload(resumeFromExisting: await _hasPartialZip());
  }

  Future<void> _extractZipFile(String zipPath, String destinationPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final extractionSegments = p
        .split(_extractionDirName)
        .where((segment) => segment.isNotEmpty)
        .toList();
    final packFolder =
        extractionSegments.isNotEmpty ? extractionSegments.last : null;

    final fileEntries = archive.where((file) => file.isFile).toList();
    final totalFiles = fileEntries.length;
    var extractedFiles = 0;

    for (final file in archive) {
      final sanitizedPath =
          _sanitizeEntryPath(file.name, extractionSegments, packFolder);
      if (sanitizedPath.isEmpty) {
        continue;
      }

      final outputPath = p.join(destinationPath, sanitizedPath);

      if (file.isFile) {
        final data = file.content as List<int>;
        final outFile = File(outputPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
        extractedFiles++;
        final extractionProgress =
            totalFiles == 0 ? 1.0 : extractedFiles / totalFiles;
        _emitProgress(
          isExtracting: true,
          extractionProgress: extractionProgress,
          forceComplete: extractedFiles >= totalFiles,
        );
      } else {
        await Directory(outputPath).create(recursive: true);
      }
    }

    if (totalFiles == 0) {
      _emitProgress(
        isExtracting: true,
        extractionProgress: 1.0,
        forceComplete: true,
      );
    }
  }

  String _sanitizeEntryPath(
    String rawPath,
    List<String> extractionSegments,
    String? packFolder,
  ) {
    var normalized = p.normalize(rawPath);
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }

    var segments = p
        .split(normalized)
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return '';
    }

    final targetSegments = extractionSegments;

    while (
      segments.length >= targetSegments.length &&
      targetSegments.isNotEmpty &&
      _startsWithSegments(segments, targetSegments)
    ) {
      segments = segments.sublist(targetSegments.length);
    }

    if (segments.isNotEmpty && packFolder != null && segments.first == packFolder) {
      segments = segments.sublist(1);
    }

    return segments.isEmpty ? '' : p.joinAll(segments);
  }

  bool _startsWithSegments(List<String> segments, List<String> prefix) {
    if (prefix.isEmpty || prefix.length > segments.length) {
      return false;
    }
    for (var i = 0; i < prefix.length; i++) {
      if (segments[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }

  void _emitProgress({
    bool isExtracting = false,
    bool forceComplete = false,
    double? extractionProgress,
  }) {
    if (_progressStreamController.isClosed) {
      return;
    }

    double progressValue;
    if (forceComplete) {
      progressValue = 1.0;
    } else if (_totalBytes != null && _totalBytes! > 0) {
      final downloadRatio =
          (_downloadedBytes / _totalBytes!).clamp(0.0, 1.0);
      progressValue = isExtracting
          ? 0.5 + ((extractionProgress ?? 0.0).clamp(0.0, 1.0) * 0.5)
          : downloadRatio * 0.5;
    } else if (isExtracting) {
      progressValue = 0.5 + ((extractionProgress ?? 0.0).clamp(0.0, 1.0) * 0.5);
    } else {
      progressValue = _downloadProgress;
    }

    _downloadProgress = progressValue;

    _progressStreamController.add(
      DownloadProgressInfo(
        progress: progressValue,
        downloadedBytes: _downloadedBytes,
        totalBytes: _totalBytes,
        speedBytesPerSecond: (isExtracting || forceComplete)
            ? 0.0
            : _downloadSpeed,
        isExtracting: isExtracting,
        extractionProgress: extractionProgress,
      ),
    );
  }

  void _emitFailure(String message) {
    if (_failureStreamController.isClosed) {
      return;
    }
    _waitingForNetwork = false;
    _isDownloading = false;
    _downloadSpeed = 0.0;
    _updateStatus('Không thể tiếp tục tải: $message');
    _failureStreamController.add(DownloadFailure(message));
  }

  void _updateStatus(String status) {
    _downloadStatus = status;
    if (!_statusStreamController.isClosed) {
      _statusStreamController.add(status);
    }
  }

  void _resetMetrics() {
    _downloadProgress = 0.0;
    _downloadSpeed = 0.0;
    _downloadedBytes = 0;
    _totalBytes = null;
    _resumeAttempts = 0;
    _waitingForNetwork = false;
  }

  Future<void> _cancelOngoingDownload() async {
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;

    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;

    _httpClient?.close();
    _httpClient = null;

    _isDownloading = false;
  }

  void dispose() {
    _isDisposed = true;
    _cancelOngoingDownload();
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _progressStreamController.close();
    _statusStreamController.close();
    _failureStreamController.close();
  }
}
