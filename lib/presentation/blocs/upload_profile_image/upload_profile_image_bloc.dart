import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/profile_usecases.dart';

// Events
abstract class UploadProfileImageEvent extends Equatable {
  const UploadProfileImageEvent();
  @override
  List<Object?> get props => [];
}

class UploadImageRequested extends UploadProfileImageEvent {
  final String uid;
  final String filePath;
  const UploadImageRequested({required this.uid, required this.filePath});
  @override
  List<Object?> get props => [uid, filePath];
}

class RemoveImageRequested extends UploadProfileImageEvent {
  final String uid;
  const RemoveImageRequested(this.uid);
  @override
  List<Object?> get props => [uid];
}

// States
abstract class UploadProfileImageState extends Equatable {
  const UploadProfileImageState();
  @override
  List<Object?> get props => [];
}

class UploadImageInitial extends UploadProfileImageState {}

class UploadImageLoading extends UploadProfileImageState {}

class UploadImageSuccess extends UploadProfileImageState {
  final String downloadUrl;
  const UploadImageSuccess(this.downloadUrl);
  @override
  List<Object?> get props => [downloadUrl];
}

class RemoveImageSuccess extends UploadProfileImageState {}

class UploadImageFailure extends UploadProfileImageState {
  final String error;
  const UploadImageFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class UploadProfileImageBloc extends Bloc<UploadProfileImageEvent, UploadProfileImageState> {
  final UploadProfilePictureUseCase _uploadProfilePictureUseCase;
  final RemoveProfilePictureUseCase _removeProfilePictureUseCase;

  UploadProfileImageBloc({
    required UploadProfilePictureUseCase uploadProfilePictureUseCase,
    required RemoveProfilePictureUseCase removeProfilePictureUseCase,
  })  : _uploadProfilePictureUseCase = uploadProfilePictureUseCase,
        _removeProfilePictureUseCase = removeProfilePictureUseCase,
        super(UploadImageInitial()) {
    on<UploadImageRequested>(_onUploadImageRequested);
    on<RemoveImageRequested>(_onRemoveImageRequested);
  }

  Future<void> _onUploadImageRequested(
    UploadImageRequested event,
    Emitter<UploadProfileImageState> emit,
  ) async {
    emit(UploadImageLoading());
    try {
      final url = await _uploadProfilePictureUseCase(event.uid, event.filePath);
      emit(UploadImageSuccess(url));
    } catch (e) {
      emit(UploadImageFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onRemoveImageRequested(
    RemoveImageRequested event,
    Emitter<UploadProfileImageState> emit,
  ) async {
    emit(UploadImageLoading());
    try {
      await _removeProfilePictureUseCase(event.uid);
      emit(RemoveImageSuccess());
    } catch (e) {
      emit(UploadImageFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
