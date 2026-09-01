import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

import '../../core/models/pending_media_transfer.dart';
import '../../core/constants/theme.dart';
import '../../core/constants/whatsapp_theme.dart';
import '../../core/utils/date_time_formatter.dart';
import '../../domain/entities/message_entity.dart';
import '../../routes/router.dart';
import '../widgets/chat_date_separator.dart';
import '../widgets/connectivity_banner.dart';
import '../widgets/message_options_sheet.dart';
import '../blocs/audio/audio_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/location/location_bloc.dart';
import '../blocs/message/message_bloc.dart';
import '../mixins/chat_media_transfer_mixin.dart';
import '../widgets/chat/media_transfer_widgets.dart';
import '../widgets/shimmer_loading.dart';
import '../blocs/search/search_bloc.dart';
import '../blocs/typing/typing_bloc.dart';

class GroupChatScreen extends StatefulWidget {
  final String roomId;
  final String groupName;
  final String groupImage;

  const GroupChatScreen({
    super.key,
    required this.roomId,
    required this.groupName,
    required this.groupImage,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> with ChatMediaTransferMixin {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Timer? _typingDebounce;
  bool _isWriting = false;
  bool _showSearch = false;
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      _currentUserName = authState.user.fullName;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text, String currentUserId) {
    setState(() {});
    if (!_isWriting && text.isNotEmpty) {
      _isWriting = true;
      context.read<TypingBloc>().add(
            UpdateTypingRequest(roomId: widget.roomId, uid: currentUserId, isTyping: true),
          );
    } else if (_isWriting && text.isEmpty) {
      _isWriting = false;
      context.read<TypingBloc>().add(
            UpdateTypingRequest(roomId: widget.roomId, uid: currentUserId, isTyping: false),
          );
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 3), () {
      if (_isWriting) {
        _isWriting = false;
        context.read<TypingBloc>().add(
              UpdateTypingRequest(roomId: widget.roomId, uid: currentUserId, isTyping: false),
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

    final message = MessageEntity(
      messageId: messageId ?? _uuid.v4(),
      senderId: currentUserId,
      senderName: _currentUserName,
      receiverId: '',
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
          SendMessageRequested(roomId: widget.roomId, message: message),
        );

    _messageController.clear();
    if (_isWriting) {
      _isWriting = false;
      context.read<TypingBloc>().add(
            UpdateTypingRequest(roomId: widget.roomId, uid: currentUserId, isTyping: false),
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
          SnackBar(content: Text('Location failed: ${state.error}'), backgroundColor: AppColors.error),
        );
        locationSubscription.cancel();
      }
    });
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

  void _showReadByDialog(MessageEntity message) {
    if (message.readBy.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Seen by'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: message.readBy.entries.map((e) {
            final time = DateTime.tryParse(e.value);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${e.key == message.senderId ? 'You (sender)' : e.key}: ${time != null ? DateTimeFormatter.formatMessageTime(time) : e.value}',
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final currentUserId = authState is Authenticated ? authState.user.uid : '';

    return BlocListener<MessageBloc, MessageState>(
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
      backgroundColor: WhatsAppColors.background(context),
      appBar: AppBar(
        backgroundColor: WhatsAppColors.bar(context),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: GestureDetector(
          onTap: () => context.push('${AppRoutes.groupInfo}/${widget.roomId}'),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF2A3942),
                backgroundImage: widget.groupImage.isNotEmpty
                    ? CachedNetworkImageProvider(widget.groupImage)
                    : null,
                child: widget.groupImage.isEmpty
                    ? const Icon(Icons.groups, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.groupName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'tap here for group info',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search, color: Colors.white),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => context.push('${AppRoutes.groupInfo}/${widget.roomId}'),
          ),
        ],
      ),
      body: Column(
        children: [
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
                  style: TextStyle(color: WhatsAppColors.primaryText(context)),
                  decoration: InputDecoration(
                    hintText: 'Search messages...',
                    hintStyle: const TextStyle(color: WhatsAppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: WhatsAppColors.textSecondary),
                    filled: true,
                    fillColor: WhatsAppColors.inputBackground(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
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
                              msg.content,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${msg.senderName.isNotEmpty ? msg.senderName : msg.senderId} • ${DateTimeFormatter.formatMessageTime(msg.timestamp)}',
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
                    return const ShimmerMessageList();
                  }
                  if (state is MessagesLoaded) {
                    final messages = state.messages;
                    if (messages.isEmpty) {
                      return Center(
                        child: Text(
                          'Messages and calls are end-to-end encrypted.\nNo one outside this group can read them.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: WhatsAppColors.textSecondary.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
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
                      children: _buildGroupMessageList(messages, currentUserId),
                    );
                  }
                  if (state is MessageFailure) {
                    return Center(child: Text('Error: ${state.error}'));
                  }
                  return Container();
                },
              ),
            ),
            _buildTypingIndicator(currentUserId),
            if (!_showSearch) _buildInputBar(context, currentUserId),
          ],
        ),
      ),
    );

  }

  List<Widget> _buildGroupMessageList(List<MessageEntity> messages, String currentUserId) {
    final items = <Widget>[];
    for (var i = 0; i < messages.length; i++) {
      if (DateTimeFormatter.shouldShowDateSeparator(
        items: messages,
        index: i,
        timestampOf: (m) => m.timestamp,
      )) {
        items.add(ChatDateSeparator(date: messages[i].timestamp));
      }
      final message = messages[i];
      items.add(
        _GroupMessageBubble(
          message: message,
          isMe: message.senderId == currentUserId,
          roomId: widget.roomId,
          currentUserId: currentUserId,
          transfer: pendingTransfers[message.messageId],
          onRetryDownload: () => retryDownload(message),
          onMediaTap: () => handleMediaTap(message),
          onReadByTap: message.senderId == currentUserId
              ? () => _showReadByDialog(message)
              : null,
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

  Widget _buildTypingIndicator(String currentUserId) {
    return BlocBuilder<TypingBloc, TypingState>(
      builder: (context, state) {
        if (state is TypingUpdated) {
          final typingUsers = state.typingMap.entries
              .where((e) => e.value && e.key != currentUserId)
              .map((e) => e.key)
              .toList();
          if (typingUsers.isNotEmpty) {
            return Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: WhatsAppColors.receivedBubbleColor(context),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    typingUsers.length == 1
                        ? 'typing...'
                        : '${typingUsers.length} people typing...',
                    style: const TextStyle(
                      color: WhatsAppColors.textSecondary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isRecording)
                  IconButton(
                    icon: Icon(Icons.emoji_emotions_outlined,
                        color: WhatsAppColors.textSecondary.withValues(alpha: 0.9)),
                    onPressed: () {},
                  ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: WhatsAppColors.inputBackground(context),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        if (!isRecording)
                          IconButton(
                            icon: const Icon(Icons.attach_file,
                                color: WhatsAppColors.textSecondary),
                            onPressed: () => _showAttachmentOptions(context, currentUserId),
                          ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: isRecording
                                ? const _VoiceRecordingPanel()
                                : TextFormField(
                                    controller: _messageController,
                                    onChanged: (text) => _onTextChanged(text, currentUserId),
                                    style: TextStyle(
                                      color: WhatsAppColors.primaryText(context),
                                    ),
                                    maxLines: 4,
                                    minLines: 1,
                                    decoration: const InputDecoration(
                                      hintText: 'Message',
                                      hintStyle: TextStyle(color: WhatsAppColors.textSecondary),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                          ),
                        ),
                        if (!isRecording)
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined,
                                color: WhatsAppColors.textSecondary),
                            onPressed: () => _captureImage(currentUserId),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () async {
                    if (isRecording) {
                      context.read<AudioBloc>().add(StopRecordingRequested());
                      late StreamSubscription audioSub;
                      audioSub = context.read<AudioBloc>().stream.listen((state) {
                        if (state is AudioRecordingSuccess) {
                          _uploadAndSendFile(state.filePath, MessageType.voice, currentUserId);
                          audioSub.cancel();
                        }
                      });
                    } else if (_messageController.text.trim().isEmpty) {
                      context.read<AudioBloc>().add(StartRecordingRequested());
                    } else {
                      _sendMessage(_messageController.text, MessageType.text, currentUserId);
                    }
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: WhatsAppColors.accent,
                    child: Icon(
                      isRecording
                          ? Icons.stop_rounded
                          : _messageController.text.trim().isEmpty
                              ? Icons.mic
                              : Icons.send_rounded,
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

class _GroupMessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final String roomId;
  final String currentUserId;
  final PendingMediaTransfer? transfer;
  final VoidCallback? onRetryDownload;
  final VoidCallback? onMediaTap;
  final VoidCallback? onReadByTap;

  const _GroupMessageBubble({
    required this.message,
    required this.isMe,
    required this.roomId,
    required this.currentUserId,
    this.transfer,
    this.onRetryDownload,
    this.onMediaTap,
    this.onReadByTap,
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
    final bubbleColor = isMe
        ? WhatsAppColors.sentBubbleColor(context)
        : WhatsAppColors.receivedBubbleColor(context);
    final textStyle = TextStyle(
      color: isMe
          ? Colors.white
          : WhatsAppColors.primaryText(context),
      fontSize: 15,
      height: 1.35,
    );
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomLeft: Radius.circular(isMe ? 8 : 2),
      bottomRight: Radius.circular(isMe ? 2 : 8),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          if (!isMe && message.senderName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(
                message.senderName,
                style: TextStyle(
                  color: WhatsAppColors.senderNameColor(message.senderName),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          GestureDetector(
            onLongPress: () => _showDeleteOptions(context),
            child: Container(
              margin: EdgeInsets.only(
                left: isMe ? 48 : 8,
                right: isMe ? 8 : 48,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(context, textStyle),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        DateTimeFormatter.formatMessageTime(message.timestamp),
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.75)
                              : WhatsAppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: onReadByTap,
                          child: _buildReceiptTick(message.status),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: message.mediaUrl ?? '',
              placeholder: (_, __) => const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => const Icon(Icons.error, color: AppColors.error),
              fit: BoxFit.cover,
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic, color: Colors.white70),
              const SizedBox(width: 8),
              Text('Voice message', style: defaultStyle),
            ],
          ),
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
                child: Text(
                  message.fileName ?? 'Document',
                  style: defaultStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      case MessageType.location:
        return Row(
          children: [
            const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
            const SizedBox(width: 4),
            Text('Shared Location', style: defaultStyle.copyWith(fontSize: 13)),
          ],
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
        return const Icon(Icons.check, size: 14, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.white70);
      case MessageStatus.seen:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF53BDEB));
    }
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
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _seconds++));
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
    return Row(
      children: [
        const Icon(Icons.fiber_manual_record, color: AppColors.error, size: 14),
        const SizedBox(width: 8),
        Text(
          'Recording... ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
          style: const TextStyle(color: AppColors.textPrimary),
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
