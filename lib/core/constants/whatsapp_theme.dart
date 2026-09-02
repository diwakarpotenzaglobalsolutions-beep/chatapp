import 'package:flutter/material.dart';

/// WhatsApp-inspired palette for group chat screens.
class WhatsAppColors {
  static const Color appBar = Color(0xFF1F2C34);
  static const Color appBarLight = Color(0xFF008069);
  static const Color chatBackground = Color(0xFF0B141A);
  static const Color chatBackgroundLight = Color(0xFFECE5DD);
  static const Color sentBubble = Color(0xFF005C4B);
  static const Color sentBubbleLight = Color(0xFFD9FDD3);
  static const Color receivedBubble = Color(0xFF202C33);
  static const Color receivedBubbleLight = Color(0xFFFFFFFF);
  static const Color inputBar = Color(0xFF1F2C34);
  static const Color inputBarLight = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF00A884);
  static const Color textPrimary = Color(0xFFE9EDEF);
  static const Color textPrimaryLight = Color(0xFF111B21);
  static const Color textSecondary = Color(0xFF8696A0);
  static const Color divider = Color(0xFF2A3942);
  static const Color searchField = Color(0xFF202C33);

  static const List<Color> senderNameColors = [
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFFBC6FF1),
    Color(0xFF00C9A7),
    Color(0xFFFF922B),
    Color(0xFF5CE1E6),
  ];

  static Color senderNameColor(String name) {
    final index = name.hashCode.abs() % senderNameColors.length;
    return senderNameColors[index];
  }

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color background(BuildContext context) =>
      isDark(context) ? chatBackground : chatBackgroundLight;

  static Color bar(BuildContext context) =>
      isDark(context) ? appBar : appBarLight;

  static Color sentBubbleColor(BuildContext context) =>
      isDark(context) ? sentBubble : sentBubbleLight;

  static Color receivedBubbleColor(BuildContext context) =>
      isDark(context) ? receivedBubble : receivedBubbleLight;

  static Color primaryText(BuildContext context) =>
      isDark(context) ? textPrimary : textPrimaryLight;

  static Color inputBackground(BuildContext context) =>
      isDark(context) ? inputBar : inputBarLight;
}
