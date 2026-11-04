import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/user.dart';
import '../widgets/auth_layout.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.auth, required this.user});
  final AuthController auth;
  final User user;
  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: Icon(
                Icons.check_circle,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: const Text('Vous êtes connecté'),
            ),
          ),
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 42,
            child: Text(
              '${user.firstName.characters.first}${user.lastName.characters.first}',
              style: const TextStyle(fontSize: 28),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bonjour ${user.firstName}.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ravi de vous retrouver dans votre espace.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF596760)),
          ),
          const SizedBox(height: 28),
          ErrorNotice(auth.error),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Nom complet'),
                    subtitle: Text(user.fullName),
                  ),
                  ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: const Text('Email'),
                    subtitle: Text(user.email),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('Rôle'),
                    subtitle: Text(user.roleLabel),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: auth.busy ? null : auth.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Actualiser mon profil'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: auth.busy ? null : auth.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
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
}
