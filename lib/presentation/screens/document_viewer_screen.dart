import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/theme.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String docUrl;
  final String docName;

  const DocumentViewerScreen({
    super.key,
    required this.docUrl,
    required this.docName,
  });

  Future<void> _openDocument(
      BuildContext context, {
        required String docURL,
      }) async {
    try {
      final uri = Uri.parse(docURL);

      if (!await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception("Could not launch");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unable to open document\n$e"),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Document'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkBackgroundGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  size: 100,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                docName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This file is stored in Cloud Storage. Tap the button below to view or download it to your local storage.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () => _openDocument(context,docURL: docUrl),
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('OPEN IN BROWSER'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
