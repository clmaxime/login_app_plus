import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.auth.busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await widget.auth.login(_email.text.trim(), _password.text);
    if (mounted && widget.auth.user != null) {
      TextInput.finishAutofillContext();
      _password.clear();
    }
  }

  @override
  Widget build(BuildContext context) => AuthLayout(
    child: AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Bienvenue.',
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Connectez-vous pour retrouver votre profil.',
              style: TextStyle(
                color: Color(0xFF596760),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ErrorNotice(widget.auth.error),
            TextFormField(
              controller: _email,
              enabled: !widget.auth.busy,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              autocorrect: false,
              validator: (v) =>
                  v == null ||
                      !RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(v.trim()) ||
                      v.trim().length > 254
                  ? 'Veuillez entrer un email valide'
                  : null,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _password,
              enabled: !widget.auth.busy,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              autofillHints: const [AutofillHints.password],
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) => v == null || v.isEmpty
                  ? 'Veuillez entrer votre mot de passe'
                  : null,
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: widget.auth.busy ? null : _submit,
              child: widget.auth.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Connexion en cours',
                      ),
                    )
                  : const Text('Se connecter'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Votre mot de passe reste confidentiel.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF596760), fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}
