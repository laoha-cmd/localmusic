class AudioFile {
  final String path;
  final String title;
  final String artist;
  String ablum = "";
  String hashed = "";

  AudioFile(
      {required this.path,
      required this.title,
      required this.artist,
      this.ablum = "",
      this.hashed = ""});

  factory AudioFile.fromJson(Map<String, dynamic> json) {
    final path = json['path'];
    final title = json['title'];
    final artist = json['artist'];
    String ablum = "";
    String md5 = "";

    if (json.containsKey("ablum")) {
      ablum = json['ablum'];
    }

    if (json.containsKey("hashed")) {
      md5 = json['hashed'];
    }

    return AudioFile(
        path: path, title: title, artist: artist, ablum: ablum, hashed: md5);
  }

  @override
  String toString() {
    return "{path:$path,title:$title,artist:$artist,ablum:$ablum}";
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> ret = {};
    ret["path"] = path;
    ret["title"] = title;
    ret["artist"] = artist;
    ret["ablum"] = ablum;
    ret["hashed"] = hashed;

    return ret;
  }
}
