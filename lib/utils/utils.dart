import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:typed_data';
import 'package:audio_metadata_extractor/audio_metadata_extractor.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:localstorage/localstorage.dart';
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
//import 'package:http/http.dart' as http;

//import '../modles/apps.dart';
import '../modles/audio_file.dart';

const _keyList1 = [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08];
const _keyList2 = [0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18];
const _keyList3 = [0x1D, 0x1E, 0x1A, 0x2c, 0x3D, 0x4D, 0x51, 0x88];

class FileData {
  String dirPath;
  String fileName;
  String extetion;

  FileData(this.dirPath, this.fileName, this.extetion);
}

class AudioDetail {
  String album = "";
  String firstArtists = "";
  String secondArtists = "";
  String composer = "";
  String trackName = "";

  @override
  String toString() {
    return "{album:$album,firstArtists:$firstArtists,secondArtists:$secondArtists,composer:$composer,trackName:$trackName,}";
  }
}

class MyCompleter<T> {
  Completer<T> completer = Completer();

  MyCompleter();

  Future<T> get future => completer.future;

  void reply(T result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }
}

class Utils {
  static String getBroadIp(String ip) {
    final idx = ip.lastIndexOf(".");
    if (idx > 0) {
      return "${ip.substring(0, idx + 1)}255";
    }

    return "";
  }

  static String getRandomString(int len) {
    const String org = "abcdefghijklmnopqrstuvwxyz1234567890";
    var rder = Random(DateTime.now().microsecondsSinceEpoch);
    var ret = "";
    for (var i = 0; i < len; i++) {
      var cur = org[rder.nextInt(org.length)];

      ret += cur;
    }

    return ret;
  }

  static Future<int> formatFileSize(String path) async {
    File file = File(path);
    try {
      int fileSize = await file.length();
      return fileSize;
    } catch (e) {
      print('Error: $e');
      return 0;
    }
  }

  static String formatPercent(int progress, int total) {
    if (total == 0) return "100%";

    return "${(progress * 100 / total).toStringAsFixed(1)}%";
  }

  static String saveFileFull(String filePath, List<int> content) {
    try {
      File file = File(filePath);
      file.writeAsBytesSync(content);
      return "";
    } catch (e) {
      return "$e";
    }
  }

  static String flushFile(String filePath, String content) {
    try {
      File file = File(filePath);
      file.writeAsString(content);
      return "";
    } catch (e) {
      return "$e";
    }
  }

  static String appendFile(String filePath, List<int> content) {
    try {
      File file = File(filePath);
      file.writeAsBytesSync(content, mode: FileMode.append);
      return "";
    } catch (e) {
      return "$e";
    }
  }

  static String getFileFull(String fName) {
    try {
      File file = File(fName);

      return file.readAsStringSync();
    } catch (e) {
      return "";
    }
  }

  static Future<List<int>> getFileContent(
      String fName, int offset, int length) {
    File file = File(fName);
    final c = MyCompleter<List<int>>();

    List<int> result = [];
    file.openRead(offset, offset + length).listen((data) {
      result.addAll(data);
    }).onDone(() {
      c.reply(result);
    });

    return c.future;
  }

  static int timestamp() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  static int mstimestamp() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  static void logout(String content) {
    print("jhPlayer:$content");
  }

  static Future<String> getAppDir() async {
    final Directory downloadsDir = await getApplicationSupportDirectory();

    return downloadsDir.path;
  }

  static Future<String> getTempDir() async {
    final Directory tempDir = await getTemporaryDirectory();

    return tempDir.path;
  }

  static Future<String> getDownloadDir() async {
    final Directory? downloadsDir = await getDownloadsDirectory();

    return downloadsDir!.path;
  }

  static String getKeyValue(String key) {
    final ret = localStorage.getItem(key);
    if (null == ret) {
      return "";
    }

    return ret;
  }

  static void setKeyValue(String key, String value) {
    localStorage.setItem(key, value);
  }

  static FileData parseFilePath(String pathName) {
    return FileData(
        p.dirname(pathName), p.basename(pathName), p.extension(pathName));
  }

