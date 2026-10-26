import 'dart:typed_data';
import 'package:flutter/material.dart';

class CurrentUser {
  final int id;
  final String nombre;
  final String correo;
  final bool esAdministrador;
  final String token;
  final bool modoModeradorActivo;

  const CurrentUser({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.esAdministrador,
    required this.token,
    this.modoModeradorActivo = false,
  });

  CurrentUser copyWith({
    int? id,
    String? nombre,
    String? correo,
    bool? esAdministrador,
    String? token,
    bool? modoModeradorActivo,
  }) {
    return CurrentUser(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      esAdministrador: esAdministrador ?? this.esAdministrador,
      token: token ?? this.token,
      modoModeradorActivo: modoModeradorActivo ?? this.modoModeradorActivo,
    );
  }
}

class CategoryDef {
  final String label;
  final IconData icon;
  final String countLabel;

  const CategoryDef(this.label, this.icon, this.countLabel);
}

const List<CategoryDef> kCategories = [
  CategoryDef('Inicio', Icons.storefront_outlined, ''),
  CategoryDef('Libros y Apuntes', Icons.menu_book_outlined, '124 artículos'),
  CategoryDef('Electrónica', Icons.devices_other_outlined, '89 artículos'),
  CategoryDef('Ropa y Accesorios', Icons.checkroom_outlined, '54 artículos'),
  CategoryDef('Útiles Escolares', Icons.edit_outlined, '30 artículos'),
  CategoryDef('Transporte y Rides', Icons.directions_car_outlined, '12 ofertas activas'),
  CategoryDef('Servicios Académicos', Icons.school_outlined, '45 tutores'),
  CategoryDef('Alojamiento', Icons.apartment_outlined, '18 vacantes'),
  CategoryDef('Deportes', Icons.fitness_center_outlined, '23 artículos'),
  CategoryDef('Comida y Snacks', Icons.local_cafe_outlined, '32 opciones'),
];

class Listing {
  final String id;
  final String categoryLabel;
  final String title;
  final String price;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final String estado;
  final int? usuarioId;
  final String? vendedorNombre;

  Listing({
    required this.id,
    required this.categoryLabel,
    required this.title,
    required this.price,
    this.imageUrl,
    this.imageBytes,
    this.estado = 'activa',
    this.usuarioId,
    this.vendedorNombre,
  });

  bool get isBloqueada => estado.toLowerCase() == 'bloqueada';
  bool get isActiva => estado.toLowerCase() == 'activa';
  bool get isVendida => estado.toLowerCase() == 'vendida';
  bool get isPausada => estado.toLowerCase() == 'pausada';
}

class CartItem {
  final Listing listing;
  int quantity;

  CartItem({required this.listing, this.quantity = 1});

  double get unitPrice {
    var clean = listing.price.replaceAll(RegExp(r'[^\d.,]'), '').trim();
    if (clean.isEmpty) return 0.0;
    if (clean.contains('.') && clean.contains(',')) {
      clean = clean.replaceAll('.', '').replaceAll(',', '.');
    } else if (clean.contains('.') && clean.split('.').last.length == 3) {
      clean = clean.replaceAll('.', '');
    } else if (clean.contains(',') && clean.split(',').last.length == 3) {
      clean = clean.replaceAll(',', '');
    } else {
      clean = clean.replaceAll(',', '.');
    }
    return double.tryParse(clean) ?? 0.0;
  }

  double get total => unitPrice * quantity;
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.read = false,
  });
}

class ChatMessage {
  final int id;
  final int remitenteId;
  final String remitenteNombre;
  final int destinatarioId;
  final String contenido;
  final String fechaEnvio;
  final bool leido;
  final int? publicacionId;
  final bool esMio;

  ChatMessage({
    required this.id,
    required this.remitenteId,
    required this.remitenteNombre,
    required this.destinatarioId,
    required this.contenido,
    required this.fechaEnvio,
    required this.leido,
    this.publicacionId,
    required this.esMio,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      remitenteId: json['remitente_id'] as int,
      remitenteNombre: json['remitente_nombre'] ?? 'Usuario',
      destinatarioId: json['destinatario_id'] as int,
      contenido: json['contenido'] ?? '',
      fechaEnvio: json['fecha_envio'] ?? '',
      leido: json['leido'] ?? false,
      publicacionId: json['publicacion_id'] as int?,
      esMio: json['es_mio'] ?? false,
    );
  }
}

class ChatConversation {
  final int otroUsuarioId;
  final String otroUsuarioNombre;
  final String otroUsuarioCorreo;
  final String ultimoMensaje;
  final String fechaUltimoMensaje;
  final int mensajesNoLeidos;
  final int? publicacionId;
  final String? publicacionTitulo;

  ChatConversation({
    required this.otroUsuarioId,
    required this.otroUsuarioNombre,
    required this.otroUsuarioCorreo,
    required this.ultimoMensaje,
    required this.fechaUltimoMensaje,
    required this.mensajesNoLeidos,
    this.publicacionId,
    this.publicacionTitulo,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      otroUsuarioId: json['otro_usuario_id'] as int,
      otroUsuarioNombre: json['otro_usuario_nombre'] ?? 'Usuario',
      otroUsuarioCorreo: json['otro_usuario_correo'] ?? '',
      ultimoMensaje: json['ultimo_mensaje'] ?? '',
      fechaUltimoMensaje: json['fecha_ultimo_mensaje'] ?? '',
      mensajesNoLeidos: json['mensajes_no_leidos'] ?? 0,
      publicacionId: json['publicacion_id'] as int?,
      publicacionTitulo: json['publicacion_titulo'] as String?,
    );
  }
}
