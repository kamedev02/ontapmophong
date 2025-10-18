import 'package:ontapmophong/models/situation.dart';

class Chapter {
  final String id;
  final String folder;
  final String title;
  final List<Situation> situations;

  Chapter({
    required this.id,
    required this.folder,
    required this.title,
    required this.situations,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    var list = (json['situations'] as List)
        .map((e) => Situation.fromJson(e))
        .toList();

    list.sort(
      (a, b) => _extractNumber(a.title).compareTo(_extractNumber(b.title)),
    );
    return Chapter(
      id: json['id'],
      title: json['title'],
      folder: json['folder'],
      situations: list,
    );
  }

  static int _extractNumber(String text) {
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(text);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    return 0;
  }
}
