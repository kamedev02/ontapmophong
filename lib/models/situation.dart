class Situation {
  final String id;
  final String folder;
  final String title;
  final String suggestedImage;
  final String suggestedDetails;
  final String urlVideo;
  final String totalDuration;
  final List<double> scoreSegments;

  Situation({
    required this.id,
    required this.folder,
    required this.title,
    required this.suggestedImage,
    required this.suggestedDetails,
    required this.urlVideo,
    required this.totalDuration,
    required this.scoreSegments,
  });

  factory Situation.fromJson(Map<String, dynamic> json) {
    return Situation(
      id: json['id'],
      folder: json['folder'],
      title: json['title'],
      suggestedImage: json['suggested_image'],
      suggestedDetails: json['suggested_details'],
      urlVideo: json['url_video'],
      totalDuration: json['total_duration'],
      scoreSegments: json['score_segments'].cast<double>(),
    );
  }
}
