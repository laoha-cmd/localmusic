import '../utils/utils.dart';

class AppListResponse {
  int code;
  String msg;
  List<AppInfo> apps = [];

  AppListResponse(this.code, this.msg);

  factory AppListResponse.fromJson(Map<String, dynamic> json) {
    var ret = AppListResponse(json['code'], json['msg']);

    if (ret.code == 200 && json.containsKey('data')) {
      final pList = json['data'] as List;

      if (pList.isNotEmpty) {
        ret.apps = pList.map((e) => AppInfo.fromJson(e)).toList();
      }
    }

    return ret;
  }
}

class AppInfo {
  String name;
  String description;
  String url;
  String icon;

  AppInfo(
    this.name,
    this.description,
    this.url,
    this.icon,
  );

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    final href1 = json['href1'];
    final href2 = json['href2'];

    if (Utils.timestamp() % 2 == 0) {
      return AppInfo(json['title'], json['memo'], href1, json['icon']);
    }

    return AppInfo(json['title'], json['memo'], href2, json['icon']);
  }

  @override
  String toString() {
    return 'AppInfo{name: $name, icon: $icon, url: $url, description: $description}';
  }
}
