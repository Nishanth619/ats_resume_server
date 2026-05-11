import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../constants/app_colors.dart';

Future<void> showAiReportDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String feature,
  required String output,
  String inputContext = '',
}) async {
  final reasonCtrl = TextEditingController();
  String selectedReason = 'Offensive or unsafe content';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Report AI Output'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Offensive or unsafe content',
                        child: Text('Offensive or unsafe content'),
                      ),
                      DropdownMenuItem(
                        value: 'False or misleading content',
                        child: Text('False or misleading content'),
                      ),
                      DropdownMenuItem(
                        value: 'Unsupported personal claim',
                        child: Text('Unsupported personal claim'),
                      ),
                      DropdownMenuItem(
                        value: 'Other policy concern',
                        child: Text('Other policy concern'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedReason = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    minLines: 3,
                    maxLines: 5,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      labelText: 'Details',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final uid = ref.read(authStateProvider).value?.uid;
                  if (uid == null) return;
                  final details = reasonCtrl.text.trim();
                  await ref.read(firestoreServiceProvider).reportAiOutput(
                        uid: uid,
                        feature: feature,
                        reason: details.isEmpty
                            ? selectedReason
                            : '$selectedReason: $details',
                        output: output,
                        inputContext: inputContext,
                      );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('AI output report submitted.'),
                        backgroundColor: AppColors.scoreGreen,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
}
