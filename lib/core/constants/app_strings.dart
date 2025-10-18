import 'package:flutter/material.dart';

ButtonStyle controlButtonStyle() {
  return ElevatedButton.styleFrom(
    shape: const CircleBorder(),
    padding: const EdgeInsets.all(0),
    backgroundColor: Colors.blue,
    iconSize: 20,
  );
}

Map<int, int> chapterCounts = {1: 29, 2: 14, 3: 20, 4: 10, 5: 17, 6: 30};
