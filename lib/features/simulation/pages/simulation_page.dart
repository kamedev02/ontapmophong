import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:ontapmophong/core/services/content_manager.dart';
import 'package:ontapmophong/core/services/file_downloader.dart';
import 'package:ontapmophong/features/simulation/widgets/download_indicator.dart';
import 'package:ontapmophong/features/simulation/widgets/left_panel.dart';
import 'package:ontapmophong/features/simulation/widgets/download_queue_fab.dart';
import 'package:ontapmophong/features/simulation/widgets/right_panel.dart';
import 'package:ontapmophong/features/simulation/widgets/video_player_panel.dart';
import 'package:ontapmophong/models/chapter.dart';
import 'package:ontapmophong/models/situation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class SimulationPage extends StatefulWidget {
  const SimulationPage({super.key});

  @override
  SimulationPageState createState() => SimulationPageState();
}

class SimulationPageState extends State<SimulationPage> {
  // State variables
  final MultiSplitViewController _controller = MultiSplitViewController();
  String _selectedOption = "Ôn tập";
  String? _selectedSituationId;
  List<Chapter> _chapters = [];
  List<Situation> _allSituations = [];
  int _currentSituationIndex = -1;
  String? _currentVideoPath;
  Situation? _selectedSituation;
  final List<Situation> _quizSituations = [];
  int _grades = 0;

  // Player variables
  late final Player player;
  late final VideoController playerController;
  final FocusNode _playerFocusNode = FocusNode();
  Duration? _flagPosition;
  bool _flagAllowed = false;
  bool _showSegment = false;
  bool _isPlay = false;
  double? _dragValue;

  // Content & download variables
  late final ContentManager _contentManager;
  bool _isReady = false;
  String _downloadStatus = 'Đang chuẩn bị dữ liệu...';
  DownloadProgressInfo? _progressInfo;
  Map<String, PackDownloadState> _packStates = {};
  Set<String> _availableChapterIds = {};
  StreamSubscription<InitialDownloadState>? _initialSubscription;
  StreamSubscription<Map<String, PackDownloadState>>? _packStatesSubscription;
  bool _showingFailureDialog = false;
  bool _showDownloadQueue = false;

