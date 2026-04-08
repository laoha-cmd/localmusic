// audio_handler.dart
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class MyAudioHandler extends BaseAudioHandler {
  // 使用 AudioPlayer 替代 AudioPlayer
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  // 用于跟踪当前播放进度
  Timer? _positionTimer;
  StreamSubscription? _durationSubscription;
  MyAudioHandler() {
    // 初始化时设置音频播放器配置
    _setupAudioPlayer();

    // 监听播放完成事件
    _audioPlayer.onPlayerComplete.listen((event) {
      // 播放完成时的逻辑，比如自动下一首
      debugPrint('播放完成');
      // 可以在这里触发下一首，但建议由 Provider 处理
      _updatePlaybackState(index: 1);
    });
  }

  void _setupAudioPlayer() {
    // 设置音频会话（Android）
    _audioPlayer.setReleaseMode(ReleaseMode.stop); // 播放完成后停止
    _audioPlayer
        .setPlayerMode(PlayerMode.mediaPlayer); // 使用 mediaPlayer 模式以支持后台

    // 监听播放状态变化
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _updatePlaybackState();
    });

    // 监听播放位置更新
    _audioPlayer.onPositionChanged.listen((position) {
      _position = position;
      _updatePlaybackState();
    });

    // 监听播放持续时间变化
    _audioPlayer.onDurationChanged.listen((duration) {
      _updatePlaybackState();
    });

    // 定期更新播放状态（确保通知栏进度刷新）
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_audioPlayer.state == PlayerState.playing) {
        _updatePlaybackState();
      }
    });

    // 监听总时长
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      _duration = duration;
      _updatePlaybackState();
    });
  }

  // 更新播放状态到 audio_service
  void _updatePlaybackState({int index = 0}) async {
    // 获取当前播放位置和总时长
    //final position = await _audioPlayer.getCurrentPosition();
    //final duration = await _audioPlayer.getDuration();

    playbackState.add(PlaybackState(
      controls: [],
      // systemActions: const {
      //   MediaAction.seek,
      // },
      androidCompactActionIndices: const [],
      processingState: _getProcessingState(_audioPlayer.state),
      playing: _audioPlayer.state == PlayerState.playing,
      updatePosition: _position,
      bufferedPosition: _duration, // audioplayers 不直接提供 bufferedPosition
      speed: 1.0,
      queueIndex: index,
    ));
  }

  AudioProcessingState _getProcessingState(PlayerState state) {
    switch (state) {
      case PlayerState.playing:
        return AudioProcessingState.ready;
      case PlayerState.paused:
        return AudioProcessingState.ready;
      case PlayerState.stopped:
        return AudioProcessingState.completed;
      default:
        return AudioProcessingState.idle;
    }
  }

  // 播放控制方法
  @override
  Future<void> play() async {
    await _audioPlayer.resume();
    _updatePlaybackState();
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
    _updatePlaybackState();
  }

  Future<void> resume() async {
    await _audioPlayer.resume();
    _updatePlaybackState();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();

    _updatePlaybackState();
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    _updatePlaybackState();
  }

  // 加载并播放媒体
  Future<void> loadAndPlay(String source,
      {String title = '', String artist = '', String ablum = ''}) async {
    final duration = await _audioPlayer.getDuration();
    //创建 MediaItem 供系统通知栏使用
    final item = MediaItem(
      id: source,
      title: title,
      artist: artist,
      album: ablum,
      duration: duration,
    );

    //通知系统媒体信息变更
    mediaItem.add(item);

    // 停止当前播放
    await _audioPlayer.stop();

    // 设置音频源并播放
    // 注意：audioplayers 5.0+ 使用 setSourceUrl 替代 play

    //await _audioPlayer.setSourceDeviceFile(source);
    await _audioPlayer.play(DeviceFileSource(source));
    //await _audioPlayer.resume();

    _updatePlaybackState();
  }

  Future<void> setVolume(double volume) {
    return _audioPlayer.setVolume(volume);
  }

  bool get isPlaying => _audioPlayer.state == PlayerState.playing;

  // 获取当前音频时长
  Future<Duration?> getDuration() async {
    return await _audioPlayer.getDuration();
  }

  Future<void> dispose() async {
    _positionTimer?.cancel();
    _durationSubscription!.cancel();

    await _audioPlayer.dispose();
  }
}
