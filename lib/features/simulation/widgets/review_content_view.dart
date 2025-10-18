import 'package:flutter/material.dart';
import 'package:ontapmophong/models/situation.dart';

class ReviewContentView extends StatelessWidget {
  final Situation? selectedTH;

  const ReviewContentView({super.key, required this.selectedTH});

  @override
  Widget build(BuildContext context) {
    if (selectedTH == null) {
      return const Center(
        child: Text(
          'Chọn một bài học để xem chi tiết.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              selectedTH!.title.replaceAll("TH", "Tình huống "),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