  static Future<AudioDetail> parseAudioInfo(String pathName) async {
    final file = File(pathName);
    final metadata = await AudioMetadata.extract(file);
    AudioDetail ret = AudioDetail();
    if (metadata != null) {
      if (null != metadata.album) ret.album = metadata.album!;
      if (null != metadata.firstArtists) {
        ret.firstArtists = metadata.firstArtists!;
      }

      if (null != metadata.secondArtists) {
        ret.secondArtists = metadata.secondArtists!;
      }

      if (null != metadata.trackName) ret.trackName = metadata.trackName!;
      if (null != metadata.composer) ret.composer = metadata.composer!;
    }

    return ret;
  }

  static Uint8List encryptAes(String plainText) {
    final keyList = List<int>.from(_keyList1);
    keyList.addAll(_keyList2);
    keyList.addAll(_keyList3);

    final key = Key.fromUtf8(String.fromCharCodes(keyList));

    final iv = IV.allZerosOfLength(16);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    return encrypted.bytes;
  }

  static String decryptAes(Uint8List cipherText, String keyString) {
    final keyList = List<int>.from(_keyList1);
    keyList.addAll(_keyList2);
    keyList.addAll(_keyList3);

    final key = Key.fromUtf8(String.fromCharCodes(keyList));

    final iv = IV.allZerosOfLength(16);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final decrypted = encrypter.decryptBytes(Encrypted(cipherText), iv: iv);

    return utf8.decode(decrypted);
  }

  // static Future<List<AppInfo>> fetchRecommApps(
  //     Map<String, dynamic> originalData) async {
  //   try {
  //     final plainReq = jsonEncode(originalData);
  //     final requestBody = encryptAes(plainReq);
  //     final apiHref = "https://your-api-endpoint.com";

  //     final response = await http.post(
  //       Uri.parse('$apiHref/api/app/recomm'),
  //       headers: {'Content-Type': 'application/octet-stream'},
  //       body: requestBody,
  //     );

  //     if (response.statusCode == 200) {
  //       final rspData = Uint8List.fromList(response.body.codeUnits);
  //       final plainRsp = decryptAes(rspData, getRandomString(32));
  //       final decryptedData = jsonDecode(plainRsp);
  //       final ret = AppListResponse.fromJson(jsonDecode(decryptedData));

  //       if (ret.code == 200) {
  //         return ret.apps;
  //       }

  //       return [];
  //     } else {
  //       print('请求失败: ${response.statusCode}');
  //       return [];
  //     }
  //   } catch (e) {
  //     print('异常: $e');
  //     return [];
  //   }
  // }

  static bool isDesktop() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return true;
    }

    return false;
  }

  static String convertAudioFileList(List<AudioFile> pList) {
    return jsonEncode(pList);
  }

  static List<AudioFile> parseAudioFileContent(String content) {
    if (content.isEmpty) return [];

    try {
      final obj = jsonDecode(content);
      if (obj is List) {
        return obj.map((ele) => AudioFile.fromJson(ele)).toList();
      }

      return [];
    } catch (e) {
      print(e);
      return [];
    }
  }

  static const List<String> _audioExtensions = [
    'mp3',
    'wav',
    'aac',
    'ogg',
    'flac',
    'm4a',
    'wma',
    'aiff',
    'alac'
  ];

  static bool isAudioFile(String filePath) {
    final fName = filePath.toLowerCase();
    for (var element in _audioExtensions) {
      if (fName.endsWith(element)) {
        return true;
      }
    }

    return false;
  }

  static List<String> filterAudio(List<String> pList) {
    List<String> ret = [];
    for (var element in pList) {
      if (isAudioFile(element)) {
        ret.add(element);
      }
    }

    return ret;
  }

  static double safePercent(int progress, int duration) {
    double ret = progress / duration;

    if (ret > 1.0) return 1.0;

    return ret;
  }

  static Future<String> calculateMD5(File file) async {
    final bytes = await file.readAsBytes();

    return md5.convert(bytes).toString();
  }
}
