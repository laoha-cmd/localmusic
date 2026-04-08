// lib/services/music_player_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../modles/audio_file.dart';
import '../utils/utils.dart';
import 'audio_handler.dart';

enum PlaybackMode { sequential, random, single }

class PlaybackProvider extends ChangeNotifier {
  final MyAudioHandler _audioHandler;
  final List<AudioFile> _playlist = [];
  int _currentIndex = -1;
  PlaybackMode _playbackMode = PlaybackMode.sequential;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  StreamSubscription? _playbackStateSubscription;
  StreamSubscription? _mediaItemSubscription;
  StreamSubscription? _playbackEventSubscription;

  double volume = 0.7;
  // Getters
  List<AudioFile> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  PlaybackMode get playbackMode => _playbackMode;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  AudioFile? get currentSong =>
      _currentIndex >= 0 && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  PlaybackProvider(this._audioHandler) {
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _playbackStateSubscription = _audioHandler.playbackState.listen((state) {
      final wasPlaying = _isPlaying;
      final oldPosition = _currentPosition;

      _isPlaying = state.playing;
      _currentPosition = state.updatePosition;

      // 只有真正变化时才 notify
      if (wasPlaying != _isPlaying ||
          oldPosition != _currentPosition ||
          state.updatePosition.inSeconds % 5 == 0) {
        // 每5秒强制更新一次进度显示
        notifyListeners();
      }
    });

    // 监听媒体项变化（歌曲切换）
    _mediaItemSubscription = _audioHandler.mediaItem.listen((item) {
      if (item != null) {
        notifyListeners();
      }
    });

// 🔥 重要：监听播放完成事件，自动切歌
    _playbackEventSubscription = _audioHandler.playbackState.listen((state) {
      if (state.queueIndex != null && state.queueIndex == 1) {
        _onTrackComplete();
      }

      _totalDuration = state.bufferedPosition;
    });

    _audioHandler.setVolume(volume);

    _initializeCurrentState();
  }

  Future<void> _initializeCurrentState() async {
    final currentMediaItem = _audioHandler.mediaItem.value;
    if (currentMediaItem != null) {
      if (currentMediaItem.duration != null) {
        _totalDuration = currentMediaItem.duration!;
      }
    }

    final currentState = _audioHandler.playbackState.value;
    _isPlaying = currentState.playing;
    _currentPosition = currentState.updatePosition;

    notifyListeners();
  }

  // 添加音乐文件
  Future<void> addFiles(List<String> paths) async {
    for (String path in paths) {
      if (!_playlist.any((song) => song.path == path)) {
        final fData = Utils.parseFilePath(path);
        String title = path.split('/').last;
        title = fData.fileName;

        final info = await Utils.parseAudioInfo(path);

        print("$path meta: ${info.toString()}");

        String artic = "未知艺术家";
        if (info.firstArtists.isNotEmpty) {
          artic = info.firstArtists;
        } else if (info.secondArtists.isNotEmpty) {
          artic = info.secondArtists;
        }

        if (info.trackName.isNotEmpty) title = info.trackName;

        _playlist.add(AudioFile(
            path: path, title: title, artist: artic, ablum: info.album));
      }
    }

    // 如果是第一次添加文件，自动选择第一个
    if (_currentIndex == -1 && _playlist.isNotEmpty) {
      _currentIndex = 0;
    }

    notifyListeners();
  }

  Future<void> addAudioFiles(List<AudioFile> files) async {
    if (files.isEmpty) return;

    for (AudioFile item in files) {
      if (!_playlist.any((song) => song.path == item.path)) {
        _playlist.add(item);
      }
    }

    // 如果是第一次添加文件，自动选择第一个
    if (_currentIndex == -1 && _playlist.isNotEmpty) {
      _currentIndex = 0;
    }

    notifyListeners();
  }

  // 移除音乐文件
  void removeFile(int index) {
    if (index >= 0 && index < _playlist.length) {
      // 如果正在播放被移除的歌曲，停止播放
      if (index == _currentIndex) {
        stop();
      }

      _playlist.removeAt(index);

      // 调整当前索引
      if (_playlist.isEmpty) {
        _currentIndex = -1;
      } else if (index <= _currentIndex) {
        _currentIndex--;
        if (_currentIndex < 0 && _playlist.isNotEmpty) {
          _currentIndex = 0;
        }
      }

      notifyListeners();
    }
  }

