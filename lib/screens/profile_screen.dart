import 'package:flutter/material.dart';

import '../controllers/auth_controller.dart';
import '../models/user.dart';
import '../widgets/auth_layout.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.auth, required this.user});
  final AuthController auth;
  final User user;

  @override
  Widget build(BuildContext context) => AuthLayout(
    title: 'Mon profil',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Icon(Icons.account_circle, size: 80, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          'Bonjour ${user.firstName}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22),
        ),
        const SizedBox(height: 24),
        ErrorNotice(auth.error),
        ListTile(
          leading: const Icon(Icons.person),
          title: const Text('Nom complet'),
          subtitle: Text(user.fullName),
        ),
        ListTile(
          leading: const Icon(Icons.email),
          title: const Text('Email'),
          subtitle: Text(user.email),
        ),
        ListTile(
          leading: const Icon(Icons.security),
          title: const Text('Rôle'),
          subtitle: Text(user.roleLabel),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: auth.busy ? null : auth.refresh,
          child: const Text('Actualiser mon profil'),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: auth.busy ? null : auth.logout,
          child: const Text('Se déconnecter'),
        ),
        if (auth.busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Traitement en cours',
              ),
            ),
          ),
      ],
    ),
  );
}
