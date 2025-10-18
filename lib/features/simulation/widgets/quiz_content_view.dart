import 'package:flutter/material.dart';
import 'dart:math';

import 'package:ontapmophong/models/situation.dart';

class QuizContentView extends StatelessWidget {
  final List<Situation> quizTHs;

  const QuizContentView({super.key, required this.quizTHs});

  double _generateRandomScore() {
    final random = Random();
    return 8.0 + random.nextDouble() * 2.0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const <DataColumn>[
            DataColumn(
              label: Expanded(
                child: Text(
                  'Câu hỏi',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Điểm',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          rows: quizTHs.map((th) {
            return DataRow(
              cells: <DataCell>[
                DataCell(Text(th.title)),
                DataCell(Text(_generateRandomScore().toStringAsFixed(2))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
