import 'package:get_it/get_it.dart';

// Services
import '../core/services/audio_service.dart';
import '../core/services/location_service.dart';
import '../core/services/fcm_oauth_token_cache.dart';
import '../core/services/fcm_push_service.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/permission_service.dart';
import '../core/services/media_download_service.dart';
import '../core/services/storage_service.dart';
import '../core/services/stripe_api_service.dart';
import '../core/services/zego_call_service.dart';

// Data Sources
import '../data/datasource/auth_remote_data_source.dart';
import '../data/datasource/block_remote_data_source.dart';
import '../data/datasource/block_remote_data_source_impl.dart';
import '../data/datasource/chat_remote_data_source.dart';
import '../data/datasource/call_remote_data_source.dart';
import '../data/datasource/group_remote_data_source.dart';
import '../data/datasource/profile_remote_data_source.dart';
import '../data/datasource/search_remote_data_source.dart';
import '../data/datasource/subscription_remote_data_source.dart';

// Repositories
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/block_repository_impl.dart';
import '../data/repositories/chat_repository_impl.dart';
import '../data/repositories/call_repository_impl.dart';
import '../data/repositories/group_repository_impl.dart';
import '../data/repositories/profile_repository_impl.dart';
import '../data/repositories/search_repository_impl.dart';
import '../data/repositories/subscription_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/block_repository.dart';
import '../domain/repositories/chat_repository.dart';
import '../domain/repositories/call_repository.dart';
import '../domain/repositories/group_repository.dart';
import '../domain/repositories/profile_repository.dart';
import '../domain/repositories/search_repository.dart';
import '../domain/repositories/subscription_repository.dart';

// Use Cases
import '../domain/usecases/auth_usecases.dart';
import '../domain/usecases/chat_request_usecases.dart';
import '../domain/usecases/block_usecases.dart';
import '../domain/usecases/chat_usecases.dart';
import '../domain/usecases/call_usecases.dart';
import '../domain/usecases/group_usecases.dart';
import '../domain/usecases/profile_usecases.dart';
import '../domain/usecases/search_usecases.dart';
import '../domain/usecases/subscription_usecases.dart';

