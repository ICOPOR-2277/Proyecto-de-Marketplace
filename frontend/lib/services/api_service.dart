import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';

class ApiService {
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static void setBaseUrl(String url) {
    baseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  static String? resolveImageUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) return null;
    if (rawUrl.startsWith('/')) {
      return '$baseUrl$rawUrl';
    }
    if (rawUrl.contains('127.0.0.1:8000') || rawUrl.contains('localhost:8000')) {
      final uri = Uri.tryParse(rawUrl);
      if (uri != null) {
        return '$baseUrl${uri.path}';
      }
    }
    return rawUrl;
  }

  static Future<CurrentUser> login(String correo, String password) async {
    final uri = Uri.parse('$baseUrl/usuarios/login');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'correo': correo, 'password': password}),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final u = data['usuario'];
      return CurrentUser(
        id: u['id'],
        nombre: u['nombre'],
        correo: u['correo'],
        esAdministrador: u['es_administrador'] ?? false,
        token: data['access_token'],
        modoModeradorActivo: false,
      );
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Error al iniciar sesión');
    }
  }

  static Future<void> register(String nombre, String correo, String password) async {
    final uri = Uri.parse('$baseUrl/usuarios/registro');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'nombre': nombre,
            'correo': correo,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200 && response.statusCode != 201) {
      final decoded = jsonDecode(response.body);
      String errorMessage = 'Error en el registro';
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is String) {
          errorMessage = detail;
        } else if (detail is List) {
          final messages = <String>[];
          for (final item in detail) {
            if (item is Map) {
              final loc = (item['loc'] as List?)?.join('.') ?? '';
              final type = item['type'] ?? '';
              if (loc.contains('password')) {
                if (type == 'string_too_short') {
                  messages.add('La contraseña debe tener mínimo 8 caracteres.');
                } else {
                  messages.add('La contraseña no cumple los requisitos.');
                }
              } else if (loc.contains('correo')) {
                messages.add('El correo institucional no es válido (usa @utb.edu.co).');
              } else if (loc.contains('nombre')) {
                messages.add('El nombre debe tener al menos 2 caracteres.');
              } else {
                messages.add(item['msg']?.toString() ?? 'Dato inválido');
              }
            }
          }
          if (messages.isNotEmpty) {
            errorMessage = messages.join('\n');
          }
        }
      }
      throw Exception(errorMessage);
    }
  }

  static Future<String> uploadImage(XFile file) async {
    final uri = Uri.parse('$baseUrl/listings/upload-image');
    final request = http.MultipartRequest('POST', uri);
    final bytes = await file.readAsBytes();
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: file.name),
    );
    final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['url'] as String;
    }
    throw Exception('Error al subir imagen: ${response.statusCode}');
  }

  static Future<Listing> createListing({
    required String category,
    required String title,
    required String price,
    required String imageUrl,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/listings/');
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .post(
          uri,
          headers: headers,
          body: jsonEncode({
            'category': category,
            'title': title,
            'price': price,
            'imageUrl': imageUrl,
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 && response.statusCode != 201) {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Error creando publicación');
    }
    final data = jsonDecode(response.body);
    return Listing(
      id: data['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
      categoryLabel: data['category'] ?? category,
      title: data['title'] ?? title,
      price: data['price'] ?? price,
      imageUrl: data['imageUrl'] ?? imageUrl,
      estado: data['estado'] ?? 'activa',
      usuarioId: data['usuario_id'] as int?,
      vendedorNombre: data['vendedor_nombre'] as String?,
    );
  }

  static Future<List<Listing>> fetchListings({String? category}) async {
    final query = (category != null && category.isNotEmpty)
        ? '?category=${Uri.encodeComponent(category)}'
        : '';
    final uri = Uri.parse('$baseUrl/listings/$query');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) {
        return Listing(
          id: item['id'].toString(),
          categoryLabel: item['category'] ?? '',
          title: item['title'] ?? '',
          price: item['price'] ?? '',
          imageUrl: resolveImageUrl(item['imageUrl']),
          estado: item['estado'] ?? 'activa',
          usuarioId: item['usuario_id'] as int?,
          vendedorNombre: item['vendedor_nombre'] as String?,
        );
      }).toList();
    }
    return [];
  }

  static Future<List<Listing>> searchListings(String query) async {
    final uri = Uri.parse('$baseUrl/busqueda/?query=${Uri.encodeComponent(query)}');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) {
        final precioNum = (item['precio'] as num?)?.toInt() ?? 0;
        final precioStr = '\$$precioNum';
        return Listing(
          id: item['id'].toString(),
          categoryLabel: item['categoria'] ?? '',
          title: item['titulo'] ?? '',
          price: precioStr,
          imageUrl: resolveImageUrl(item['imagen_url']),
          estado: item['estado'] ?? 'activa',
          usuarioId: item['usuario_id'] as int?,
          vendedorNombre: item['vendedor_nombre'] as String?,
        );
      }).toList();
    }
    return [];
  }

  // ==========================================
  // Endpoints para Compras (Requisitos 1 y 2)
  // ==========================================
  static Future<List<dynamic>> realizarCompra({
    required String token,
    required List<Map<String, dynamic>> items,
  }) async {
    final uri = Uri.parse('$baseUrl/compras/');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'items': items}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Error al procesar la compra');
    }
  }

  static Future<Map<String, dynamic>> validarPublicacion(int publicacionId) async {
    final uri = Uri.parse('$baseUrl/compras/validar/$publicacionId');
    final response = await http.get(uri).timeout(const Duration(seconds: 6));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error validando disponibilidad de la publicación');
  }

  // ==========================================
  // Endpoints para Chat Interactivo (Requisito 3)
  // ==========================================
  static Future<List<ChatConversation>> fetchConversations(String token) async {
    final uri = Uri.parse('$baseUrl/chat/conversaciones');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => ChatConversation.fromJson(item)).toList();
    }
    return [];
  }

  static Future<List<ChatMessage>> fetchMessages(String token, int otroUsuarioId) async {
    final uri = Uri.parse('$baseUrl/chat/mensajes/$otroUsuarioId');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => ChatMessage.fromJson(item)).toList();
    }
    return [];
  }

  static Future<ChatMessage> sendMessage({
    required String token,
    required int destinatarioId,
    required String contenido,
    int? publicacionId,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/mensajes');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'destinatario_id': destinatarioId,
            'contenido': contenido,
            if (publicacionId != null) ...{'publicacion_id': publicacionId},
          }),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 201 || response.statusCode == 200) {
      return ChatMessage.fromJson(jsonDecode(response.body));
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Error al enviar mensaje');
  }

  static Future<Map<String, dynamic>> fetchSellerForListing(int publicacionId) async {
    final uri = Uri.parse('$baseUrl/chat/vendedor-publicacion/$publicacionId');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al obtener vendedor');
  }



  // ==========================================
  // Endpoints para Moderador
  // ==========================================
  static Future<Map<String, dynamic>> fetchModeratorStats(String token) async {
    final uri = Uri.parse('$baseUrl/moderacion/stats');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error cargando estadísticas');
  }

  static Future<List<dynamic>> fetchModeratorListings(String token) async {
    final uri = Uri.parse('$baseUrl/moderacion/publicaciones');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Error cargando publicaciones para moderación');
  }

  static Future<void> updateListingStatus(String token, int id, String estado) async {
    final uri = Uri.parse('$baseUrl/moderacion/publicaciones/$id/estado');
    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'estado': estado}),
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Error actualizando estado');
    }
  }

  static Future<void> deleteListing(String token, int id) async {
    final uri = Uri.parse('$baseUrl/moderacion/publicaciones/$id');
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Error eliminando publicación');
    }
  }

  // ==========================================
  // Endpoints para Mis Publicaciones (Estudiante Vendedor)
  // ==========================================
  static Future<List<Listing>> fetchMisPublicaciones(String token) async {
    final uri = Uri.parse('$baseUrl/publicaciones/mis-publicaciones');
    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) {
        return Listing(
          id: item['id'].toString(),
          categoryLabel: item['category'] ?? item['categoria'] ?? '',
          title: item['title'] ?? item['titulo'] ?? '',
          price: item['price'] ?? '\$${item['precio'] ?? 0}',
          imageUrl: resolveImageUrl(item['imageUrl'] ?? item['imagen_url']),
          estado: item['estado'] ?? 'activa',
          usuarioId: item['usuario_id'] as int?,
          vendedorNombre: item['vendedor_nombre'] as String?,
        );
      }).toList();
    }
    throw Exception('Error al cargar mis publicaciones');
  }

  static Future<void> updateMiPublicacionEstado(String token, int id, String nuevoEstado) async {
    final uri = Uri.parse('$baseUrl/publicaciones/$id/estado?nuevo_estado=$nuevoEstado');
    final response = await http.patch(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Error actualizando estado de la publicación');
    }
  }

  static Future<void> deleteMiPublicacion(String token, int id) async {
    final uri = Uri.parse('$baseUrl/publicaciones/$id');
    final response = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Error al eliminar la publicación');
    }
  }
}
