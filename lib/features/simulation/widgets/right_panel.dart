import 'dart:io';

import 'package:flutter/material.dart';
import 'package:ontapmophong/features/simulation/widgets/quiz_content_view.dart';
import 'package:ontapmophong/features/simulation/widgets/review_content_view.dart';
import 'package:ontapmophong/models/situation.dart';
import 'package:ontapmophong/widgets/group_box.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RightPanel extends StatelessWidget {
  final String selectedOption;
  final Situation? selectedSituation;
  final int grades;
  final List<Situation> quizSituations;

  const RightPanel({
    super.key,
    required this.selectedOption,
    this.selectedSituation,
    required this.grades,
    required this.quizSituations,
  });

  Future<String> _generateImagePath(String imageName) async {
    final int imageNumber = int.parse(imageName.replaceAll('.png', ''));
    String chapter = "";
    if (imageNumber <= 29) {
      chapter = 'chapter1';
    } else if (imageNumber <= 43) {
      chapter = 'chapter2';
    } else if (imageNumber <= 63) {
      chapter = 'chapter3';
    } else if (imageNumber <= 73) {
      chapter = 'chapter4';
    } else if (imageNumber <= 90) {
      chapter = 'chapter5';
    } else {
      chapter = 'chapter6';
    }

    final directory = await getApplicationDocumentsDirectory();
    return p.join(
      directory.path,
      'videos',
      chapter,
      "th$imageNumber",
      imageName,
    );
  }

  Future<void> _showHintModal(
    BuildContext context,
    String imagePath,
    String suggestedDetails,
  ) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Gợi ý'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (File(imagePath).existsSync())
                  Image.file(
                    File(imagePath),
                    width: 854,
                    height: 480,
                    fit: BoxFit.cover,
                  ),
                if (!File(imagePath).existsSync())
                  const Text('Không tìm thấy hình ảnh gợi ý.'),
                const SizedBox(height: 8),
                Text(
                  suggestedDetails,
                  style: TextStyle(fontSize: 18, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                iconSize: 20,
              ),
              child: const Text('Đóng', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueGrey[50],
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          GroupBox(
            title: "Kết quả",
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.red, fontSize: 14),
              child: Table(
                columnWidths: const {
                  0: IntrinsicColumnWidth(),
                  1: FlexColumnWidth(),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  _buildResultRow(
                    Icons.flag_rounded,
                    "Số tình huống:",
                    "${(selectedOption == 'Ôn tập') ? 1 : 10}",
                  ),
                  _buildResultRow(
                    Icons.edit_note,
                    "Điểm:",
                    "$grades/${(selectedOption == 'Ôn tập') ? 5 : 40}",
                  ),
                  _buildResultRow(
                    Icons.grade,
                    "Đánh giá:",
                    grades > 0 ? "Đạt" : "Chưa đạt",
                  ),
                ],
              ),
            ),
          ),
          (selectedOption != 'Ôn tập')
              ? Expanded(child: QuizContentView(quizTHs: quizSituations))
              : Expanded(
                  child: ReviewContentView(selectedTH: selectedSituation),
                ),
          SizedBox(height: 16),
          if (selectedSituation != null)
            ElevatedButton(
              onPressed: () async {
                String imagePath = await _generateImagePath(
                  selectedSituation!.suggestedImage,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showHintModal(
                    context,
                    imagePath,
                    selectedSituation!.suggestedDetails.replaceAll(
                      "Gợi ý: ",
                      "",
                    ),
                  );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                iconSize: 20,
              ),
              child: const Text(
                'Xem gợi ý',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  TableRow _buildResultRow(IconData icon, String label, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 4),
              Text(label),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.only(left: 4), child: Text(value)),
      ],
    );
  }
}
