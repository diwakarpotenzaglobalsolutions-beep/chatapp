import 'package:flutter/material.dart';

import '../../core/constants/whatsapp_theme.dart';

class ShimmerLoading extends StatefulWidget {
  final Widget child;

  const ShimmerLoading({super.key, required this.child});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = WhatsAppColors.isDark(context);
    final base = isDark ? const Color(0xFF202C33) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF2A3942) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1 - _controller.value * 2, 0),
              end: Alignment(1 - _controller.value * 2, 0),
              colors: [base, highlight, base],
              stops: const [0.1, 0.5, 0.9],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = WhatsAppColors.isDark(context);
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202C33) : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerListTile extends StatelessWidget {
  const ShimmerListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const ShimmerBox(width: 48, height: 48, radius: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(width: double.infinity, height: 14, radius: 4),
                SizedBox(height: 8),
                ShimmerBox(width: 120, height: 12, radius: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShimmerMessageBubble extends StatelessWidget {
  final bool isMe;

  const ShimmerMessageBubble({super.key, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ShimmerBox(
          width: MediaQuery.of(context).size.width * (isMe ? 0.55 : 0.65),
          height: isMe ? 44 : 56,
          radius: 8,
        ),
      ),
    );
  }
}

class ShimmerMessageList extends StatelessWidget {
  const ShimmerMessageList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: const [
        ShimmerMessageBubble(isMe: false),
        ShimmerMessageBubble(isMe: true),
        ShimmerMessageBubble(isMe: false),
        ShimmerMessageBubble(isMe: true),
        ShimmerMessageBubble(isMe: false),
        ShimmerMessageBubble(isMe: true),
      ],
    );
  }
}

class ShimmerContactList extends StatelessWidget {
  final int itemCount;

  const ShimmerContactList({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: (_, __) => const ShimmerListTile(),
    );
  }
}
