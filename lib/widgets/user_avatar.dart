import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final double? fontSize;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.radius = 20,
    this.fontSize,
    this.onTap,
  });

  /// Tạo cặp màu gradient cố định dựa trên tên người dùng (giống Gmail/Slack)
  static List<Color> _getGradientForName(String name) {
    const gradients = [
      [Color(0xFFFF8A65), Color(0xFFE64A19)], // Warm Orange / Rust
      [Color(0xFF4FC3F7), Color(0xFF0288D1)], // Vivid Sky / Ocean Blue
      [Color(0xFF81C784), Color(0xFF388E3C)], // Mint / Deep Forest
      [Color(0xFFBA68C8), Color(0xFF7B1FA2)], // Lavender / Royal Purple
      [Color(0xFFFFB74D), Color(0xFFF57C00)], // Amber / Sunset Gold
      [Color(0xFF4DB6AC), Color(0xFF00796B)], // Teal / Deep Cyan
      [Color(0xFFE57373), Color(0xFFD32F2F)], // Soft Coral / Crimson
      [Color(0xFF7986CB), Color(0xFF303F9F)], // Indigo / Deep Night
    ];

    if (name.isEmpty) return gradients[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % gradients.length;
    return gradients[index];
  }

  /// Lấy 1-2 ký tự viết tắt chuẩn
  static String getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final initials = getInitials(name);
    final colors = _getGradientForName(name);
    final effectiveFontSize = fontSize ?? (radius * 0.75);

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: effectiveFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    Widget content;
    final validUrl = photoUrl != null &&
        photoUrl!.trim().isNotEmpty &&
        (photoUrl!.startsWith('http://') || photoUrl!.startsWith('https://'));

    if (validUrl) {
      content = ClipOval(
        child: Image.network(
          photoUrl!.trim(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return fallback();
          },
          errorBuilder: (context, error, stackTrace) {
            return fallback();
          },
        ),
      );
    } else {
      content = fallback();
    }

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    return content;
  }
}