  // 清空播放列表
  void clearPlaylist() {
    stop();
    _playlist.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  void changePlayList() {
    stop();
    _playlist.clear();
    _currentIndex = -1;
  }

  void setAudioName(int index, String title) {
    final oldAudio = _playlist[index];

    _playlist[index] =
        AudioFile(path: oldAudio.path, title: title, artist: oldAudio.artist);
    notifyListeners();
  }

  // 播放指定索引的歌曲
  Future<void> playAtIndex(int index) async {
    if (index >= 0 && index < _playlist.length) {
      await stop();
      _currentIndex = index;
      await _playCurrent();
    }
  }

  // 播放当前歌曲
  Future<void> _playCurrent() async {
    if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
      try {
        final song = _playlist[_currentIndex];

        // 根据不同平台处理文件路径
        String source;
        if (kIsWeb) {
          // Web平台需要特殊处理
          source = song.path;
        } else {
          // 移动端和桌面
          source = song.path.startsWith('file://')
              ? song.path
              : 'file://${song.path}';
        }

        await _audioHandler.loadAndPlay(source,
            title: song.title, ablum: song.ablum, artist: song.artist);
        _isPlaying = true;
        //_isInitialized = true;
        notifyListeners();
      } catch (e) {
        debugPrint('播放错误: $e');
      }
    }
  }

  // 播放/暂停
  Future<void> playPause() async {
    if (_playlist.isEmpty) return;

    if (_isPlaying) {
      await _audioHandler.pause();
      _isPlaying = false;
    } else {
      if (_currentIndex == -1) {
        _currentIndex = 0;
      }

      if (_currentPosition == Duration.zero ||
          _currentPosition == _totalDuration) {
        await _playCurrent();
      } else {
        await _audioHandler.resume();
        _isPlaying = true;
      }
    }
    notifyListeners();
  }

  // 停止播放
  Future<void> stop() async {
    await _audioHandler.stop();
    _isPlaying = false;
    _currentPosition = Duration.zero;
    notifyListeners();
  }

  // 下一首
  Future<void> next() async {
    if (_playlist.isEmpty) return;

    int nextIndex = _getNextIndex();
    if (nextIndex != _currentIndex) {
      await playAtIndex(nextIndex);
    } else if (_playbackMode == PlaybackMode.single) {
      // 单曲循环模式下，重新播放当前歌曲
      await seek(Duration.zero);
      await playPause();
    }
  }

  // 上一首
  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    int prevIndex = _getPreviousIndex();
    if (prevIndex != _currentIndex) {
      await playAtIndex(prevIndex);
    }
  }

  // 根据播放模式获取下一首索引
  int _getNextIndex() {
    if (_playlist.isEmpty) return -1;

    switch (_playbackMode) {
      case PlaybackMode.random:
        return _getRandomIndex();
      case PlaybackMode.sequential:
        return (_currentIndex + 1) % _playlist.length;
      case PlaybackMode.single:
        return _currentIndex;
    }
  }

  // 根据播放模式获取上一首索引
  int _getPreviousIndex() {
    if (_playlist.isEmpty) return -1;

    switch (_playbackMode) {
      case PlaybackMode.random:
        return _getRandomIndex();
      case PlaybackMode.sequential:
        return (_currentIndex - 1 + _playlist.length) % _playlist.length;
      case PlaybackMode.single:
        return _currentIndex;
    }
  }

  int _getRandomIndex() {
    if (_playlist.length == 1) return 0;
    int newIndex;
    do {
      newIndex = DateTime.now().millisecondsSinceEpoch % _playlist.length;
    } while (newIndex == _currentIndex && _playlist.length > 1);
    return newIndex;
  }

  // 歌曲播放完成处理
  void _onTrackComplete() {
    if (_playbackMode == PlaybackMode.single) {
      // 单曲循环：重新播放当前歌曲
      _playCurrent();
    } else {
      // 其他模式：播放下一首
      next();
    }
  }

  // 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }

  // 设置播放模式
  void setPlaybackMode(PlaybackMode mode) {
    _playbackMode = mode;
    notifyListeners();
  }

  Future<void> setVolume(double val) async {
    volume = val.clamp(0.0, 1.0);
    await _audioHandler.setVolume(volume);
    notifyListeners();
  }

  @override
  void dispose() {
    _playbackStateSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    _playbackEventSubscription?.cancel();

    super.dispose();
  }
}
