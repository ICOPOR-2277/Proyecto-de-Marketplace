import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'login.dart';

class RegisterDialog extends StatefulWidget {
  final void Function(CurrentUser user) onLoginSuccess;

  const RegisterDialog({super.key, required this.onLoginSuccess});

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() {
        _error = 'Por favor completa todos los campos';
        _loading = false;
      });
      return;
    }

    if (!email.toLowerCase().endsWith('@utb.edu.co')) {
      setState(() {
        _error = 'Debes usar tu correo institucional terminado en @utb.edu.co';
        _loading = false;
      });
      return;
    }

    if (pass.length < 8) {
      setState(() {
        _error = 'La contraseña debe tener al menos 8 caracteres.';
        _loading = false;
      });
      return;
    }

    try {
      await ApiService.register(name, email, pass);
      // Login automático tras registro
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 380,
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
                  'Registro Institucional',
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
              'Crea tu cuenta institucional con tu correo @utb.edu.co para comerciar de forma segura.',
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
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
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
                  : const Text('Registrarme', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (_) => LoginDialog(onLoginSuccess: widget.onLoginSuccess),
                );
              },
              child: const Text(
                '¿Ya tienes cuenta? Inicia sesión aquí',
                style: TextStyle(color: kNavy, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
