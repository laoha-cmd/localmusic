import 'dart:convert';
import 'dart:io';

import '../modles/audio_file.dart';
import 'utils.dart';

const _keyPlayListName = "_play_list_";
const _keySelectedName = "_play_selected";

class DataHelper {
  static final DataHelper _instance = DataHelper._internal();
  factory DataHelper() => _instance;
  DataHelper._internal();

  bool showRecommApp = false;
  Map<String, List<AudioFile>> songsMap = {};

  String _appDir = "";
  String _selectedName = "";

  String get appDir => _appDir;
  String get selectedName => _selectedName;

  Future<void> initDataHelper() async {
    final born = Utils.getKeyValue("born");
    int bornTick = Utils.timestamp();
    int openTimes = 0;

    if (born.isEmpty) {
      Utils.setKeyValue("born", bornTick.toString());
    } else {
      bornTick = int.parse(born);
    }

    final strTimes = Utils.getKeyValue("openTimes");
    if (strTimes.isEmpty) {
      Utils.setKeyValue("openTimes", openTimes.toString());
    } else {
      openTimes = int.parse(strTimes);

      openTimes++;
      Utils.setKeyValue("openTimes", openTimes.toString());
    }

    if (openTimes > 30 && bornTick + (3600 * 24 * 30) < Utils.timestamp()) {
      showRecommApp = true;
    }

    _appDir = await Utils.getAppDir();
    if (_appDir.isEmpty) {
      _appDir = await Utils.getDownloadDir();
    }

    final strValue = Utils.getKeyValue(_keyPlayListName);
    if (strValue.isNotEmpty) {
      final val = jsonDecode(strValue);
      if (val is List) {
        for (var ele in val) {
          final pathName = _playListFileName(ele);
          final content = Utils.getFileFull(pathName);

          if (content.isEmpty) {
            continue;
          }

          final pAudios = Utils.parseAudioFileContent(content);
          songsMap[ele] = pAudios;
          print("title:$ele ,pathName:$pathName, audio size:${pAudios.length}");
        }
      } else {
        print("val type is ${val.runtimeType}");
      }
    }

    final selected = Utils.getKeyValue(_keySelectedName);
    if (selected.isNotEmpty) {
      if (songsMap.containsKey(selected)) {
        _selectedName = selected;
      } else {
        _selectedName = "";
      }
    }

    Utils.logout(
        "bornTick=$bornTick,openTimes=$openTimes,appDir=$_appDir，keys=$strValue,selected=$_selectedName");
  }

  bool setSelectPlayListName(String name) {
    if (!songsMap.containsKey(name)) {
      return false;
    }

    _selectedName = name;
    Utils.setKeyValue(_keySelectedName, _selectedName);

    return true;
  }

  void _savePlayListKeys() {
    if (songsMap.isEmpty) return;

    final val = songsMap.keys.toList();
    final content = jsonEncode(val);

    Utils.setKeyValue(_keyPlayListName, content);
  }

  bool addPlayList(String title) {
    if (songsMap.containsKey(title)) return false;

    List<AudioFile> val = [];
    songsMap[title] = val;

    _savePlayListKeys();

    return true;
  }

  List<String> getPlayLists() {
    return songsMap.keys.toList();
  }

  List<String> getExceptPlayLists(String title) {
    final lists = List<String>.from(songsMap.keys.toList());
    lists.removeWhere((val) => val == title);

    return lists;
  }

  String _playListFileName(String title) {
    return "$_appDir/$title.json";
  }

  void addSongs(List<AudioFile> songs) {
    addListSongs(_selectedName, songs);
  }

  void removeSong(String fullPath) {
    removeListSong(_selectedName, fullPath);
  }

  void removeAllSongs() {
    removeListAllSongs(_selectedName);
  }

  void addListSongs(String title, List<AudioFile> songs) {
    if (!songsMap.containsKey(title)) return;

    final pList = songsMap[title];
    for (AudioFile song in songs) {
      if (!pList!.any((item) => item.path == song.path)) {
        pList.add(song);
      }
    }

    final fileName = _playListFileName(title);
    final content = Utils.convertAudioFileList(pList!);
    Utils.flushFile(fileName, content);
  }

  void removeListSong(String title, String fullPath) {
    if (!songsMap.containsKey(title)) return;

    final pList = songsMap[title];

    for (var idx = 0; idx < pList!.length; idx++) {
      if (pList[idx].path == fullPath) {
        pList.removeAt(idx);
        break;
      }
    }

    final fileName = _playListFileName(title);
    final content = Utils.convertAudioFileList(pList);
    Utils.flushFile(fileName, content);
  }

  void removeListAllSongs(String title) {
    if (!songsMap.containsKey(title)) return;

    final pList = songsMap[title];

    pList!.clear();

    final fileName = _playListFileName(title);
    final content = Utils.convertAudioFileList(pList);
    Utils.flushFile(fileName, content);
  }

  List<AudioFile> getPlayListSongs(String title) {
    if (title.isEmpty) {
      title = _selectedName;
    }

    if (!songsMap.containsKey(title)) {
      return [];
    }

    final pList = songsMap[title];

    if (null == pList) {
      return [];
    }

    return pList;
  }

  void setPlayListSongTitle(String pathName, String name) {
    String title = _selectedName;

    if (!songsMap.containsKey(title)) return;

    final pList = songsMap[title];

    for (var idx = 0; idx < pList!.length; idx++) {
      if (pList[idx].path == pathName) {
        final oldAudio = pList[idx];
        pList[idx] = AudioFile(
            path: oldAudio.path, title: name, artist: oldAudio.artist);
        break;
      }
    }

    final fileName = _playListFileName(title);
    final content = Utils.convertAudioFileList(pList);
    Utils.flushFile(fileName, content);
  }

  void changePlayListName(String oldName, String newName) {
    if (!songsMap.containsKey(oldName)) return;

    final oldList = songsMap[oldName];
    final fileName = _playListFileName(oldName);
    File file = File(fileName);

    final fileNewName = _playListFileName(newName);
    file.rename(fileNewName);

    songsMap.remove(oldName);
    songsMap[newName] = oldList!;

    if (_selectedName == oldName) {
      _selectedName = newName;
      Utils.setKeyValue(_keySelectedName, _selectedName);
    }

    _savePlayListKeys();
  }

  void removePlayList(String title) {
    if (_selectedName == title) {
      _selectedName = "";
    }

    songsMap.remove(title);

    final fileName = _playListFileName(title);
    File file = File(fileName);
    file.delete();

    _savePlayListKeys();
  }

  void copyAudioToPlayList(final AudioFile audio, final String titleName) {
    final pList = songsMap[titleName];
    if (null != pList && pList.isNotEmpty) {
      int idx = -1;
      for (var i = 0; i < pList.length; i++) {
        if (pList[i].path == audio.path) {
          idx = i;
          break;
        }
      }

      if (idx > -1) return;

      pList.add(audio);

      final fileName = _playListFileName(titleName);
      final content = Utils.convertAudioFileList(pList);
      Utils.flushFile(fileName, content);
    } else {
      List<AudioFile> pAudios = [];
      pAudios.add(audio);

      songsMap[titleName] = pAudios;

      final fileName = _playListFileName(titleName);
      final content = Utils.convertAudioFileList(pAudios);
      Utils.flushFile(fileName, content);
    }
  }

  void moveAudioToPlayList(final AudioFile audio, final String titleName) {
    copyAudioToPlayList(audio, titleName);
    removeSong(audio.path);
  }
}