  @override
  void initState() {
    super.initState();
    player = Player();
    playerController = VideoController(player);

    _contentManager = ContentManager(
      manifestUrl:
          'https://github.com/kamedev02/ontapmophong/releases/download/v25.10.1/manifest.json',
      manifestAssetPath: 'assets/manifest.json',
    );

    _controller.areas = [
      Area(size: 200, min: 200, max: 200),
      Area(flex: 1),
      Area(size: 225, min: 225, max: 225),
    ];
    _initializeContent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_playerFocusNode);
    });
  }

  @override
  void dispose() {
    _initialSubscription?.cancel();
    _packStatesSubscription?.cancel();
    player.dispose();
    unawaited(_contentManager.dispose());
    _controller.dispose();
    _playerFocusNode.dispose();
    super.dispose();
  }

  // --- LOGIC METHODS ---
  Future<void> _initializeContent() async {
    await _initialSubscription?.cancel();
    await _packStatesSubscription?.cancel();
    _initialSubscription = null;
    _packStatesSubscription = null;

    _initialSubscription = _contentManager.initialDownloadStream.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() {
        _downloadStatus = state.message;
        _progressInfo = state.progress;
        if (state.isComplete) {
          _progressInfo = state.progress ?? _progressInfo;
        }
      });
    });

    _packStatesSubscription = _contentManager.packStatesStream.listen((states) {
      if (!mounted) {
        return;
      }
      setState(() {
        _packStates = states;
        _availableChapterIds = states.entries
            .where((entry) => entry.value.stage == PackDownloadStage.completed)
            .map((entry) => entry.key)
            .toSet();
        _rebuildAvailableSituations();
        if (_selectedOption == 'Thi thử') {
          _generateQuizTHs();
        }
      });
    });

    try {
      await _contentManager.initialize();
      await _loadChapters();
      if (!mounted) {
        return;
      }
      setState(() {
        _isReady = true;
        _downloadStatus = 'Khởi chạy ứng dụng';
      });
    } on ContentInitializationException catch (error) {
      await _handleInitializationFailure(error.message);
    } catch (error) {
      await _handleInitializationFailure(error.toString());
    }
  }

  Future<void> _loadChapters() async {
    try {
      final String jsonString = await _contentManager.loadDataJson();
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _chapters = jsonList.map((e) => Chapter.fromJson(e)).toList();
      });
      _rebuildAvailableSituations();
      _generateQuizTHs();
    } catch (e) {
      debugPrint('Lỗi khi tải tài nguyên: $e');
    }
  }

  void _rebuildAvailableSituations() {
    final availableChapters = _chapters
        .where((chapter) => _availableChapterIds.contains(chapter.folder))
        .toList();
    _allSituations = availableChapters
        .expand((chapter) => chapter.situations)
        .toList();

    if (_selectedSituation != null) {
      _currentSituationIndex = _allSituations.indexWhere(
        (situation) => situation.id == _selectedSituation!.id,
      );
    } else {
      _currentSituationIndex = -1;
    }
  }

  Future<void> _handleInitializationFailure(String message) async {
    if (!mounted || _showingFailureDialog) {
      return;
    }
    _showingFailureDialog = true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Không thể tải dữ liệu'),
        content: Text('$message\n\nBạn muốn làm gì tiếp theo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('exit'),
            child: const Text('Đóng ứng dụng'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('retry'),
            child: const Text('Tải lại'),
          ),
        ],
      ),
    );

    _showingFailureDialog = false;

    if (result == 'retry') {
      if (!mounted) {
        return;
      }
      setState(() {
        _progressInfo = null;
        _downloadStatus = 'Đang khởi động lại tải xuống...';
        _packStates = {};
        _availableChapterIds = {};
        _isReady = false;
        _allSituations = [];
        _selectedSituation = null;
        _selectedSituationId = null;
        _currentSituationIndex = -1;
        _currentVideoPath = null;
      });
      await _initialSubscription?.cancel();
      await _packStatesSubscription?.cancel();
      _initialSubscription = null;
      _packStatesSubscription = null;
      await _contentManager.dispose();
      _contentManager = ContentManager(
        manifestUrl:
            'https://github.com/kamedev02/ontapmophong/releases/download/v25.10.1/manifest.json',
        manifestAssetPath: 'assets/manifest.json',
      );
      await _initializeContent();
      return;
    }

    if (result == 'exit') {
      await windowManager.close();
    }
  }

  void _generateQuizTHs() {
    _quizSituations.clear();
    final random = Random();

    final Map<int, int> situationCounts = {0: 2, 1: 1, 2: 2, 3: 1, 4: 2, 5: 2};

    situationCounts.forEach((chapterIndex, count) {
      if (chapterIndex >= _chapters.length) {
        return;
      }
      final chapter = _chapters[chapterIndex];
      if (!_availableChapterIds.contains(chapter.folder)) {
        return;
      }
      final chapterSituations = List<Situation>.from(chapter.situations);
      chapterSituations.shuffle(random);
      _quizSituations.addAll(chapterSituations.take(count));
    });

    _quizSituations.shuffle(random);
  }

  Future<String> _generateVideoPath(
    String chapter,
    String situation,
    String filename,
  ) async {
    final baseDir =
        _contentManager.baseDirectory ??
        Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            _contentManager.basePath,
          ),
        );
    return p.join(baseDir.path, chapter, situation, filename);
  }

  void _loadAndPlay(String filepath) {
    player.open(Media('file://$filepath'), play: false);
    debugPrint('Đã mở file: file://$filepath');
  }

  Future<bool> _ensurePlaylistAvailable(
    Chapter chapter,
    Situation situation,
  ) async {
    try {
      await _contentManager.ensurePlaylistIntegrity(
        chapterId: chapter.folder,
        situationFolder: situation.folder,
        playlistFile: situation.urlVideo,
      );
      return true;
    } on ContentInitializationException catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return false;
    } catch (error) {
      debugPrint('Lỗi kiểm tra playlist: $error');
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể kiểm tra dữ liệu video.')),
      );
      return false;
    }
  }

  Future<void> _playSituation(Chapter chapter, Situation situation) async {
    final videoPath = await _generateVideoPath(
      chapter.folder,
      situation.folder,
      situation.urlVideo,
    );

    final ready = await _ensurePlaylistAvailable(chapter, situation);
    if (!ready || !mounted) {
      return;
    }

    final index = _allSituations.indexWhere((item) => item.id == situation.id);

    setState(() {
      _selectedSituationId = situation.id;
      _selectedSituation = situation;
      _currentVideoPath = videoPath;
      _flagPosition = null;
      _showSegment = false;
      _isPlay = false;
      _currentSituationIndex = index;
    });
    _loadAndPlay(_currentVideoPath!);
  }

  // --- UI HANDLER METHODS ---
  void _handleModeChange(String? newValue) {
    if (_selectedOption == newValue) {
      FocusScope.of(context).requestFocus(_playerFocusNode);
      return;
    }
    setState(() {
      _selectedOption = newValue!;
      if (newValue == 'Thi thử') {
        _generateQuizTHs();
      }
      _selectedSituationId = null;
      _currentVideoPath = null;
      _selectedSituation = null;
    });
    FocusScope.of(context).requestFocus(_playerFocusNode);
  }

  void _handleSituationSelected(Chapter chapter, Situation situation) async {
    await _playSituation(chapter, situation);
  }

  void _handlePlay() {
    setState(() => _isPlay = true);
    player.play();
  }

  void _handlePause() {
    setState(() => _isPlay = false);
    player.pause();
  }

  void _handleRefresh() {
    setState(() {
      _showSegment = false;
    });

    setState(() {
      _flagPosition = null;
      _isPlay = false;
    });

    if (_currentVideoPath != null) {
      _loadAndPlay(_currentVideoPath!);
    }
  }

  void _onNext() async {
    if (_currentSituationIndex < _allSituations.length - 1) {
      final nextSituation = _allSituations[_currentSituationIndex + 1];
      final chapter = _chapters.firstWhere(
        (chap) => chap.situations.contains(nextSituation),
      );
      await _playSituation(chapter, nextSituation);
    }
  }

  void _onPrev() async {
    if (_currentSituationIndex > 0) {
      final prevSituation = _allSituations[_currentSituationIndex - 1];
      final chapter = _chapters.firstWhere(
        (chap) => chap.situations.contains(prevSituation),
      );
      await _playSituation(chapter, prevSituation);
    }
  }

  Future<void> _onCapture(Uint8List screenshot) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final screenshotsDir = Directory('${directory.path}/Screenshots');

      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'screenshot_$timestamp.png';

      final filePath = p.join(screenshotsDir.path, fileName);
      final file = File(filePath);

      await file.writeAsBytes(screenshot);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ảnh đã được lưu vào: ${file.path}')),
        );
      });
    } catch (e) {
      debugPrint('Lỗi khi lưu ảnh: $e');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi khi lưu ảnh chụp màn hình.')),
        );
      });
    }
  }

  void _handleFlag() {
    if (_flagAllowed && _flagPosition == null) {
      setState(() {
        _flagPosition = player.state.position;
        _flagAllowed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapterStatusLabels = <String, String>{
      for (final entry in _packStates.entries) entry.key: entry.value.message,
    };
    final pendingDownloads = _packStates.values
        .where((state) => state.stage != PackDownloadStage.completed)
        .toList();

    return Scaffold(
      floatingActionButton: pendingDownloads.isEmpty
          ? null
          : DownloadQueueFab(
              expanded: _showDownloadQueue,
              downloads: pendingDownloads,
              onToggle: () {
                setState(() {
                  _showDownloadQueue = !_showDownloadQueue;
                });
              },
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndFloat,
      body: (!_isReady)
          ? DownloadIndicator(
              downloadStatus: _downloadStatus,
              progressInfo: _progressInfo,
            )
          : MultiSplitView(
              controller: _controller,
              builder: (BuildContext context, Area area) {
                switch (area.index) {
                  case 0:
                    return LeftPanel(
                      selectedOption: _selectedOption,
                      chapters: _chapters,
                      selectedSituationId: _selectedSituationId,
                      isPlay: _isPlay,
                      availableChapters: _availableChapterIds,
                      chapterStatuses: chapterStatusLabels,
                      onModeChanged: _handleModeChange,
                      onSituationSelected: _handleSituationSelected,
                      onPlay: _handlePlay,
                      onPause: _handlePause,
                      onRefresh: _handleRefresh,
                      onPrev:
                          (_selectedOption == "Ôn tập" &&
                              _currentSituationIndex > 0 &&
                              _selectedSituation != null)
                          ? _onPrev
                          : null,
                      onNext:
                          (_selectedOption == "Ôn tập" &&
                              _currentSituationIndex <
                                  _allSituations.length - 1 &&
                              _selectedSituation != null)
                          ? _onNext
                          : null,
                      onCapture: () async {
                        final Uint8List? screenshot = await player.screenshot();
                        if (screenshot != null) {
                          await _onCapture(screenshot);
                        }
                      },
                    );
                  case 1:
                    return VideoPlayerPanel(
                      currentVideoPath: _currentVideoPath,
                      player: player,
                      playerController: playerController,
                      playerFocusNode: _playerFocusNode,
                      flagAllowed: _flagAllowed,
                      flagPosition: _flagPosition,
                      showSegment: _showSegment,
                      dragValue: _dragValue,
                      onFlag: _handleFlag,
                      onPlayStateChanged: (isPlaying) =>
                          setState(() => _isPlay = isPlaying),
                      onShowSegmentChanged: (show) =>
                          setState(() => _showSegment = show),
                      onFlagAllowedChanged: (allowed) =>
                          setState(() => _flagAllowed = allowed),
                      onDragUpdate: (value) =>
                          setState(() => _dragValue = value),
                      onSeek: (value) {
                        setState(() => _dragValue = null);
                        player.seek(Duration(milliseconds: value.toInt()));
                      },
                      onScoreChanged: (score) =>
                          setState(() => _grades = score),
                      scoreSegments:
                          (_showSegment && _selectedSituation != null)
                          ? _selectedSituation!.scoreSegments
                          : [],
                    );
                  case 2:
                    return RightPanel(
                      selectedOption: _selectedOption,
                      selectedSituation: _selectedSituation,
                      grades: _grades,
                      quizSituations: _quizSituations,
                    );
                  default:
                    return Container();
                }
              },
            ),
    );
  }
}
