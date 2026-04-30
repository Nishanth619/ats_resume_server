import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Account Information'),
            subtitle: Text('Manage your account details and preferences'),
            leading: Icon(Icons.person_outline),
          ),
          const Divider(),
          const ListTile(
            title: Text('Privacy Policy'),
            leading: Icon(Icons.privacy_tip_outlined),
          ),
          const ListTile(
            title: Text('Terms of Service'),
            leading: Icon(Icons.description_outlined),
          ),
          const Divider(),
          ListTile(
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () {
              ref.read(authServiceProvider).signOut();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }
}
