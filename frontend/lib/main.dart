import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MarketplaceApp());
}

class MarketplaceApp extends StatelessWidget {
  const MarketplaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marketplace UTB',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const MarketplaceHomePage(),
    );
  }
}

class MarketplaceHomePage extends StatefulWidget {
  const MarketplaceHomePage({super.key});

  @override
  State<MarketplaceHomePage> createState() => _MarketplaceHomePageState();
}

class _MarketplaceHomePageState extends State<MarketplaceHomePage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  String? _token;
  String? _message;
  bool _loading = false;
  List<Map<String, dynamic>> _publications = [];

  static const String _apiBaseUrl = 'http://127.0.0.1:8000';

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Completa nombre, correo y contraseña');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/usuarios/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': name,
          'correo': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        _showMessage('Usuario registrado correctamente');
      } else {
        final body = jsonDecode(response.body);
        _showMessage(body['detail'] ?? 'Error al registrar');
      }
    } catch (_) {
      _showMessage('No se pudo conectar con el backend');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Correo y contraseña requeridos');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/usuarios/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _token = body['access_token'];
        });
        await _fetchPublications();
        _showMessage('Sesión iniciada');
      } else {
        final body = jsonDecode(response.body);
        _showMessage(body['detail'] ?? 'Credenciales inválidas');
      }
    } catch (_) {
      _showMessage('No se pudo iniciar sesión');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchPublications() async {
    if (_token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/busqueda/?query=${_searchController.text.trim()}'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _publications = List<Map<String, dynamic>>.from(body is List ? body : []);
        });
      }
    } catch (_) {
      _showMessage('No se pudieron cargar las publicaciones');
    }
  }

  Future<void> _createPublication() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final priceText = _priceController.text.trim();
    final category = _categoryController.text.trim();

    if (_token == null || title.isEmpty || description.isEmpty || category.isEmpty) {
      _showMessage('Debes iniciar sesión y completar los datos de la publicación');
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null) {
      _showMessage('El precio debe ser un número válido');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/publicaciones/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'titulo': title,
          'descripcion': description,
          'precio': price,
          'categoria': category,
        }),
      );

      if (response.statusCode == 201) {
        _titleController.clear();
        _descriptionController.clear();
        _priceController.clear();
        _categoryController.clear();
        await _fetchPublications();
        _showMessage('Publicación creada');
      } else {
        final body = jsonDecode(response.body);
        _showMessage(body['detail'] ?? 'No se pudo crear la publicación');
      }
    } catch (_) {
      _showMessage('Error de conexión al crear la publicación');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showMessage(String text) {
    setState(() => _message = text);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _message = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace UTB'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_message != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(_message!),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registro / Login',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Correo institucional'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Contraseña'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _register,
                            child: const Text('Registrar'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: const Text('Login'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crear publicación',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Título'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Descripción'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Precio'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loading || _token == null ? null : _createPublication,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Publicar servicio'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Búsqueda',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: _fetchPublications,
                          icon: const Icon(Icons.search),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(labelText: 'Buscar por palabra clave'),
                    ),
                    const SizedBox(height: 12),
                    if (_publications.isEmpty)
                      const Text('No hay publicaciones para mostrar')
                    else
                      ..._publications.map(
                        (publication) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                publication['titulo'] ?? 'Sin título',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(publication['descripcion'] ?? ''),
                              const SizedBox(height: 6),
                              Text('Precio: ${publication['precio'] ?? 0}'),
                              Text('Categoría: ${publication['categoria'] ?? 'Sin categoría'}'),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
}
