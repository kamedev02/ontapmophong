import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

class FileDownloader {
  final String _zipUrl;
  final String _zipFileName;
  final String _extractionDirName;

  double _downloadProgress = 0.0;
  String _downloadStatus = 'Idle';

  FileDownloader(this._zipUrl, this._zipFileName, this._extractionDirName);

  double get downloadProgress => _downloadProgress;
  String get downloadStatus => _downloadStatus;

  final _progressStreamController = StreamController<double>();
  final _statusStreamController = StreamController<String>();

  Stream<double> get progressStream => _progressStreamController.stream;
  Stream<String> get statusStream => _statusStreamController.stream;

  Future<void> downloadAndExtract() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final zipFilePath = p.join(directory.path, _zipFileName);
      final extractionPath = p.join(directory.path, _extractionDirName);
      final extractedDir = Directory(extractionPath);

      if (!await extractedDir.exists()) {
        await extractedDir.create(recursive: true);
      }

      if (await extractedDir.exists() && !await extractedDir.list().isEmpty) {
        _updateStatus('Đã tải và giải nén');
        _updateProgress(1.0);
        return;
      }

      _updateStatus('Đang tải tài nguyên...');

      final file = File(zipFilePath);
      final request = http.Request('GET', Uri.parse(_zipUrl));
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        List<int> bytes = [];
        final totalBytes = response.contentLength!;
        debugPrint('$totalBytes');

        response.stream.listen(
          (List<int> chunk) {
            bytes.addAll(chunk);
            _updateProgress(bytes.length / totalBytes / 2);
          },
          onDone: () async {
            await file.writeAsBytes(bytes);
            _updateStatus('Tải xong, đang giải nén...');
            await _extractZipFile(zipFilePath, extractionPath);
            await file.delete();
            _updateStatus('Hoàn thành!');
          },
          onError: (e) {
            debugPrint('$e');
            _updateStatus('Lỗi tải xuống: $e');
            _updateProgress(0.0);
          },
        );
      } else {
        _updateStatus('Lỗi: ${response.statusCode}');
        _updateProgress(0.0);
        throw Exception('Failed to download file.');
      }
    } catch (e) {
      debugPrint('$e');
      _updateStatus('Lỗi chung: $e');
      _updateProgress(0.0);
    }
  }

  Future<void> _extractZipFile(String zipPath, String destinationPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final totalFiles = archive.length;
    int extractedCount = 0;

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        final newFilePath = p.join(destinationPath, filename);
        final newFile = File(newFilePath);
        await newFile.create(recursive: true);
        await newFile.writeAsBytes(data);
      } else {
        await Directory(
          p.join(destinationPath, filename),
        ).create(recursive: true);
      }

      extractedCount++;
      double progress = (extractedCount / totalFiles) * 0.5 + 0.5;
      _updateProgress(progress);
    }
  }

  void _updateProgress(double progress) {
    _downloadProgress = progress;
    if (!_progressStreamController.isClosed) {
      _progressStreamController.add(progress);
    }
  }

  void _updateStatus(String status) {
    _downloadStatus = status;
    if (!_statusStreamController.isClosed) {
      _statusStreamController.add(status);
    }
  }

  void dispose() {
    _progressStreamController.close();
    _statusStreamController.close();
  }
}
