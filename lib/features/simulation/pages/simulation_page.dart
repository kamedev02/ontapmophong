import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:ontapmophong/core/services/file_downloader.dart';
import 'package:ontapmophong/features/simulation/widgets/download_indicator.dart';
import 'package:ontapmophong/features/simulation/widgets/left_panel.dart';
import 'package:ontapmophong/features/simulation/widgets/right_panel.dart';
import 'package:ontapmophong/features/simulation/widgets/video_player_panel.dart';
import 'package:ontapmophong/models/chapter.dart';
import 'package:ontapmophong/models/situation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  // Downloader variables
  late final FileDownloader _fileDownloader;
  bool _isDownloaded = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = 'Kiểm tra tài nguyên...';

  @override
  void initState() {
    super.initState();
    player = Player();
    playerController = VideoController(player);

    _fileDownloader = FileDownloader(
      'https://api.kamedev.top/uploads/videos.zip',
      'videos.zip',
      'videos',
    );
    _controller.areas = [
      Area(size: 200, min: 200, max: 200),
      Area(flex: 1),
      Area(size: 225, min: 225, max: 225),
    ];
    _checkAndDownloadVideos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_playerFocusNode);
    });
  }

  @override
  void dispose() {
    player.dispose();
    _fileDownloader.dispose();
    _controller.dispose();
    _playerFocusNode.dispose();
    super.dispose();
  }

  // --- LOGIC METHODS ---
  Future<void> _checkAndDownloadVideos() async {
    final directory = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${directory.path}/videos');
    _isDownloaded = await videosDir.exists();

    if (_isDownloaded) {
      _loadChapters();
    } else {
      _fileDownloader.downloadAndExtract();
      _fileDownloader.progressStream.listen((progress) {
        setState(() => _downloadProgress = progress);
      });
      _fileDownloader.statusStream.listen((status) {
        setState(() {
          _downloadStatus = status;
          if (status == 'Hoàn thành!') {
            _isDownloaded = true;
            _downloadStatus = "Khởi chạy ứng dụng";
            _loadChapters();
          }
        });
      });
    }
  }

  Future<void> _loadChapters() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/data.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      setState(() {
        _chapters = jsonList.map((e) => Chapter.fromJson(e)).toList();
        _allSituations = _chapters
            .expand((chapter) => chapter.situations)
            .toList();
      });
      _generateQuizTHs();
    } catch (e) {
      debugPrint('Lỗi khi tải tài nguyên: $e');
    }
  }

  void _generateQuizTHs() {
    _quizSituations.clear();
    final random = Random();

    final Map<int, int> situationCounts = {0: 2, 1: 1, 2: 2, 3: 1, 4: 2, 5: 2};

    situationCounts.forEach((chapterIndex, count) {
      if (chapterIndex < _chapters.length) {
        final chapterSituations = List<Situation>.from(
          _chapters[chapterIndex].situations,
        );
        chapterSituations.shuffle(random);
        _quizSituations.addAll(chapterSituations.take(count));
      }
    });

    _quizSituations.shuffle(random);
  }

  Future<String> _generateVideoPath(
    String chapter,
    String situation,
    String filename,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    return p.join(directory.path, 'videos', chapter, situation, filename);
  }

  void _loadAndPlay(String filepath) {
    player.open(Media('file://$filepath'), play: false);
    debugPrint('Đã mở file: file://$filepath');
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
    String videoPath = await _generateVideoPath(
      chapter.folder,
      situation.folder,
      situation.urlVideo,
    );
    setState(() {
      _selectedSituationId = situation.id;
      _selectedSituation = situation;
      _currentVideoPath = videoPath;
      _flagPosition = null;
      _showSegment = false;
      _isPlay = false;
      _currentSituationIndex = _allSituations.indexOf(situation);
    });
    _loadAndPlay(_currentVideoPath!);
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
      final videoPath = await _generateVideoPath(
        chapter.folder,
        nextSituation.folder,
        nextSituation.urlVideo,
      );
      setState(() {
        _currentSituationIndex++;
        _selectedSituation = nextSituation;
        _selectedSituationId = nextSituation.id;
        _currentVideoPath = videoPath;
        _flagPosition = null;
        _showSegment = false;
        _isPlay = false;
        _loadAndPlay(_currentVideoPath!);
      });
    }
  }

  void _onPrev() async {
    if (_currentSituationIndex > 0) {
      final prevSituation = _allSituations[_currentSituationIndex - 1];
      final chapter = _chapters.firstWhere(
        (chap) => chap.situations.contains(prevSituation),
      );
      final videoPath = await _generateVideoPath(
        chapter.folder,
        prevSituation.folder,
        prevSituation.urlVideo,
      );
      setState(() {
        _currentSituationIndex--;
        _selectedSituation = prevSituation;
        _selectedSituationId = prevSituation.id;
        _currentVideoPath = videoPath;
        _flagPosition = null;
        _showSegment = false;
        _isPlay = false;
        _loadAndPlay(_currentVideoPath!);
      });
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
    return Scaffold(
      body: (!_isDownloaded)
          ? DownloadIndicator(
              downloadStatus: _downloadStatus,
              downloadProgress: _downloadProgress,
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
                      scoreSegments: _showSegment
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