// Blocs
import '../presentation/blocs/audio/audio_bloc.dart';
import '../presentation/blocs/auth/auth_bloc.dart';
import '../presentation/blocs/change_password/change_password_bloc.dart';
import '../presentation/blocs/chat/chat_bloc.dart';
import '../presentation/blocs/chat_list/chat_list_bloc.dart';
import '../presentation/blocs/chat_request/chat_request_bloc.dart';
import '../presentation/blocs/edit_profile/edit_profile_bloc.dart';
import '../presentation/blocs/forgot_password/forgot_password_bloc.dart';
import '../presentation/blocs/home/home_bloc.dart';
import '../presentation/blocs/location/location_bloc.dart';
import '../presentation/blocs/login/login_bloc.dart';
import '../presentation/blocs/connectivity/connectivity_bloc.dart';
import '../presentation/blocs/block/block_bloc.dart';
import '../presentation/blocs/message/message_bloc.dart';
import '../presentation/blocs/notification/notification_bloc.dart';
import '../presentation/blocs/presence/presence_bloc.dart';
import '../presentation/blocs/profile/profile_bloc.dart';
import '../presentation/blocs/register/register_bloc.dart';
import '../presentation/blocs/search/search_bloc.dart';
import '../presentation/blocs/group/group_bloc.dart';
import '../presentation/blocs/call/call_bloc.dart';
import '../presentation/blocs/settings/settings_bloc.dart';
import '../presentation/blocs/subscription/subscription_bloc.dart';
import '../presentation/blocs/typing/typing_bloc.dart';
import '../presentation/blocs/upload/upload_bloc.dart';
import '../presentation/blocs/upload_profile_image/upload_profile_image_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ==========================================
  // 1. Services
  // ==========================================
  sl.registerLazySingleton<AudioService>(() => AudioService());
  sl.registerLazySingleton<LocationService>(() => LocationService());
  sl.registerLazySingleton<ConnectivityService>(() => ConnectivityService());
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<FcmOAuthTokenCache>(() => FcmOAuthTokenCache());
  sl.registerLazySingleton<FcmPushService>(
    () => FcmPushService(tokenCache: sl()),
  );
  sl.registerLazySingleton<PermissionService>(() => PermissionService());
  sl.registerLazySingleton<StorageService>(() => StorageService());
  sl.registerLazySingleton<MediaDownloadService>(() => MediaDownloadService());
  sl.registerLazySingleton<StripeApiService>(() => StripeApiService());

  // ==========================================
  // 2. Data Sources
  // ==========================================
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<BlockRemoteDataSource>(
    () => BlockRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(
      fcmPushService: sl(),
      blockRemoteDataSource: sl(),
    ),
  );
  sl.registerLazySingleton<GroupRemoteDataSource>(
    () => GroupRemoteDataSourceImpl(notificationService: sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<SearchRemoteDataSource>(
    () => SearchRemoteDataSourceImpl(),
  );
  sl.registerLazySingleton<SubscriptionRemoteDataSource>(
    () => SubscriptionRemoteDataSourceImpl(stripeApi: sl()),
  );
  sl.registerLazySingleton<CallRemoteDataSource>(
    () => CallRemoteDataSourceImpl(),
  );

  // ==========================================
  // 3. Repositories
  // ==========================================
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<BlockRepository>(
    () => BlockRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<GroupRepository>(
    () => GroupRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<SearchRepository>(
    () => SearchRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<CallRepository>(
    () => CallRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton<ZegoCallService>(
    () => ZegoCallService(
      callRepository: sl(),
      permissionService: sl(),
      fcmPushService: sl(),
    ),
  );

  // ==========================================
  // 4. Use Cases
  // ==========================================
  // Auth Usecases
  sl.registerLazySingleton(() => SignUpUseCase(sl()));
  sl.registerLazySingleton(() => SignInUseCase(sl()));
  sl.registerLazySingleton(() => SignOutUseCase(sl()));
  sl.registerLazySingleton(() => ForgotPasswordUseCase(sl()));
  sl.registerLazySingleton(() => ChangePasswordUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserStreamUseCase(sl()));

  // Profile Usecases
  sl.registerLazySingleton(() => GetUserProfileUseCase(sl()));
  sl.registerLazySingleton(() => UpdateUserProfileUseCase(sl()));
  sl.registerLazySingleton(() => UploadProfilePictureUseCase(sl()));
  sl.registerLazySingleton(() => RemoveProfilePictureUseCase(sl()));

  // Chat Usecases
  sl.registerLazySingleton(() => GetChatRoomsUseCase(sl()));
  sl.registerLazySingleton(() => GetChatRoomUseCase(sl()));
  sl.registerLazySingleton(() => GetMessagesUseCase(sl()));
  sl.registerLazySingleton(() => SendMessageUseCase(sl()));
  sl.registerLazySingleton(() => UpdateMessageStatusUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTypingStatusUseCase(sl()));
  sl.registerLazySingleton(() => UpdateUserPresenceUseCase(sl()));
  sl.registerLazySingleton(() => GetOrCreateChatRoomUseCase(sl()));
  sl.registerLazySingleton(() => GetUserPresenceUseCase(sl()));
  sl.registerLazySingleton(() => GetTypingStatusUseCase(sl()));
  sl.registerLazySingleton(() => MarkMessagesAsSeenUseCase(sl()));
  sl.registerLazySingleton(() => DeleteMessageForMeUseCase(sl()));
  sl.registerLazySingleton(() => DeleteMessageForEveryoneUseCase(sl()));

  // Block Usecases
  sl.registerLazySingleton(() => BlockUserUseCase(sl()));
  sl.registerLazySingleton(() => UnblockUserUseCase(sl()));
  sl.registerLazySingleton(() => GetBlockedUsersUseCase(sl()));
  sl.registerLazySingleton(() => WatchBlockStatusUseCase(sl()));
  sl.registerLazySingleton(() => IsBlockedEitherWayUseCase(sl()));

  // Search Usecases
  sl.registerLazySingleton(() => SearchUsersUseCase(sl()));
  sl.registerLazySingleton(() => SearchMessagesUseCase(sl()));

  sl.registerLazySingleton(() => WatchSubscriptionUseCase(sl()));
  sl.registerLazySingleton(() => InitializeTrialUseCase(sl()));
  sl.registerLazySingleton(() => VerifySubscriptionUseCase(sl()));
  sl.registerLazySingleton(() => CreateSubscriptionPaymentSheetUseCase(sl()));
  sl.registerLazySingleton(() => SyncSubscriptionAfterPaymentUseCase(sl()));

  // Group Usecases
  sl.registerLazySingleton(() => CreateGroupUseCase(sl()));
  sl.registerLazySingleton(() => UpdateGroupInfoUseCase(sl()));
  sl.registerLazySingleton(() => AddGroupMembersUseCase(sl()));
  sl.registerLazySingleton(() => RemoveGroupMemberUseCase(sl()));
  sl.registerLazySingleton(() => LeaveGroupUseCase(sl()));
  sl.registerLazySingleton(() => TransferGroupAdminUseCase(sl()));
  sl.registerLazySingleton(() => SearchGroupsUseCase(sl()));

  // Call Usecases
  sl.registerLazySingleton(() => GetCallHistoryUseCase(sl()));
  sl.registerLazySingleton(() => CreateCallRecordUseCase(sl()));
  sl.registerLazySingleton(() => UpdateCallRecordStatusUseCase(sl()));
  sl.registerLazySingleton(() => IsUserInCallUseCase(sl()));
  sl.registerLazySingleton(() => SetUserCallAvailabilityUseCase(sl()));

  // ==========================================
  // 5. Blocs
  // ==========================================
  // Auth
  sl.registerFactory(() => AuthBloc(
    getCurrentUserStreamUseCase: sl(),
    getCurrentUserUseCase: sl(),
    signOutUseCase: sl(),
    updateUserPresenceUseCase: sl(),
  ));
  sl.registerFactory(() => LoginBloc(signInUseCase: sl()));
  sl.registerFactory(() => RegisterBloc(signUpUseCase: sl()));
  sl.registerFactory(() => ForgotPasswordBloc(forgotPasswordUseCase: sl()));
  sl.registerFactory(() => ChangePasswordBloc(changePasswordUseCase: sl()));

  // Profile
  sl.registerFactory(() => ProfileBloc(getUserProfileUseCase: sl()));
  sl.registerFactory(() => EditProfileBloc(
    getUserProfileUseCase: sl(),
    updateUserProfileUseCase: sl(),
  ));
  sl.registerFactory(() => UploadProfileImageBloc(
    uploadProfilePictureUseCase: sl(),
    removeProfilePictureUseCase: sl(),
  ));

  // Chat & Messages
  sl.registerFactory(() => ChatBloc(getOrCreateChatRoomUseCase: sl()));
  sl.registerFactory(() => MessageBloc(
    getMessagesUseCase: sl(),
    sendMessageUseCase: sl(),
    markMessagesAsSeenUseCase: sl(),
    deleteMessageForMeUseCase: sl(),
    deleteMessageForEveryoneUseCase: sl(),
  ));
  sl.registerFactory(() => ConnectivityBloc(connectivityService: sl()));
  sl.registerFactory(() => BlockBloc(
    blockUserUseCase: sl(),
    unblockUserUseCase: sl(),
    getBlockedUsersUseCase: sl(),
    watchBlockStatusUseCase: sl(),
  ));
  sl.registerFactory(() => ChatListBloc(getChatRoomsUseCase: sl()));
  sl.registerFactory(() => TypingBloc(
    getTypingStatusUseCase: sl(),
    updateTypingStatusUseCase: sl(),
  ));
  sl.registerFactory(() => PresenceBloc(getUserPresenceUseCase: sl()));
  sl.registerFactory(() => UploadBloc(storageService: sl()));
  sl.registerFactory(() => AudioBloc(audioService: sl()));
  sl.registerFactory(() => LocationBloc(locationService: sl()));

  // Search
  sl.registerFactory(() => SearchBloc(
    searchUsersUseCase: sl(),
    searchMessagesUseCase: sl(),
  ));
  sl.registerFactory(() => GroupBloc(
    createGroupUseCase: sl(),
    updateGroupInfoUseCase: sl(),
    addGroupMembersUseCase: sl(),
    removeGroupMemberUseCase: sl(),
    leaveGroupUseCase: sl(),
    transferGroupAdminUseCase: sl(),
    searchGroupsUseCase: sl(),
  ));
  sl.registerFactory(() => CallBloc(
    getCallHistoryUseCase: sl(),
    zegoCallService: sl(),
    isBlockedEitherWayUseCase: sl(),
  ));
  sl.registerFactory(() => SubscriptionBloc(
    watchSubscriptionUseCase: sl(),
    initializeTrialUseCase: sl(),
    verifySubscriptionUseCase: sl(),
    createPaymentSheetUseCase: sl(),
    syncAfterPaymentUseCase: sl(),
  ));

  // Settings, Notifications, Home
  sl.registerFactory(() => SettingsBloc(signOutUseCase: sl()));
  sl.registerFactory(() => NotificationBloc(notificationService: sl()));
  sl.registerFactory(() => HomeBloc(
    getCurrentUserUseCase: sl(),
    updateUserPresenceUseCase: sl(),
  ));
  // Use Cases (after chat use cases):
  sl.registerLazySingleton(() => SendChatRequestUseCase(sl()));
  sl.registerLazySingleton(() => UpdateChatRequestStatusUseCase(sl()));
  sl.registerLazySingleton(() => GetChatRequestsUseCase(sl()));
  sl.registerLazySingleton(() => GetChatRequestBetweenUsersUseCase(sl()));
  sl.registerLazySingleton(() => SetActiveChatRoomUseCase(sl()));
// Blocs:
  sl.registerFactory(() => ChatRequestBloc(
    sendChatRequestUseCase: sl(),
    updateChatRequestStatusUseCase: sl(),
    getChatRequestsUseCase: sl(),
    getChatRequestBetweenUsersUseCase: sl(),
    getOrCreateChatRoomUseCase: sl(),
  ));
}
