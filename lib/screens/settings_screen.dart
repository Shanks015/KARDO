import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        actions: [
          IconButton(
            onPressed: () => ref.read(configProvider.notifier).toggleTheme(),
            icon: Icon(config.isDark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionTitle(context, "APP THEME"),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Dark Mode"),
            subtitle: const Text("Switch between light and dark themes"),
            trailing: Switch(
              value: config.isDark,
              onChanged: (_) => ref.read(configProvider.notifier).toggleTheme(),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(context, "ON-DEVICE OFFLINE AI"),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.offline_bolt_rounded, color: Theme.of(context).colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        "Fully Offline Extractor",
                        style: TextStyle(fontSize: 16, fontWeight: kIsWeb ? FontWeight.w600 : FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildAiEngineRow(
                    context,
                    Icons.text_fields_rounded,
                    "OCR Engine",
                    "Google ML Kit Text Recognition",
                    "Extracts raw characters and lines locally on Android & iOS.",
                  ),
                  const Divider(height: 24),
                  _buildAiEngineRow(
                    context,
                    Icons.psychology_rounded,
                    "Entity Recognizer",
                    "Google ML Kit Entity Extraction",
                    "Sequence transformer model maps names, phones, emails, and locations offline.",
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              "kardo Standalone v3.0.0 (Serverless)",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildAiEngineRow(
    BuildContext context,
    IconData icon,
    String label,
    String name,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

