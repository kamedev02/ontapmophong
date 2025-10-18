import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'file_downloader.dart';

class ContentInitializationException implements Exception {
  ContentInitializationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContentManifest {
  ContentManifest({
    required this.version,
    required this.updatedAt,
    required this.basePath,
    required this.dataJson,
    required this.packs,
  });

  factory ContentManifest.fromJson(Map<String, dynamic> json) {
    final updatedAtRaw = json['updatedAt'] as String?;
    return ContentManifest(
      version: json['version'] as String? ?? 'unknown',
      updatedAt: updatedAtRaw != null ? DateTime.tryParse(updatedAtRaw) : null,
      basePath: json['basePath'] as String? ?? 'videos',
      dataJson: json['dataJson'] as String? ?? 'data.json',
      packs: ((json['packs'] as List<dynamic>?) ?? [])
          .map((entry) => ContentPack.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }

  final String version;
  final DateTime? updatedAt;
  final String basePath;
  final String dataJson;
  final List<ContentPack> packs;
}

class ContentPack {
  ContentPack({
    required this.id,
    required this.title,
    required this.situationCount,
    required this.url,
    required this.size,
    required this.sha256,
  });

  factory ContentPack.fromJson(Map<String, dynamic> json) {
    return ContentPack(
      id: json['id'] as String,
      title: json['title'] as String? ?? json['id'] as String,
      situationCount: json['situationCount'] as int? ?? 0,
      url: json['url'] as String,
      size: json['size'] as int? ?? 0,
      sha256: json['sha256'] as String? ?? '',
    );
  }

  final String id;
  final String title;
  final int situationCount;
  final String url;
  final int size;
  final String sha256;
}

enum PackDownloadStage {
  idle,
  queued,
  downloading,
  extracting,
  completed,
  failed,
}

class PackDownloadState {
  const PackDownloadState({
    required this.pack,
    required this.stage,
    required this.message,
    this.progress,
  });

  final ContentPack pack;
  final PackDownloadStage stage;
  final String message;
  final DownloadProgressInfo? progress;

  PackDownloadState copyWith({
    PackDownloadStage? stage,
    String? message,
    DownloadProgressInfo? progress,
    bool resetProgress = false,
  }) {
    return PackDownloadState(
      pack: pack,
      stage: stage ?? this.stage,
      message: message ?? this.message,
      progress: resetProgress ? null : (progress ?? this.progress),
    );
  }
}

class InitialDownloadState {
  const InitialDownloadState({
    required this.message,
    this.progress,
    this.isComplete = false,
  });

  final String message;
  final DownloadProgressInfo? progress;
  final bool isComplete;
}

class _QueuedDownload {
  _QueuedDownload({
    required this.pack,
    this.force = false,
    this.isInitial = false,
  });

  final ContentPack pack;
  bool force;
  final bool isInitial;
  final Completer<bool> completer = Completer<bool>();
  FileDownloader? downloader;
}

class ContentManager {
  ContentManager({required this.manifestUrl, required this.manifestAssetPath});

  final String manifestUrl;
  final String manifestAssetPath;

  final _initialController = StreamController<InitialDownloadState>.broadcast();
  final _packStateController =
      StreamController<Map<String, PackDownloadState>>.broadcast();

  final List<_QueuedDownload> _downloadQueue = <_QueuedDownload>[];

  final Map<String, PackDownloadState> _packStates =
      <String, PackDownloadState>{};

  Directory? _baseDir;
  ContentManifest? _manifest;
  _QueuedDownload? _activeDownload;
  bool _disposed = false;

  Stream<InitialDownloadState> get initialDownloadStream =>
      _initialController.stream;
  Stream<Map<String, PackDownloadState>> get packStatesStream =>
      _packStateController.stream;

  ContentManifest? get manifest => _manifest;

  String get basePath => _manifest?.basePath ?? 'videos';

  Directory? get baseDirectory => _baseDir;

  Future<void> initialize() async {
    if (_disposed) {
      throw StateError('ContentManager has been disposed.');
    }

    _emitInitial('Đang chuẩn bị thư mục dữ liệu...');
    _baseDir = await _prepareBaseDir();

    await _downloadManifestIfNeeded();
    await _loadManifestFromDisk();

    if (_manifest == null) {
      throw ContentInitializationException('Không thể đọc manifest nội dung.');
    }

    await _ensureDataJson();
    await _setupPackStates();

    final ContentPack? initialPack = _selectInitialPack();

    if (initialPack != null) {
      final alreadyReady = await _isPackReady(initialPack.id);
      if (alreadyReady) {
        _updatePackState(
          initialPack.id,
          stage: PackDownloadStage.completed,
          message: 'Đã sẵn sàng',
          resetProgress: true,
        );
        _emitInitial('Chương 1 đã sẵn sàng', isComplete: true);
      } else {
        final success = await _enqueueDownload(
          initialPack,
          priority: true,
          isInitial: true,
        );
        if (!success) {
          throw ContentInitializationException(
            'Không thể tải dữ liệu cho ${initialPack.title}.',
          );
        }
        _emitInitial('Hoàn tất dữ liệu ban đầu', isComplete: true);
      }
    } else {
      _emitInitial(
        'Không có dữ liệu chương nào trong manifest.',
        isComplete: true,
      );
    }

    // enqueue remaining packs
    for (final pack in _manifest!.packs) {
      if (initialPack != null && pack.id == initialPack.id) {
        continue;
      }
      final ready = await _isPackReady(pack.id);
      if (!ready) {
        // fire and forget
        unawaited(_enqueueDownload(pack, priority: false));
      } else {
        _updatePackState(
          pack.id,
          stage: PackDownloadStage.completed,
          message: 'Đã sẵn sàng',
          resetProgress: true,
        );
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _initialController.close();
    _packStateController.close();
    if (_activeDownload?.downloader != null) {
      _activeDownload?.downloader?.dispose();
    }
    for (final task in _downloadQueue) {
      task.downloader?.dispose();
      if (!task.completer.isCompleted) {
        task.completer.completeError(
          StateError('ContentManager đã bị dispose.'),
        );
      }
    }
    _downloadQueue.clear();
  }

  Future<String> loadDataJson() async {
    if (_manifest == null || _baseDir == null) {
      throw StateError('ContentManager chưa được khởi tạo.');
    }
    final filePath = p.join(_baseDir!.path, _manifest!.dataJson);
    final file = File(filePath);
    if (await file.exists()) {
      return file.readAsString(encoding: utf8);
    }
    return rootBundle.loadString('assets/data.json');
  }

  Future<void> ensurePlaylistIntegrity({
    required String chapterId,
    required String situationFolder,
    required String playlistFile,
  }) async {
    if (_manifest == null || _baseDir == null) {
      throw StateError('ContentManager chưa được khởi tạo.');
    }

    final playlistPath = p.join(
      _baseDir!.path,
      chapterId,
      situationFolder,
      playlistFile,
    );

    final playlist = File(playlistPath);
    if (!await playlist.exists()) {
      await _forceRedownloadPack(chapterId);
      return;
    }

    final segmentLines = await playlist.readAsLines();
    final missingSegments = <String>[];
    for (final line in segmentLines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        continue;
      }
      final segmentPath = p.join(playlist.parent.path, trimmed);
      if (!await File(segmentPath).exists()) {
        missingSegments.add(trimmed);
      }
    }

    if (missingSegments.isEmpty) {
      return;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    final bool hasNetwork;
    if (connectivityResult is ConnectivityResult) {
      hasNetwork = connectivityResult != ConnectivityResult.none;
    } else if (connectivityResult is List<ConnectivityResult>) {
      hasNetwork = connectivityResult.any(
        (result) => result != ConnectivityResult.none,
      );
    } else {
      hasNetwork = true;
    }
    if (!hasNetwork) {
      throw ContentInitializationException(
        'Thiếu ${missingSegments.length} đoạn video và không có kết nối Internet.',
      );
    }
    await _forceRedownloadPack(chapterId);
  }

  Set<String> get availablePackIds {
    return _packStates.entries
        .where((entry) => entry.value.stage == PackDownloadStage.completed)
        .map((entry) => entry.key)
        .toSet();
  }

  Future<Directory> _prepareBaseDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final base = Directory(p.join(docs.path, 'videos'));
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return base;
  }

  Future<void> _downloadManifestIfNeeded() async {
    final baseDir = _baseDir ?? await _prepareBaseDir();
    final manifestFile = File(p.join(baseDir.path, 'manifest.json'));

    try {
      final response = await http.get(Uri.parse(manifestUrl));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        await manifestFile.create(recursive: true);
        await manifestFile.writeAsBytes(response.bodyBytes, flush: true);
        return;
      }
      debugPrint(
        'Không thể tải manifest (HTTP ${response.statusCode}), sử dụng bản cũ nếu có.',
      );
    } catch (e) {
      debugPrint('Không thể tải manifest: $e');
    }

    if (!await manifestFile.exists()) {
      final assetManifest = await rootBundle.loadString(manifestAssetPath);
      await manifestFile.create(recursive: true);
      await manifestFile.writeAsString(assetManifest, encoding: utf8);
    }

    _baseDir = baseDir;
  }

  Future<void> _loadManifestFromDisk() async {
    final docs = await getApplicationDocumentsDirectory();
    _baseDir ??= Directory(p.join(docs.path, 'videos'));

    final manifestFile = File(p.join(_baseDir!.path, 'manifest.json'));
    if (!await manifestFile.exists()) {
      return;
    }
    final jsonStr = await manifestFile.readAsString(encoding: utf8);
    final Map<String, dynamic> jsonData = json.decode(jsonStr);
    _manifest = ContentManifest.fromJson(jsonData);

    final manifestBaseDir = Directory(p.join(docs.path, _manifest!.basePath));
    if (!await manifestBaseDir.exists()) {
      await manifestBaseDir.create(recursive: true);
    }
    if (_baseDir?.path != manifestBaseDir.path) {
      _baseDir = manifestBaseDir;
      final targetManifest = File(p.join(_baseDir!.path, 'manifest.json'));
      if (!await targetManifest.exists()) {
        await targetManifest.create(recursive: true);
      }
      if (manifestFile.path != targetManifest.path) {
        await targetManifest.writeAsString(jsonStr, encoding: utf8);
      }
    }
  }

  Future<void> _ensureDataJson() async {
    if (_manifest == null || _baseDir == null) {
      return;
    }

    final dataFile = File(p.join(_baseDir!.path, _manifest!.dataJson));
    final manifestUri = Uri.parse(manifestUrl);
    Uri dataUri;
    if (_manifest!.dataJson.startsWith('http')) {
      dataUri = Uri.parse(_manifest!.dataJson);
    } else {
      dataUri = manifestUri.resolve(_manifest!.dataJson);
    }

    var updated = false;
    try {
      final response = await http.get(dataUri);
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        await dataFile.create(recursive: true);
        await dataFile.writeAsBytes(response.bodyBytes, flush: true);
        updated = true;
      }
    } catch (e) {
      debugPrint('Không thể tải ${_manifest!.dataJson}: $e');
    }

    if (!updated && !await dataFile.exists()) {
      try {
        final bundled = await rootBundle.loadString('assets/data.json');
        await dataFile.create(recursive: true);
        await dataFile.writeAsString(bundled, encoding: utf8);
      } catch (e) {
        debugPrint('Không thể sao chép data.json từ assets: $e');
      }
    }
  }

  Future<void> _setupPackStates() async {
    if (_manifest == null) {
      return;
    }
    _packStates.clear();

    for (final pack in _manifest!.packs) {
      final ready = await _isPackReady(pack.id);
      _packStates[pack.id] = PackDownloadState(
        pack: pack,
        stage: ready ? PackDownloadStage.completed : PackDownloadStage.idle,
        message: ready ? 'Đã sẵn sàng' : 'Chưa tải',
        progress: ready
            ? const DownloadProgressInfo(
                progress: 1.0,
                downloadedBytes: 0,
                totalBytes: null,
                speedBytesPerSecond: 0,
                extractionProgress: 1.0,
              )
            : null,
      );
    }

    _emitPackStates();
  }

  ContentPack? _selectInitialPack() {
    if (_manifest == null) {
      return null;
    }
    final packs = _manifest!.packs;
    if (packs.isEmpty) {
      return null;
    }
    try {
      return packs.firstWhere((pack) => pack.id == 'chapter1');
    } catch (_) {
      return packs.first;
    }
  }

  Future<bool> _isPackReady(String packId) async {
    if (_baseDir == null) {
      return false;
    }
    final packDir = Directory(p.join(_baseDir!.path, packId));
    if (!await packDir.exists()) {
      return false;
    }
    try {
      final hasContent = !await packDir.list(followLinks: false).isEmpty;
      return hasContent;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _enqueueDownload(
    ContentPack pack, {
    bool priority = false,
    bool force = false,
    bool isInitial = false,
  }) {
    if (_disposed) {
      return Future.error(StateError('ContentManager đã dispose.'));
    }

    if (_manifest == null) {
      return Future.error(StateError('Manifest chưa sẵn sàng.'));
    }

    final existingActive = _activeDownload;
    if (existingActive != null && existingActive.pack.id == pack.id) {
      if (force && !existingActive.force) {
        existingActive.force = true;
      }
      return existingActive.completer.future;
    }

    final existingQueuedIndex = _downloadQueue.indexWhere(
      (task) => task.pack.id == pack.id,
    );
    if (existingQueuedIndex >= 0) {
      final existingTask = _downloadQueue[existingQueuedIndex];
      if (force && !existingTask.force) {
        existingTask.force = true;
      }
      return existingTask.completer.future;
    }

    final task = _QueuedDownload(
      pack: pack,
      force: force,
      isInitial: isInitial,
    );

    if (priority) {
      _downloadQueue.insert(0, task);
    } else {
      _downloadQueue.add(task);
    }

    _updatePackState(
      pack.id,
      stage: PackDownloadStage.queued,
      message: 'Trong hàng chờ tải...',
      resetProgress: true,
    );
    _emitInitialIfNeeded(task, 'Trong hàng chờ tải dữ liệu...');

    unawaited(_processQueue());
    return task.completer.future;
  }

  Future<void> _processQueue() async {
    if (_activeDownload != null || _disposed) {
      return;
    }

    while (_downloadQueue.isNotEmpty && !_disposed) {
      final task = _downloadQueue.removeAt(0);
      _activeDownload = task;
      final success = await _runDownloadTask(task);
      _activeDownload = null;
      if (!task.completer.isCompleted) {
        task.completer.complete(success);
      }
    }
  }

  Future<bool> _runDownloadTask(_QueuedDownload task) async {
    final pack = task.pack;

    if (!task.force && await _isPackReady(pack.id)) {
      _updatePackState(
        pack.id,
        stage: PackDownloadStage.completed,
        message: 'Đã sẵn sàng',
        resetProgress: true,
      );
      _emitInitialIfNeeded(task, 'Chương đã sẵn sàng', isComplete: true);
      return true;
    }

    final extractionDirName = p.join(basePath, pack.id);
    final downloader = FileDownloader(
      pack.url,
      '${pack.id}.zip',
      extractionDirName,
    );
    task.downloader = downloader;

    final completer = Completer<bool>();

    StreamSubscription<DownloadProgressInfo>? progressSub;
    StreamSubscription<String>? statusSub;
    StreamSubscription<DownloadFailure>? failureSub;

    void updateProgress(DownloadProgressInfo info) {
      final stage = info.isExtracting
          ? PackDownloadStage.extracting
          : PackDownloadStage.downloading;
      final message = info.isExtracting
          ? 'Đang giải nén (${_formatPercent(info.progress)})'
          : 'Đang tải (${_formatPercent(info.progress)})';
      _updatePackState(pack.id, stage: stage, message: message, progress: info);
      _emitInitialIfNeeded(
        task,
        info.isExtracting
            ? 'Đang giải nén dữ liệu...'
            : 'Đang tải ${pack.title}...',
        progress: info,
      );
    }

    progressSub = downloader.progressStream.listen(updateProgress);
    statusSub = downloader.statusStream.listen((status) {
      if (status == 'Hoàn thành!' || status == 'Đã tải và giải nén') {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });
    failureSub = downloader.failureStream.listen((failure) {
      _updatePackState(
        pack.id,
        stage: PackDownloadStage.failed,
        message: failure.message,
        resetProgress: true,
      );
      _emitInitialIfNeeded(task, 'Lỗi tải ${pack.title}: ${failure.message}');
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    final success = await _startDownload(downloader, task.force, completer);

    await progressSub.cancel();
    await statusSub.cancel();
    await failureSub.cancel();

    downloader.dispose();
    task.downloader = null;

    if (success) {
      _updatePackState(
        pack.id,
        stage: PackDownloadStage.completed,
        message: 'Đã sẵn sàng',
        resetProgress: true,
      );
      _emitInitialIfNeeded(task, '${pack.title} đã sẵn sàng', isComplete: true);
    } else {
      final currentState = _packStates[pack.id];
      if (currentState == null ||
          currentState.stage != PackDownloadStage.failed) {
        _updatePackState(
          pack.id,
          stage: PackDownloadStage.failed,
          message: 'Không thể tải dữ liệu.',
          resetProgress: true,
        );
      }
    }

    return success;
  }

  Future<bool> _startDownload(
    FileDownloader downloader,
    bool force,
    Completer<bool> completer,
  ) async {
    try {
      await downloader.downloadAndExtract(force: force);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    }

    return completer.future;
  }

  Future<void> _forceRedownloadPack(String packId) async {
    final packState = _packStates[packId];
    if (packState == null) {
      return;
    }
    final success = await _enqueueDownload(
      packState.pack,
      priority: true,
      force: true,
    );
    if (!success) {
      throw ContentInitializationException(
        'Không thể khôi phục dữ liệu cho ${packState.pack.title}.',
      );
    }
  }

  void _emitInitial(
    String message, {
    DownloadProgressInfo? progress,
    bool isComplete = false,
  }) {
    if (_initialController.isClosed) {
      return;
    }
    _initialController.add(
      InitialDownloadState(
        message: message,
        progress: progress,
        isComplete: isComplete,
      ),
    );
  }

  void _emitInitialIfNeeded(
    _QueuedDownload task,
    String message, {
    DownloadProgressInfo? progress,
    bool isComplete = false,
  }) {
    if (task.isInitial) {
      _emitInitial(message, progress: progress, isComplete: isComplete);
    }
  }

  void _updatePackState(
    String packId, {
    PackDownloadStage? stage,
    String? message,
    DownloadProgressInfo? progress,
    bool resetProgress = false,
  }) {
    final current = _packStates[packId];
    if (current == null) {
      return;
    }
    _packStates[packId] = current.copyWith(
      stage: stage,
      message: message,
      progress: progress,
      resetProgress: resetProgress,
    );
    _emitPackStates();
  }

  void _emitPackStates() {
    if (_packStateController.isClosed) {
      return;
    }
    _packStateController.add(
      Map<String, PackDownloadState>.unmodifiable(
        Map<String, PackDownloadState>.from(_packStates),
      ),
    );
  }

  String _formatPercent(double value) =>
      '${(value.clamp(0.0, 1.0) * 100).toStringAsFixed(0)}%';
}
