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
    title: 'Connexion',
    child: AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.person, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Bienvenue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 24),
            ErrorNotice(widget.auth.error),
            TextFormField(
              controller: _email,
              enabled: !widget.auth.busy,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              autocorrect: false,
              validator: (value) =>
                  value == null ||
                      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(value.trim()) ||
                      value.trim().length > 254
                  ? 'Veuillez entrer un email valide'
                  : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _password,
              enabled: !widget.auth.busy,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                ),
              ),
              autofillHints: const [AutofillHints.password],
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) => value == null || value.isEmpty
                  ? 'Veuillez entrer votre mot de passe'
                  : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.auth.busy ? null : _submit,
              child: const Text('Se connecter'),
            ),
            if (widget.auth.busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Connexion en cours',
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
