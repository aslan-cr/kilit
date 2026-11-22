import 'package:flutter/material.dart';
import 'theme.dart';

class FeaturePlaceholder extends StatelessWidget {
  final String emoji, title, text;
  const FeaturePlaceholder({super.key, required this.emoji, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Glass(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kInkSoft)),
        ]))),
      );
}
