import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/services/audio_service.dart';

// Events
abstract class AudioEvent extends Equatable {
  const AudioEvent();
  @override
  List<Object?> get props => [];
}

class StartRecordingRequested extends AudioEvent {}

class StopRecordingRequested extends AudioEvent {}

class CancelRecordingRequested extends AudioEvent {}

class PlayAudioRequested extends AudioEvent {
  final String pathOrUrl;
  const PlayAudioRequested(this.pathOrUrl);
  @override
  List<Object?> get props => [pathOrUrl];
}

class PauseAudioRequested extends AudioEvent {}

class StopAudioRequested extends AudioEvent {}

class PlaybackProgressUpdated extends AudioEvent {
  final Duration position;
  final Duration duration;
  const PlaybackProgressUpdated({required this.position, required this.duration});
  @override
  List<Object?> get props => [position, duration];
}

class PlaybackStateChanged extends AudioEvent {
  final PlayerState playerState;
  const PlaybackStateChanged(this.playerState);
  @override
  List<Object?> get props => [playerState];
}

// States
abstract class AudioState extends Equatable {
  const AudioState();
  @override
  List<Object?> get props => [];
}

class AudioInitial extends AudioState {}

class AudioRecordingInProgress extends AudioState {}

class AudioRecordingSuccess extends AudioState {
  final String filePath;
  const AudioRecordingSuccess(this.filePath);
  @override
  List<Object?> get props => [filePath];
}

class AudioPlaybackInProgress extends AudioState {
  final Duration position;
  final Duration duration;
  const AudioPlaybackInProgress({required this.position, required this.duration});
  @override
  List<Object?> get props => [position, duration];
}

class AudioPlaybackPaused extends AudioState {
  final Duration position;
  final Duration duration;
  const AudioPlaybackPaused({required this.position, required this.duration});
  @override
  List<Object?> get props => [position, duration];
}

class AudioPlaybackStopped extends AudioState {}

class AudioFailure extends AudioState {
  final String error;
  const AudioFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class AudioBloc extends Bloc<AudioEvent, AudioState> {
  final AudioService _audioService;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _stateSub;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;

  AudioBloc({required AudioService audioService})
      : _audioService = audioService,
        super(AudioInitial()) {
    on<StartRecordingRequested>(_onStartRecording);
    on<StopRecordingRequested>(_onStopRecording);
    on<CancelRecordingRequested>(_onCancelRecording);
    on<PlayAudioRequested>(_onPlayAudio);
    on<PauseAudioRequested>(_onPauseAudio);
    on<StopAudioRequested>(_onStopAudio);
    on<PlaybackProgressUpdated>(_onProgressUpdated);
    on<PlaybackStateChanged>(_onPlaybackStateChanged);

    // Setup streams
    _positionSub = _audioService.positionStream.listen((pos) {
      if (pos != null) {
        _currentPosition = pos;
        add(PlaybackProgressUpdated(position: _currentPosition, duration: _currentDuration));
      }
    });

    _durationSub = _audioService.durationStream.listen((dur) {
      if (dur != null) {
        _currentDuration = dur;
        add(PlaybackProgressUpdated(position: _currentPosition, duration: _currentDuration));
      }
    });

    _stateSub = _audioService.playerStateStream.listen((state) {
      add(PlaybackStateChanged(state));
    });
  }

  Future<void> _onStartRecording(StartRecordingRequested event, Emitter<AudioState> emit) async {
    emit(AudioRecordingInProgress());
    try {
      await _audioService.startRecording();
    } catch (e) {
      emit(AudioFailure(e.toString()));
    }
  }

  Future<void> _onStopRecording(StopRecordingRequested event, Emitter<AudioState> emit) async {
    try {
      final path = await _audioService.stopRecording();
      if (path != null) {
        emit(AudioRecordingSuccess(path));
      } else {
        emit(const AudioFailure('Failed to capture audio path.'));
      }
    } catch (e) {
      emit(AudioFailure(e.toString()));
    }
  }

  Future<void> _onCancelRecording(CancelRecordingRequested event, Emitter<AudioState> emit) async {
    try {
      await _audioService.cancelRecording();
      emit(AudioInitial());
    } catch (e) {
      emit(AudioFailure(e.toString()));
    }
  }

  Future<void> _onPlayAudio(PlayAudioRequested event, Emitter<AudioState> emit) async {
    try {
      emit(const AudioPlaybackInProgress(position: Duration.zero, duration: Duration.zero));
      await _audioService.playAudio(event.pathOrUrl);
    } catch (e) {
      emit(AudioFailure(e.toString()));
    }
  }

  Future<void> _onPauseAudio(PauseAudioRequested event, Emitter<AudioState> emit) async {
    try {
      await _audioService.pauseAudio();
      emit(AudioPlaybackPaused(position: _currentPosition, duration: _currentDuration));
    } catch (e) {
      emit(AudioFailure(e.toString()));
    }
  }

  Future<void> _onStopAudio(StopAudioRequested event, Emitter<AudioState> emit) async {
    try {
      await _audioService.stopAudio();
      emit(AudioPlaybackStopped());
    } catch (e) {
      emit(AudioFailure(e.toString()));
    }
  }

  void _onProgressUpdated(PlaybackProgressUpdated event, Emitter<AudioState> emit) {
    if (state is AudioPlaybackInProgress) {
      emit(AudioPlaybackInProgress(position: event.position, duration: event.duration));
    } else if (state is AudioPlaybackPaused) {
      emit(AudioPlaybackPaused(position: event.position, duration: event.duration));
    }
  }

  void _onPlaybackStateChanged(PlaybackStateChanged event, Emitter<AudioState> emit) {
    if (event.playerState.processingState == ProcessingState.completed) {
      emit(AudioPlaybackStopped());
    }
  }

  @override
  Future<void> close() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    return super.close();
  }
}
