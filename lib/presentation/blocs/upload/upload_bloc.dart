import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/storage_service.dart';

// Events
abstract class UploadEvent extends Equatable {
  const UploadEvent();
  @override
  List<Object?> get props => [];
}

class UploadFileRequested extends UploadEvent {
  final String filePath;
  final String folder;
  const UploadFileRequested({required this.filePath, required this.folder});
  @override
  List<Object?> get props => [filePath, folder];
}

class UploadProgressUpdated extends UploadEvent {
  final double progress;
  const UploadProgressUpdated(this.progress);
  @override
  List<Object?> get props => [progress];
}

// States
abstract class UploadState extends Equatable {
  const UploadState();
  @override
  List<Object?> get props => [];
}

class UploadInitial extends UploadState {}

class UploadProgress extends UploadState {
  final double progress;
  const UploadProgress(this.progress);
  @override
  List<Object?> get props => [progress];
}

class UploadSuccess extends UploadState {
  final String downloadUrl;
  const UploadSuccess(this.downloadUrl);
  @override
  List<Object?> get props => [downloadUrl];
}

class UploadFailure extends UploadState {
  final String error;
  const UploadFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class UploadBloc extends Bloc<UploadEvent, UploadState> {
  final StorageService _storageService;

  UploadBloc({required StorageService storageService})
      : _storageService = storageService,
        super(UploadInitial()) {
    on<UploadFileRequested>(_onUploadFileRequested);
    on<UploadProgressUpdated>(_onUploadProgressUpdated);
  }

  Future<void> _onUploadFileRequested(UploadFileRequested event, Emitter<UploadState> emit) async {
    emit(const UploadProgress(0.0));
    try {
      final downloadUrl = await _storageService.uploadFile(
        filePath: event.filePath,
        folder: event.folder,
        onProgress: (progress) {
          add(UploadProgressUpdated(progress));
        },
      );
      emit(UploadSuccess(downloadUrl));
    } catch (e) {
      emit(UploadFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  void _onUploadProgressUpdated(UploadProgressUpdated event, Emitter<UploadState> emit) {
    emit(UploadProgress(event.progress));
  }
}
