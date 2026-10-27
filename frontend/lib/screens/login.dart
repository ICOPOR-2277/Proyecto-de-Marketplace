import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'register.dart';

class LoginDialog extends StatefulWidget {
  final void Function(CurrentUser user) onLoginSuccess;

  const LoginDialog({super.key, required this.onLoginSuccess});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _emailCtrl = TextEditingController(text: 'moderador@utb.edu.co');
  final _passwordCtrl = TextEditingController(text: 'moderador123');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();

    try {
      final user = await ApiService.login(email, pass);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onLoginSuccess(user);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Container(
            width: isMobile ? double.infinity : 380,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/utb_logo.png',
                  height: 28,
                  errorBuilder: (_, __, ___) => const Icon(Icons.school, color: kNavy),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Ingreso UTB',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Accede con tu cuenta institucional de la Universidad Tecnológica de Bolívar.',
              style: TextStyle(fontSize: 12, color: kTextGrey),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo (@utb.edu.co)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Entrar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => RegisterDialog(onLoginSuccess: widget.onLoginSuccess),
                );
              },
              child: const Text(
                '¿No tienes cuenta? Regístrate aquí',
                style: TextStyle(color: kNavy, fontSize: 13),
              ),
            ),
            const Divider(height: 20),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(6)),
              child: const Text(
                'Cuentas demo disponibles:\n• Moderador: moderador@utb.edu.co / moderador123\n• Estudiante: estudiante@utb.edu.co / estudiante123',
                style: TextStyle(fontSize: 10, color: kTextGrey),
              ),
            )
          ],
        ),
      ),
    ),
  ),
);
  }
}
