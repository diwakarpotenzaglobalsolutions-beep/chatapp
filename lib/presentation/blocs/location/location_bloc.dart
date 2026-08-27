import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/location_service.dart';

// Events
abstract class LocationEvent extends Equatable {
  const LocationEvent();
  @override
  List<Object?> get props => [];
}

class FetchCurrentLocationRequested extends LocationEvent {}

class OpenMapRequested extends LocationEvent {
  final double latitude;
  final double longitude;
  const OpenMapRequested({required this.latitude, required this.longitude});
  @override
  List<Object?> get props => [latitude, longitude];
}

// States
abstract class LocationState extends Equatable {
  const LocationState();
  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationLoading extends LocationState {}

class LocationSuccess extends LocationState {
  final double latitude;
  final double longitude;
  const LocationSuccess({required this.latitude, required this.longitude});
  @override
  List<Object?> get props => [latitude, longitude];
}

class LocationFailure extends LocationState {
  final String error;
  const LocationFailure(this.error);
  @override
  List<Object?> get props => [error];
}

// Bloc
class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationService _locationService;

  LocationBloc({required this._locationService})
      : super(LocationInitial()) {
    on<FetchCurrentLocationRequested>(_onFetchLocation);
    on<OpenMapRequested>(_onOpenMap);
  }

  Future<void> _onFetchLocation(
    FetchCurrentLocationRequested event,
    Emitter<LocationState> emit,
  ) async {
    emit(LocationLoading());
    try {
      final pos = await _locationService.getCurrentLocation();
      emit(LocationSuccess(latitude: pos.latitude, longitude: pos.longitude));
    } catch (e) {
      emit(LocationFailure(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> _onOpenMap(OpenMapRequested event, Emitter<LocationState> emit) async {
    try {
      await _locationService.openInGoogleMaps(event.latitude, event.longitude);
    } catch (_) {}
  }
}
