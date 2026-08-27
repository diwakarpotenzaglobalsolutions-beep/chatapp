import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../domain/usecases/auth_usecases.dart';

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class ToggleDarkMode extends SettingsEvent {
  final bool isDarkMode;
  const ToggleDarkMode(this.isDarkMode);
  @override
  List<Object?> get props => [isDarkMode];
}

class LoadSettings extends SettingsEvent {}

class LogoutRequestedSettings extends SettingsEvent {}

abstract class SettingsState extends Equatable {
  const SettingsState();
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsLoaded extends SettingsState {
  final bool isDarkMode;
  const SettingsLoaded({required this.isDarkMode});
  @override
  List<Object?> get props => [isDarkMode];
}

class SettingsLogoutSuccess extends SettingsState {}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  static const _darkModeKey = 'is_dark_mode';

  final SignOutUseCase _signOutUseCase;
  bool _isDarkMode = true;

  SettingsBloc({required SignOutUseCase signOutUseCase})
      : _signOutUseCase = signOutUseCase,
        super(SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<ToggleDarkMode>(_onToggleDarkMode);
    on<LogoutRequestedSettings>(_onLogout);
  }

  Future<void> _onLoadSettings(
    LoadSettings event,
    Emitter<SettingsState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_darkModeKey) ?? true;
    emit(SettingsLoaded(isDarkMode: _isDarkMode));
  }

  Future<void> _onToggleDarkMode(
    ToggleDarkMode event,
    Emitter<SettingsState> emit,
  ) async {
    _isDarkMode = event.isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _isDarkMode);
    emit(SettingsLoaded(isDarkMode: _isDarkMode));
  }

  Future<void> _onLogout(
    LogoutRequestedSettings event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _signOutUseCase();
      emit(SettingsLogoutSuccess());
    } catch (_) {}
  }
}
