import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../common/common.dart';
import '../modles/audio_file.dart';
import '../services/music_player_service.dart';
import '../ui/volume_popup_content.dart';
import '../ui/wavebar_animation.dart';
import '../utils/data_helper.dart';
import '../utils/utils.dart';
import 'about.dart';
import 'playlist_page.dart';

class MusicPlayerHome extends StatefulWidget {
  const MusicPlayerHome({super.key});

  @override
  State<MusicPlayerHome> createState() => _MusicPlayerHomeState();
}

class _MusicPlayerHomeState extends State<MusicPlayerHome> {
  final GlobalKey _buttonKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  String playListName = "";
  bool onAddFiles = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DataHelper dh = DataHelper();
      playListName = dh.selectedName;
      final pSongs = dh.getPlayListSongs(playListName);
      Utils.logout("playListName=$playListName, song size:${pSongs.length}");
      if (pSongs.isNotEmpty) {
        addSongToService(pSongs);
      }
    });
    super.initState();
  }

  Future<void> _requestPermissions() async {
    if (Theme.of(context).platform == TargetPlatform.android) {
      await Permission.storage.request();
    }
  }

  void showMsgBySnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content)),
    );
  }

  void addSongToService(List<AudioFile> songs) {
    context.read<PlaybackProvider>().addAudioFiles(songs);
  }

  void addSelectedFiles(List<String> paths) async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return SimpleDialog(
            title: Text("导入中..."),
            children: [
              Center(
                child: CircularProgressIndicator(),
              )
            ],
          );
        });

    DataHelper dh = DataHelper();

    if (playListName.isEmpty) {
      for (int i = 0; i < 100; i++) {
        if (i == 0) {
          playListName = "默认歌单";
          if (dh.addPlayList(playListName)) break;
        } else {
          playListName = "默认歌单$i";
          if (dh.addPlayList(playListName)) break;
        }
      }

      dh.setSelectPlayListName(playListName);
    }

    final audios = Utils.filterAudio(paths);

    final playList = dh.getPlayListSongs("");

    List<AudioFile> realSongs = [];
    final innerPath = dh.appDir;

    for (String srcPath in audios) {
      final srcMusic = File(srcPath);
      final srcHash = await Utils.calculateMD5(srcMusic);

      if (playList.any((song) => song.hashed == srcHash)) {
        continue;
      }

      final fData = Utils.parseFilePath(srcPath);
      String title = fData.fileName;
      String dstPath = "$innerPath/$title";
      if (Utils.isDesktop()) {
        dstPath = srcPath;
      } else {
        srcMusic.copySync(dstPath);
      }

      final info = await Utils.parseAudioInfo(dstPath);

      Utils.logout("$dstPath meta: ${info.toString()}");

      String artic = "未知艺术家";
      if (info.firstArtists.isNotEmpty) {
        artic = info.firstArtists;
      } else if (info.secondArtists.isNotEmpty) {
        artic = info.secondArtists;
      }

      if (info.trackName.isNotEmpty) title = info.trackName;

      realSongs.add(AudioFile(
          path: dstPath,
          title: title,
          artist: artic,
          ablum: info.album,
          hashed: srcHash));
    }

    if (realSongs.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    dh.addSongs(realSongs);

    addSongToService(realSongs);
    Navigator.of(context).pop();
  }

  Future<void> _pickAudioFiles() async {
    _requestPermissions();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
      );

      if (result != null) {
        List<String> paths = result.paths.whereType<String>().toList();
        if (paths.isNotEmpty) {
          addSelectedFiles(paths);
        }
      }
    } catch (e) {
      showMsgBySnack('选择文件失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theColor = Theme.of(context).colorScheme;
    DataHelper dh = DataHelper();

    //playListName = dh.selectedName;

    return Scaffold(
      appBar: AppBar(
        title: Text('本地音乐播放器'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: _pickAudioFiles,
          ),
          PopupMenuButton<String>(
            tooltip: "更多菜单",
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('确认操作'),
                        content: Text('你确定要移除歌单中所有文件？'),
                        actions: <Widget>[
                          TextButton(
                            child: Text('取消'),
                            onPressed: () {
                              Navigator.of(context).pop(); // 关闭对话框
                            },
                          ),
                          TextButton(
                            child: Text('确认'),
                            onPressed: () {
                              DataHelper dh = DataHelper();
                              dh.removeAllSongs();

                              context.read<PlaybackProvider>().clearPlaylist();
                              Navigator.of(context).pop(); // 关闭对话框
                            },
                          ),
                        ],
                      );
                    },
                  );
                  break;

                case 'playlists':
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return PlayListPage();
                  })).then((_) {
                    DataHelper dh = DataHelper();
                    setState(() {
                      playListName = dh.selectedName;
                      Utils.logout("playListName = $playListName");
                      final audios = dh.getPlayListSongs(playListName);
                      context.read<PlaybackProvider>().addAudioFiles(audios);
                    });
                  });

                  break;

                case 'about':
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return AboutPage();
                  }));
                  break;

                case 'recomm':
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.delete_sharp, size: 20, color: Colors.orange),
                    SizedBox(width: 10),
                    Text('清空播放列表'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'playlists',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.queue_music_rounded,
                        size: 20, color: Colors.deepPurpleAccent),
                    SizedBox(width: 10),
                    Text('歌单'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.help_sharp, size: 20, color: theColor.primary),
                    SizedBox(width: 10),
                    Text('关于'),
                  ],
                ),
              ),
              if (dh.showRecommApp && buildMode == 0)
                PopupMenuItem(
                  value: 'recomm',
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.thumb_up, size: 20, color: Colors.green),
                      SizedBox(width: 10),
                      Text('推荐工具'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<PlaybackProvider>(
              builder: (context, player, child) {
                if (player.playlist.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          '暂无音乐文件',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '点击右上角+号添加音乐文件',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: player.playlist.length,
                  itemBuilder: (context, index) {
                    final song = player.playlist[index];
                    final isCurrent = index == player.currentIndex;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            isCurrent ? Colors.blue : Colors.grey[300],
                        child: Icon(
                          isCurrent
                              ? Icons.music_note
                              : Icons.music_note_outlined,
                          color: isCurrent ? Colors.white : Colors.grey[700],
                        ),
                      ),
                      title: Text(
                        song.title,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? Colors.blue : null,
                        ),
                      ),
                      subtitle: Text(song.ablum.isEmpty
                          ? song.artist
                          : "${song.artist}  ${song.ablum} "),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isCurrent && player.isPlaying) WaveBarAnimation(),
                          PopupMenuButton<String>(
                            tooltip: "更多",
                            icon: Icon(Icons.more_vert, size: 20),
                            onSelected: (value) {
                              DataHelper dh = DataHelper();

                              switch (value) {
                                case "detail":
                                  _showAudioDetail(song);
                                  break;

                                case "remove":
                                  dh.removeSong(song.path);
                                  player.removeFile(index);
                                  break;

                                case "rename":
                                  _showEditNameDialog(context, index, song);
                                  break;

                                case "copyto":
                                  final others = DataHelper()
                                      .getExceptPlayLists(playListName);
                                  showModalBottomSheet<String>(
                                    context: context,
                                    isScrollControlled:
                                        true, // 允许 bottomsheet 占据更多空间
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20)),
                                    ),
                                    builder: (BuildContext context) {
                                      return DraggableScrollableSheet(
                                        initialChildSize: 0.6, // 初始高度为屏幕的60%
                                        minChildSize: 0.4, // 最小高度
                                        maxChildSize: 0.9, // 最大高度
                                        expand: false,
                                        builder: (context, scrollController) {
                                          return Container(
                                            padding: EdgeInsets.all(16),
                                            child: Column(
                                              children: [
                                                // 顶部标题和关闭按钮
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      '请选择歌单',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(Icons.close),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                    ),
                                                  ],
                                                ),
                                                Divider(),
                                                // 可滚动的列表部分
                                                Expanded(
                                                  child: ListView.builder(
                                                    controller:
                                                        scrollController,
                                                    itemCount: others.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      return ListTile(
                                                        title:
                                                            Text(others[index]),
                                                        onTap: () {
                                                          Navigator.pop(context,
                                                              others[index]);
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ).then((result) {
                                    if (result == null) return;
                                    if (result.isEmpty) return;
                                    DataHelper()
                                        .copyAudioToPlayList(song, result);

                                    showMsgBySnack(
                                        "已复制${song.title}到歌单$result");
                                  });
                                  break;

                                case "moveto":
                                  final others = DataHelper()
                                      .getExceptPlayLists(playListName);
                                  showModalBottomSheet<String>(
                                    context: context,
                                    isScrollControlled:
                                        true, // 允许 bottomsheet 占据更多空间
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20)),
                                    ),
                                    builder: (BuildContext context) {
                                      return DraggableScrollableSheet(
                                        initialChildSize: 0.6, // 初始高度为屏幕的60%
                                        minChildSize: 0.4, // 最小高度
                                        maxChildSize: 0.9, // 最大高度
                                        expand: false,
                                        builder: (context, scrollController) {
                                          return Container(
                                            padding: EdgeInsets.all(16),
                                            child: Column(
                                              children: [
                                                // 顶部标题和关闭按钮
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      '请选择歌单',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      icon: Icon(Icons.close),
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                    ),
                                                  ],
                                                ),
                                                Divider(),
                                                // 可滚动的列表部分
                                                Expanded(
                                                  child: ListView.builder(
                                                    controller:
                                                        scrollController,
                                                    itemCount: others.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      return ListTile(
                                                        title:
                                                            Text(others[index]),
                                                        onTap: () {
                                                          Navigator.pop(context,
                                                              others[index]);
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  ).then((result) {
                                    if (result == null) return;
                                    if (result.isEmpty) return;
                                    DataHelper()
                                        .moveAudioToPlayList(song, result);
                                    player.removeFile(index);

                                    showMsgBySnack(
                                        "已移动${song.title}到歌单$result");
                                  });
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'detail',
                                child: Text('详细信息'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                child: Text('移除文件'),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('修改别名'),
                              ),
                              PopupMenuItem(
                                value: 'copyto',
                                child: Text('复制到歌单'),
                              ),
                              PopupMenuItem(
                                value: 'moveto',
                                child: Text('移动到歌单'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () {
                        player.playAtIndex(index);
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildPlayerControls(),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(
      BuildContext context, int index, AudioFile audioFile) async {
    TextEditingController controller = TextEditingController();
    controller.text = audioFile.title;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('修改名称'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '请输入新名称',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            // 取消按钮
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('取消'),
            ),
            // 确定按钮
            TextButton(
              onPressed: () {
                // 这里处理确定逻辑
                setState(() {
                  String newName = controller.text.trim();
                  if (newName.isNotEmpty) {
                    DataHelper dh = DataHelper();

                    dh.setPlayListSongTitle(audioFile.path, controller.text);
                    context
                        .read<PlaybackProvider>()
                        .setAudioName(index, controller.text);
                  }
                });
                Navigator.of(context).pop();
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void _showAudioDetail(AudioFile audioFile) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: Center(
              child: Text("详情"),
            ),
            titlePadding: EdgeInsets.fromLTRB(0, 8, 0, 0),
            contentPadding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      "标题:",
                      style: TextStyle(color: Colors.grey[188], fontSize: 12),
                    ),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                      child: SelectableText(audioFile.title,
                          maxLines: null,
                          style: TextStyle(fontWeight: FontWeight.bold)))
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text("文件路径:",
                        style:
                            TextStyle(color: Colors.grey[188], fontSize: 12)),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                      child: SelectableText(audioFile.path,
                          maxLines: null,
                          style: TextStyle(fontWeight: FontWeight.bold)))
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text("艺术家:",
                        style:
                            TextStyle(color: Colors.grey[188], fontSize: 12)),
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                      child: SelectableText(
                    audioFile.artist,
                    maxLines: null,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ))
                ],
              ),
              if (audioFile.ablum.isNotEmpty)
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text("专辑:",
                          style:
                              TextStyle(color: Colors.grey[188], fontSize: 12)),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Expanded(
                        child: SelectableText(
                      audioFile.ablum,
                      maxLines: null,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ))
                  ],
                ),
              const SizedBox(
                height: 20,
              ),
              Center(
                child: SizedBox(
                  width: 180,
                  child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text("关闭")),
                ),
              )
            ],
          );
        });
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void _toggleVolumePopup(PlaybackProvider player) {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => VolumePopupContent(
        buttonKey: _buttonKey,
        currentVolume: player.volume,
        onVolumeChanged: (val) {
          player.setVolume(val);
        },
        onClose: _removeOverlay,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  String formatPlayModeName(PlaybackProvider player) {
    switch (player.playbackMode) {
      case PlaybackMode.sequential:
        return "顺序播放";

      case PlaybackMode.random:
        return "随机播放";

      case PlaybackMode.single:
        return "单曲循环";
    }
  }

  Widget _buildPlayerControls() {
    return Consumer<PlaybackProvider>(
      builder: (context, player, child) {
        if (player.playlist.isEmpty) {
          return SizedBox.shrink();
        }

        return Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                // ignore: deprecated_member_use
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              if (player.currentSong != null)
                Row(
                  children: [
                    Text(
                      playListName,
                      style: TextStyle(color: Colors.teal),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text(
                      player.currentSong!.title,
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis),
                    )),
                    Text(
                      player.currentSong!.artist,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(width: 8)
                  ],
                ),
              // 进度条
              Row(
                children: [
                  Text(
                    _formatDuration(player.currentPosition),
                    style: TextStyle(fontSize: 12),
                  ),
                  Expanded(
                    child: Slider(
                      value: player.totalDuration.inMilliseconds > 0
                          ? Utils.safePercent(
                              player.currentPosition.inMilliseconds,
                              player.totalDuration.inMilliseconds)
                          : 0,
                      onChanged: (value) {
                        final position = Duration(
                          milliseconds:
                              (value * player.totalDuration.inMilliseconds)
                                  .toInt(),
                        );
                        player.seek(position);
                      },
                    ),
                  ),
                  Text(
                    _formatDuration(player.totalDuration),
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              // 控制按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          onPressed: () {
                            if (player.playbackMode ==
                                PlaybackMode.sequential) {
                              player.setPlaybackMode(PlaybackMode.random);
                            } else if (player.playbackMode ==
                                PlaybackMode.random) {
                              player.setPlaybackMode(PlaybackMode.single);
                            } else {
                              player.setPlaybackMode(PlaybackMode.sequential);
                            }
                          },
                          icon: Icon(
                            player.playbackMode == PlaybackMode.random
                                ? Icons.shuffle
                                : player.playbackMode == PlaybackMode.single
                                    ? Icons.repeat_one
                                    : Icons.repeat,
                          )),
                      Text(formatPlayModeName(player),
                          style:
                              TextStyle(fontSize: 10, color: Colors.deepPurple))
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_previous, size: 36),
                    onPressed: player.previous,
                  ),
                  IconButton(
                    icon: Icon(
                      player.isPlaying ? Icons.pause_circle : Icons.play_circle,
                      size: 56,
                      color: Colors.blue,
                    ),
                    onPressed: player.playPause,
                  ),
                  IconButton(
                    icon: Icon(Icons.skip_next, size: 36),
                    onPressed: player.next,
                  ),
                  IconButton(
                    key: _buttonKey,
                    icon: Icon(Icons.volume_up_rounded),
                    onPressed: () {
                      _toggleVolumePopup(player);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$minutes:$seconds";
  }
}
