import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Widget hiển thị Hearts + XP trên AppBar.
class UserStatusBar extends StatelessWidget {
  final int hearts;
  final int xp;

  const UserStatusBar({super.key, required this.hearts, required this.xp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // XP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚡', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Text(
                  '$xp',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFBBF24),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Hearts
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              return Padding(
                padding: const EdgeInsets.only(right: 1),
                child: Text(
                  i < hearts ? '❤️' : '🖤',
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
