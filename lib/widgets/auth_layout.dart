import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 48).clamp(0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: LayoutBuilder(
                  builder: (context, inner) => inner.maxWidth >= 800
                      ? Row(
                          children: [
                            const Expanded(child: _BrandPanel()),
                            const SizedBox(width: 64),
                            Expanded(child: child),
                          ],
                        )
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: child,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(40),
    decoration: BoxDecoration(
      color: const Color(0xFF173F3B),
      borderRadius: BorderRadius.circular(32),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'ESPACE / PERSONNEL',
          style: TextStyle(
            color: Color(0xFFB7D9C4),
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 48),
        Image.asset(
          'assets/images/connection.png',
          height: 160,
          semanticLabel: 'Illustration d’un espace personnel connecté',
        ),
        const SizedBox(height: 32),
        const Text(
          'Votre espace.\nEn toute simplicité.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            height: 1.15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Une connexion à votre compte,\nun accès à l’essentiel.',
          style: TextStyle(color: Color(0xFFCEE2DA), fontSize: 17, height: 1.6),
        ),
      ],
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Semantics(
          liveRegion: true,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        );
}
