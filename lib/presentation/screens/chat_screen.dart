import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
//import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/theme.dart';
import '../../core/models/pending_media_transfer.dart';
import '../../core/utils/date_time_formatter.dart';
import '../../core/services/location_service.dart';
import '../../domain/entities/block_status_entity.dart';
import '../../domain/entities/chat_request_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../injection/injection_container.dart';
import '../../routes/router.dart';
import '../blocs/audio/audio_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/chat_request/chat_request_bloc.dart';
import '../blocs/location/location_bloc.dart';
import '../blocs/block/block_bloc.dart';
import '../blocs/message/message_bloc.dart';
import '../blocs/presence/presence_bloc.dart';
import '../blocs/typing/typing_bloc.dart';
import '../blocs/search/search_bloc.dart';
import '../mixins/chat_media_transfer_mixin.dart';
import '../widgets/chat/media_transfer_widgets.dart';
import '../widgets/chat_call_buttons.dart';
import '../widgets/chat_date_separator.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/message_options_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String peerId;
  final String peerName;
  final String peerImage;

  const ChatScreen({
    super.key,
    required this.roomId,
    required this.peerId,
    required this.peerName,
    required this.peerImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with ChatMediaTransferMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Timer? _typingDebounce;
  bool _isWriting = false;
  bool _showSearch = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text, String currentUserId) {
    if (!_isWriting && text.isNotEmpty) {
      _isWriting = true;
      context.read<TypingBloc>().add(
        UpdateTypingRequest(
          roomId: widget.roomId,
          uid: currentUserId,
          isTyping: true,
        ),
      );
    } else if (_isWriting && text.isEmpty) {
      _isWriting = false;
      context.read<TypingBloc>().add(
        UpdateTypingRequest(
          roomId: widget.roomId,
          uid: currentUserId,
          isTyping: false,
        ),
      );
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      if (_isWriting) {
        _isWriting = false;
        context.read<TypingBloc>().add(
          UpdateTypingRequest(
            roomId: widget.roomId,
            uid: currentUserId,
            isTyping: false,
          ),
        );
      }
    });
  }

  void _sendMessage(
      String text,
      MessageType type,
      String currentUserId, {
        String? mediaUrl,
        Duration? duration,
        double? lat,
        double? lng,
        String? fileName,
        String? fileSize,
        String? messageId,
      }) {
    if (!ensureOnlineOrNotify(context)) return;
    if (text.trim().isEmpty && mediaUrl == null) return;

    final reqState = context.read<ChatRequestBloc>().state;
    final blockState = context.read<BlockBloc>().state;
    final blockStatus = blockState is BlockStatusState
        ? blockState.status
        : const BlockStatusEntity();
    if (!_canSendMessages(reqState, blockStatus)) return;

    final message = MessageEntity(
      messageId: messageId ?? _uuid.v4(),
      senderId: currentUserId,
      receiverId: widget.peerId,
      content: text,
      type: type,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
      mediaUrl: mediaUrl,
      duration: duration,
      latitude: lat,
      longitude: lng,
      fileName: fileName,
      fileSize: fileSize,
    );

    context.read<MessageBloc>().add(
      SendMessageRequested(
        roomId: widget.roomId,
        message: message,
      ),
    );

    _messageController.clear();
    if (_isWriting) {
      _isWriting = false;
      context.read<TypingBloc>().add(
        UpdateTypingRequest(
          roomId: widget.roomId,
          uid: currentUserId,
          isTyping: false,
        ),
      );
    }

    Timer(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(String currentUserId) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _uploadAndSendFile(pickedFile.path, MessageType.image, currentUserId);
    }
  }

  Future<void> _captureImage(String currentUserId) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      _uploadAndSendFile(pickedFile.path, MessageType.image, currentUserId);
    }
  }

  Future<void> _pickVideo(String currentUserId) async {
    final pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      _uploadAndSendFile(pickedFile.path, MessageType.video, currentUserId);
    }
  }

  void _uploadAndSendFile(
      String path,
      MessageType type,
      String currentUserId, {
        String? customFileName,
        String? fileSize,
      }) {
    uploadMediaFile(
      path: path,
      type: type,
      customFileName: customFileName,
      fileSize: fileSize,
      onSuccess: ({required messageId, required mediaUrl, fileName, fileSize}) {
        _sendMessage(
          customFileName ?? p.basename(path),
          type,
          currentUserId,
          mediaUrl: mediaUrl,
          fileName: fileName ?? customFileName ?? p.basename(path),
          fileSize: fileSize,
          messageId: messageId,
        );
      },
    );
  }

  void _sendLocation(String currentUserId) {
    context.read<LocationBloc>().add(FetchCurrentLocationRequested());

    late StreamSubscription locationSubscription;
    locationSubscription = context.read<LocationBloc>().stream.listen((state) {
      if (state is LocationSuccess) {
        _sendMessage(
          'Location shared',
          MessageType.location,
          currentUserId,
          lat: state.latitude,
          lng: state.longitude,
        );
        locationSubscription.cancel();
      } else if (state is LocationFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share location: ${state.error}'),
            backgroundColor: AppColors.error,
          ),
        );
        locationSubscription.cancel();
      }
    });
  }
  Future<void> _pickDocument(String currentUserId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'zip', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      _uploadAndSendFile(
        file.path!,
        MessageType.file,
        currentUserId,
        customFileName: file.name,
        fileSize: '${(file.size / 1024).toStringAsFixed(1)} KB',
      );
    }
  }

  void _showAttachmentOptions(BuildContext context, String currentUserId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AttachmentItem(
                  icon: Icons.image_rounded,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(currentUserId);
                  },
                ),
                _AttachmentItem(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: Colors.pink,
                  onTap: () {
                    Navigator.pop(context);
                    _captureImage(currentUserId);
                  },
                ),
                _AttachmentItem(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo(currentUserId);
                  },
                ),
                _AttachmentItem(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Document',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument(currentUserId);
                  },
                ),
                _AttachmentItem(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _sendLocation(currentUserId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.uid : '';

    return BlocListener<BlockBloc, BlockState>(
      listener: (context, state) {
        if (state is BlockStatusState) {
          if (state.actionMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.actionMessage!)),
            );
            context.read<BlockBloc>().add(ClearBlockFeedback());
          } else if (state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: AppColors.error,
              ),
            );
            context.read<BlockBloc>().add(ClearBlockFeedback());
          }
        }
      },
      child: BlocListener<MessageBloc, MessageState>(
        listener: (context, state) {
          if (state is MessageFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: Scaffold(
          appBar: _buildAppBar(context),
          body: Container(
            decoration: BoxDecoration(gradient: context.scaffoldGradient),
            child: BlocBuilder<BlockBloc, BlockState>(
              builder: (context, blockState) {
                final blockStatus = blockState is BlockStatusState
                    ? blockState.status
                    : const BlockStatusEntity();
                return BlocBuilder<ChatRequestBloc, ChatRequestState>(
                  builder: (context, requestState) {
                    final canSend = _canSendMessages(requestState, blockStatus);
                    return Column(
                      children: [
                        _buildRequestBanner(requestState),
                        _buildBlockBanner(blockStatus),

                        if (_showSearch)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (q) {
                                context.read<SearchBloc>().add(
                                      SearchMessagesRequested(roomId: widget.roomId, query: q),
                                    );
                              },
                              decoration: const InputDecoration(
                                hintText: 'Search messages in this chat...',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                          ),
                        if (_showSearch)
                          BlocBuilder<SearchBloc, SearchState>(
                            builder: (context, state) {
                              if (state is SearchMessagesSuccess && state.messages.isNotEmpty) {
                                return SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    itemCount: state.messages.length,
                                    itemBuilder: (_, i) {
                                      final msg = state.messages[i];
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          msg.content.isNotEmpty ? msg.content : (msg.fileName ?? 'Media'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          DateTimeFormatter.formatMessageTime(msg.timestamp),
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),

                        Expanded(
                          child: BlocBuilder<MessageBloc, MessageState>(
                            builder: (context, state) {
                              if (state is MessageLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                );
                              }
                              if (state is MessagesLoaded) {
                                final messages = state.messages;
                                if (messages.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'Say hello to ${widget.peerName} 👋',
                                      style: const TextStyle(color: AppColors.textMuted),
                                    ),
                                  );
                                }

                                Timer(const Duration(milliseconds: 100), () {
                                  if (_scrollController.hasClients) {
                                    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                                  }
                                });

                                return ListView(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  children: _buildMessageList(messages, currentUserId),
                                );
                              }
                              if (state is MessageFailure) {
                                return Center(child: Text('Error loading messages: ${state.error}'));
                              }
                              return Container();
                            },
                          ),
                        ),

                        _buildTypingIndicatorPanel(),

                        if (canSend && !_showSearch)
                          _buildInputBar(context, currentUserId)
                        else if (!canSend)
                          _buildDisabledInputBar(blockStatus),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMessageList(List<MessageEntity> messages, String currentUserId) {
    final items = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      if (DateTimeFormatter.shouldShowDateSeparator(
        items: messages,
        index: i,
        timestampOf: (m) => m.timestamp,
      )) {
        items.add(ChatDateSeparator(date: messages[i].timestamp));
      }
      items.add(
        _MessageBubble(
          message: messages[i],
          isMe: messages[i].senderId == currentUserId,
          peerName: widget.peerName,
          roomId: widget.roomId,
          currentUserId: currentUserId,
          transfer: pendingTransfers[messages[i].messageId],
          onRetryDownload: () => retryDownload(messages[i]),
          onMediaTap: () => handleMediaTap(messages[i]),
        ),
      );
    }

    for (final upload in pendingUploads) {
      items.add(
        PendingUploadBubble(
          transfer: upload,
          onRetry: () => retryUpload(
            messageId: upload.messageId,
            onSuccess: ({required messageId, required mediaUrl, fileName, fileSize}) {
              _sendMessage(
                fileName ?? upload.fileName ?? 'Media',
                upload.type,
                currentUserId,
                mediaUrl: mediaUrl,
                fileName: fileName ?? upload.fileName,
                fileSize: fileSize ?? upload.fileSize,
                messageId: messageId,
              );
            },
          ),
        ),
      );
    }

    return items;
  }

  bool _canSendMessages(ChatRequestState? state, BlockStatusEntity blockStatus) {
    if (blockStatus.isBlockedEitherWay) return false;
    if (state is BetweenUsersRequestLoaded) {
      return state.request?.status == ChatRequestStatus.accepted;
    }
    return false;
  }

  Widget _buildBlockBanner(BlockStatusEntity blockStatus) {
    if (!blockStatus.isBlockedEitherWay) return const SizedBox.shrink();
    if (blockStatus.blockedByMe) {
      return _banner('You blocked this user. Unblock to send messages.', AppColors.error);
    }
    return _banner('You cannot message this user.', AppColors.error);
  }

  Widget _buildRequestBanner(ChatRequestState? state) {
    if (state is! BetweenUsersRequestLoaded) return const SizedBox.shrink();
    final request = state.request;
    if (request == null) {
      return _banner('You need to send a chat request first.', Colors.orange);
    }
    switch (request.status) {
      case ChatRequestStatus.pending:
        return _banner('Chat request is pending. Messaging is disabled.', Colors.orange);
      case ChatRequestStatus.rejected:
        return _banner('Chat request was rejected.', AppColors.error);
      case ChatRequestStatus.accepted:
        return const SizedBox.shrink();
    }
  }

  Widget _banner(String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color.withOpacity(0.15),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildDisabledInputBar([BlockStatusEntity? blockStatus]) {
    final blocked = blockStatus?.isBlockedEitherWay ?? false;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Icon(
                blocked ? Icons.block : Icons.lock_outline,
                color: AppColors.textMuted,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                blocked ? 'Communication is blocked' : 'Messaging unavailable',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: BlocBuilder<BlockBloc, BlockState>(
        builder: (context, blockState) {
          final isBlocked = blockState is BlockStatusState &&
              blockState.status.isBlockedEitherWay;

          if (isBlocked) {
            return Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceLight,
                  backgroundImage: widget.peerImage.isNotEmpty
                      ? CachedNetworkImageProvider(widget.peerImage)
                      : null,
                  child: widget.peerImage.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.peerName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Unavailable',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return BlocBuilder<PresenceBloc, PresenceState>(
            builder: (context, state) {
              String statusText = 'Offline';
              bool isOnline = false;

              if (state is PresenceLoaded) {
                statusText = 'Online';
                isOnline = true;
              } else if (state is PresenceOffline) {
                statusText = DateTimeFormatter.formatLastSeen(state.lastSeen);
              }

              return Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.surfaceLight,
                    backgroundImage: widget.peerImage.isNotEmpty
                        ? CachedNetworkImageProvider(widget.peerImage)
                        : null,
                    child: widget.peerImage.isEmpty
                        ? const Icon(Icons.person, color: Colors.white, size: 20)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.peerName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            if (isOnline)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 10,
                                color: isOnline ? AppColors.success : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      actions: [
        BlocBuilder<BlockBloc, BlockState>(
          builder: (context, blockState) {
            return BlocBuilder<ChatRequestBloc, ChatRequestState>(
              builder: (context, requestState) {
                final authState = context.read<AuthBloc>().state;
                final currentUserId = authState is Authenticated ? authState.user.uid : '';
                final currentUserName = authState is Authenticated ? authState.user.fullName : '';
                final currentUserImage = authState is Authenticated ? authState.user.profilePicture : '';
                final blockStatus = blockState is BlockStatusState
                    ? blockState.status
                    : const BlockStatusEntity();
                final canCall = _canSendMessages(requestState, blockStatus);

                return ChatCallButtons(
                  enabled: canCall && currentUserId.isNotEmpty,
                  callerId: currentUserId,
                  callerName: currentUserName,
                  callerImage: currentUserImage,
                  calleeId: widget.peerId,
                  calleeName: widget.peerName,
                  calleeImage: widget.peerImage,
                  chatRoomId: widget.roomId,
                );
              },
            );
          },
        ),
        BlocBuilder<BlockBloc, BlockState>(
          builder: (context, blockState) {
            final blockStatus = blockState is BlockStatusState
                ? blockState.status
                : const BlockStatusEntity();
            final authState = context.read<AuthBloc>().state;
            final currentUserId = authState is Authenticated ? authState.user.uid : '';

            return PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'block') {
                  final confirmed = await confirmBlockUser(context, widget.peerName);
                  if (confirmed && context.mounted) {
                    context.read<BlockBloc>().add(
                          BlockUserRequested(
                            blockerId: currentUserId,
                            blockedUserId: widget.peerId,
                            blockedUserName: widget.peerName,
                            blockedUserImage: widget.peerImage,
                          ),
                        );
                  }
                } else if (value == 'unblock') {
                  final confirmed = await confirmUnblockUser(context, widget.peerName);
                  if (confirmed && context.mounted) {
                    context.read<BlockBloc>().add(
                          UnblockUserRequested(
                            blockerId: currentUserId,
                            blockedUserId: widget.peerId,
                          ),
                        );
                  }
                }
                else if(value=="search"){
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      context.read<SearchBloc>().add(ClearSearchRequested());
                    }
                  });
                }
              },
              itemBuilder: (context) => [
                if (blockStatus.blockedByMe)
                  const PopupMenuItem(
                    value: 'unblock',
                    child: Text('Unblock user'),
                  )
                else
                  const PopupMenuItem(
                    value: 'block',
                    child: Text('Block user'),
                  ),
                PopupMenuItem(
                  value: "search",
                  child: Text("Search Message"),
                )
              ],
            );
          },
        ),
        IconButton(
          icon: Icon(CupertinoIcons.profile_circled),
          onPressed: () => context.push('${AppRoutes.profile}/${widget.peerId}'),
        ),
      ],
    );
  }

  Widget _buildTypingIndicatorPanel() {
    return BlocBuilder<TypingBloc, TypingState>(
      builder: (context, state) {
        if (state is TypingUpdated) {
          final isPeerTyping = state.typingMap[widget.peerId] ?? false;
          if (isPeerTyping) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.peerName} is typing',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildInputBar(BuildContext context, String currentUserId) {
    return BlocBuilder<AudioBloc, AudioState>(
      builder: (context, audioState) {
        final isRecording = audioState is AudioRecordingInProgress;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0x1AFFFFFF)),
                    ),
                    child: Row(
                      children: [
                        if (!isRecording)
                          IconButton(
                            icon: const Icon(Icons.attach_file_rounded, color: AppColors.textSecondary),
                            onPressed: () => _showAttachmentOptions(context, currentUserId),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: isRecording
                                ? const _VoiceRecordingPanel()
                                : TextFormField(
                              controller: _messageController,
                              onChanged: (text) => _onTextChanged(text, currentUserId),
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        if (!isRecording)
                          IconButton(
                            icon: const Icon(Icons.mic_none_rounded, color: AppColors.textSecondary),
                            onPressed: () {
                              context.read<AudioBloc>().add(StartRecordingRequested());
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    if (isRecording) {
                      context.read<AudioBloc>().add(StopRecordingRequested());

                      late StreamSubscription audioSub;
                      audioSub = context.read<AudioBloc>().stream.listen((state) {
                        if (state is AudioRecordingSuccess) {
                          _uploadAndSendFile(
                            state.filePath,
                            MessageType.voice,
                            currentUserId,
                          );
                          audioSub.cancel();
                        }
                      });
                    } else {
                      _sendMessage(_messageController.text, MessageType.text, currentUserId);
                    }
                  },
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      isRecording ? Icons.stop_rounded : Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _VoiceRecordingPanel extends StatefulWidget {
  const _VoiceRecordingPanel();

  @override
  State<_VoiceRecordingPanel> createState() => _VoiceRecordingPanelState();
}

class _VoiceRecordingPanelState extends State<_VoiceRecordingPanel> {
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mins = _seconds ~/ 60;
    final secs = _seconds % 60;
    final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Row(
      children: [
        const Icon(Icons.fiber_manual_record, color: AppColors.error, size: 14),
        const SizedBox(width: 8),
        Text('Recording... $timeStr', style: const TextStyle(color: AppColors.textPrimary)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          onPressed: () {
            context.read<AudioBloc>().add(CancelRecordingRequested());
          },
        ),
      ],
    );
  }
}

class _AttachmentItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String peerName;
  final String roomId;
  final String currentUserId;
  final PendingMediaTransfer? transfer;
  final VoidCallback? onRetryDownload;
  final VoidCallback? onMediaTap;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.peerName,
    required this.roomId,
    required this.currentUserId,
    this.transfer,
    this.onRetryDownload,
    this.onMediaTap,
  });

  void _showDeleteOptions(BuildContext context) {
    showMessageOptionsSheet(
      context: context,
      message: message,
      isMe: isMe,
      onDeleteForMe: () {
        context.read<MessageBloc>().add(
              DeleteMessageForMeRequested(
                roomId: roomId,
                messageId: message.messageId,
                userId: currentUserId,
              ),
            );
      },
      onDeleteForEveryone: isMe
          ? () {
              context.read<MessageBloc>().add(
                    DeleteMessageForEveryoneRequested(
                      roomId: roomId,
                      messageId: message.messageId,
                      senderId: currentUserId,
                    ),
                  );
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMe ? AppColors.primary : AppColors.surface;
    final textStyle = TextStyle(
      color: isMe ? Colors.white : AppColors.textPrimary,
      fontSize: 15,
    );
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
    );

    return Column(
      crossAxisAlignment: alignment,
      children: [
        GestureDetector(
          onLongPress: () => _showDeleteOptions(context),
          child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: borderRadius,
            border: Border.all(color: const Color(0x1AFFFFFF), width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMessageContent(context, textStyle),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    DateTimeFormatter.formatMessageTime(message.timestamp),
                    style: TextStyle(color:  AppColors.lightBackground, fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    _buildReceiptTick(message.status),
                  ],
                ],
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildMessageContent(BuildContext context, TextStyle defaultStyle) {
    if (message.showsDeletedPlaceholder) {
      return Text(
        MessageEntity.deletedPlaceholder,
        style: defaultStyle.copyWith(
          fontStyle: FontStyle.italic,
          color: isMe ? Colors.white70 : AppColors.textMuted,
        ),
      );
    }

    switch (message.type) {
      case MessageType.text:
        return Text(message.content, style: defaultStyle);
      case MessageType.image:
        return _wrapMedia(
          height: 150,
          width: 200,
          child: Hero(
            tag: message.messageId,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl ?? '',
                placeholder: (context, url) => const SizedBox(
                  height: 150,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.secondary, strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error, color: AppColors.error),
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      case MessageType.video:
        return _wrapMedia(
          height: 150,
          width: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
              ),
            ],
          ),
        );
      case MessageType.voice:
        return _wrapMedia(
          height: 56,
          width: 200,
          child: _VoicePlayBubble(mediaUrl: message.mediaUrl ?? ''),
        );
      case MessageType.file:
        return _wrapMedia(
          height: 72,
          width: 200,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.insert_drive_file_rounded, color: Colors.amber, size: 36),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      message.fileName ?? 'Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (message.fileSize != null)
                      Text(
                        message.fileSize!,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      case MessageType.location:
        return GestureDetector(
          onTap: () {
            sl<LocationService>().openInGoogleMaps(message.latitude!, message.longitude!);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  sl<LocationService>().getStaticMapUrl(message.latitude!, message.longitude!,),
                  height: 120,
                  width: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: 200,
                      color: AppColors.surfaceLight,
                      child: Center(
                        child: Icon(
                          CupertinoIcons.map_pin_ellipse,
                          color: AppColors.textSecondary,
                          size: 40,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 4),
                  Text('Shared Location', style: defaultStyle.copyWith(fontSize: 13)),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _wrapMedia({
    required Widget child,
    double? height,
    double? width,
  }) {
    return GestureDetector(
      onTap: transfer == null || !transfer!.isDownload ? onMediaTap : null,
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (transfer != null && transfer!.isDownload)
              MediaTransferOverlay(
                transfer: transfer!,
                onRetry: onRetryDownload,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptTick(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 14, color: AppColors.textPrimary);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: AppColors.textPrimary);
      case MessageStatus.seen:
        return const Icon(Icons.done_all, size: 14, color: AppColors.secondary);
    }
  }
}

class _VoicePlayBubble extends StatefulWidget {
  final String mediaUrl;
  const _VoicePlayBubble({required this.mediaUrl});

  @override
  State<_VoicePlayBubble> createState() => _VoicePlayBubbleState();
}

class _VoicePlayBubbleState extends State<_VoicePlayBubble> {
  late AudioBloc _audioBloc;

  @override
  void initState() {
    super.initState();
    _audioBloc = sl<AudioBloc>();
  }

  @override
  void dispose() {
    _audioBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _audioBloc,
      child: BlocBuilder<AudioBloc, AudioState>(
        builder: (context, state) {
          final isPlaying = state is AudioPlaybackInProgress;
          final isPaused = state is AudioPlaybackPaused;
          final isCurrent = isPlaying || isPaused;

          Duration pos = Duration.zero;
          Duration dur = Duration.zero;

          if (state is AudioPlaybackInProgress) {
            pos = state.position;
            dur = state.duration;
          } else if (state is AudioPlaybackPaused) {
            pos = state.position;
            dur = state.duration;
          }

          final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (isPlaying) {
                    _audioBloc.add(PauseAudioRequested());
                  } else {
                    _audioBloc.add(PlayAudioRequested(widget.mediaUrl));
                  }
                },
              ),
              Expanded(
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    value: isCurrent ? progress : 0.0,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isCurrent ? _formatDuration(pos) : 'Voice',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}