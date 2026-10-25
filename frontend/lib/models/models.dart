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

  Listing({
    required this.id,
    required this.categoryLabel,
    required this.title,
    required this.price,
    this.imageUrl,
    this.imageBytes,
    this.estado = 'activa',
  });
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
