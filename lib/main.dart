import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:localmusic/utils/data_helper.dart';
import 'package:localstorage/localstorage.dart';
import 'package:provider/provider.dart';
import 'page/player_home.dart';
import 'services/audio_handler.dart';
import 'services/music_player_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initLocalStorage();
  await DataHelper().initDataHelper();

  final session = await AudioSession.instance;
  await session.configure(AudioSessionConfiguration.music());

  // 初始化 AudioService
  final audioHandler = await AudioService.init(
    builder: () => MyAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelId: 'com.laoha.localplayer',
      androidNotificationChannelName: '音乐播放',
      androidShowNotificationBadge: true,
      androidNotificationOngoing: true, // 通知是持续的
      androidStopForegroundOnPause: true, // ⚠️ 必须设置为 true // 暂停时是否移除通知
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<MyAudioHandler>.value(value: audioHandler),
        ChangeNotifierProvider(
          create: (context) => PlaybackProvider(audioHandler),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: '本地音乐播放器',
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        home: const MusicPlayerHome(),
        debugShowCheckedModeBanner: false);
  }
}

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Consumer<PlaybackProvider>(
//       builder: (context, provider, child) {
//         return MaterialApp(
//           title: '本地音乐播放器',
//           theme: ThemeData(
//             primarySwatch: Colors.green,
//             useMaterial3: true,
//           ),
//           home: MusicPlayerHome(),
//           debugShowCheckedModeBanner: false,
//         );
//       },
//     );
//   }
// }
