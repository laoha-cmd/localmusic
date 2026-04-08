import 'package:flutter/material.dart';
import 'package:localmusic/utils/data_helper.dart';
import 'package:provider/provider.dart';

import '../services/music_player_service.dart';
import '../ui/wavebar_animation.dart';
import '../utils/utils.dart';

class PlayListPage extends StatefulWidget {
  const PlayListPage({super.key});

  @override
  State<PlayListPage> createState() => _PlayListPageState();
}

class _PlayListPageState extends State<PlayListPage> {
  DataHelper helper = DataHelper();
  int currentIndex = -1;
  String currentPlay = "";

  List<String> playList = [];

  @override
  void initState() {
    currentPlay = helper.selectedName;
    playList.addAll(helper.getPlayLists());

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('歌单管理'),
          centerTitle: true,
          elevation: 2,
          actions: [
            TextButton.icon(
                icon: Icon(Icons.add),
                onPressed: () {
                  _showNewPlayListDialog(context);
                },
                label: Text("新增歌单"))
          ],
        ),
        body: ListView.builder(
            itemCount: playList.length,
            itemBuilder: (context, index) {
              final item = playList[index];
              DataHelper dh = DataHelper();
              final songs = dh.getPlayListSongs(item);

              return ListTile(
                leading: Icon(Icons.queue_music_sharp),
                title: Text(
                  item,
                  textAlign: TextAlign.center,
                ),
                subtitle:
                    Text("歌曲数:${songs.length}", textAlign: TextAlign.center),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (currentPlay == item)
                      WaveBarAnimation()
                    else
                      IconButton(
                          onPressed: () {
                            final service = context.read<PlaybackProvider>();
                            service.changePlayList();
                            helper.setSelectPlayListName(item);
                            Navigator.of(context).pop();
                          },
                          icon: Icon(Icons.play_circle_fill_sharp)),
                    PopupMenuButton<String>(
                      tooltip: "更多",
                      icon: Icon(Icons.more_vert, size: 20),
                      onSelected: (value) {
                        switch (value) {
                          case "modify":
                            _showEditNameDialog(context, index, item);
                            break;

                          case "delete":
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('删除歌单'),
                                content: Text('确定要删除歌单 "$item" 吗？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      final oldSelect = helper.selectedName;
                                      helper.removePlayList(item);
                                      Utils.logout(
                                          "helper.selectedName:${helper.selectedName},current item:$item");
                                      if (oldSelect == item) {
                                        final service =
                                            context.read<PlaybackProvider>();
                                        service.clearPlaylist();
                                      }
                                      setState(() {
                                        playList.removeAt(index);
                                        if (item == currentPlay) {
                                          currentPlay = "";
                                        }
                                      });
                                      Navigator.pop(context);
                                    },
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.red),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'modify',
                          child: Text('修改名称'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('删除歌单'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }));
  }

  Future<void> _showNewPlayListDialog(BuildContext context) {
    TextEditingController controller = TextEditingController();

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('新增歌单'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '请输入名称',
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
                String newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  if (!helper.addPlayList(newName)) {
                    showMsgBySnack("歌单已经存在，换个名字吧!");
                    return;
                  }
                }
                setState(() {
                  playList.add(newName);
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

  Future<void> _showEditNameDialog(
      BuildContext context, int index, String oldName) async {
    TextEditingController controller = TextEditingController();
    controller.text = oldName;

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
                String newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  helper.changePlayListName(oldName, newName);

                  setState(() {
                    if (oldName == currentPlay) {
                      currentPlay = newName;
                    }
                    playList[index] = newName;
                  });
                }

                Navigator.of(context).pop();
              },
              child: Text('确定'),
            ),
          ],
        );
      },
    );
  }

  void showMsgBySnack(String content) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(content)),
    );
  }
}
