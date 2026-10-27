import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/services/app_state.dart';

void main() {
  group('Pruebas Unitarias de Modelos y Carrito', () {
    test('CartItem parsea correctamente precios en formato colombiano', () {
      final item1 = CartItem(
        listing: Listing(
          id: '1',
          categoryLabel: 'Libros y Apuntes',
          title: 'Libro Stewart',
          price: '\$65.000',
        ),
        quantity: 2,
      );

      expect(item1.unitPrice, 65000.0);
      expect(item1.total, 130000.0);

      final item2 = CartItem(
        listing: Listing(
          id: '2',
          categoryLabel: 'Libros y Apuntes',
          title: 'Resumen Álgebra',
          price: '\$15.000',
        ),
        quantity: 1,
      );

      expect(item2.unitPrice, 15000.0);
      expect(item2.total, 15000.0);
    });

    test('CartState gestiona agregar, actualizar y vaciar productos', () {
      final cart = CartState();
      final listing = Listing(
        id: '10',
        categoryLabel: 'Electrónica',
        title: 'Arduino Mega',
        price: '\$85.000',
      );

      cart.addItem(listing);
      expect(cart.totalItemCount, 1);
      expect(cart.totalPrice, 85000.0);

      cart.updateQuantity('10', 1);
      expect(cart.totalItemCount, 2);
      expect(cart.totalPrice, 170000.0);

      cart.clear();
      expect(cart.totalItemCount, 0);
      expect(cart.totalPrice, 0.0);
    });

    test('NotificationState agrega y marca notificaciones como leídas', () {
      final notifState = NotificationState();
      final initialUnread = notifState.unreadCount;

      notifState.addNotification('Prueba', 'Mensaje de prueba');
      expect(notifState.unreadCount, initialUnread + 1);

      notifState.markAllAsRead();
      expect(notifState.unreadCount, 0);
    });

    test('CartState.syncWithCatalog reconcilia artículos eliminados y actualizados', () {
      final cart = CartState();
      final item1 = Listing(
        id: '1',
        categoryLabel: 'Libros y Apuntes',
        title: 'Cálculo Stewart',
        price: r'$50.000',
        estado: 'activa',
      );
      final item2 = Listing(
        id: '2',
        categoryLabel: 'Electrónica',
        title: 'Mouse Logitech',
        price: r'$30.000',
        estado: 'activa',
      );

      cart.addItem(item1);
      cart.addItem(item2);
      expect(cart.totalItemCount, 2);

      // Si el item2 fue eliminado del catálogo por el moderador:
      // solo el item1 sigue en el catálogo, pero ahora bloqueado:
      final updatedCatalog = <Listing>[
        item1.copyWith(estado: 'bloqueada'),
      ];

      cart.syncWithCatalog(updatedCatalog);

      expect(cart.items.length, 1);
      expect(cart.items.first.listing.id, '1');
      expect(cart.items.first.listing.isBloqueada, isTrue);
    });

    test('CatalogState notifica y acumula IDs eliminados para sincronización inmediata', () {
      final catalogState = CatalogState();
      var notified = false;
      catalogState.addListener(() => notified = true);

      catalogState.listingRemoved('99');
      expect(notified, isTrue);

      final removed = catalogState.takeRemovedIds();
      expect(removed, contains('99'));

      // Verificar que takeRemovedIds vacía la cola
      final empty = catalogState.takeRemovedIds();
      expect(empty, isEmpty);
    });

    test('ChatConversation modela llaves compuestas independientes por publicación', () {
      final jsonConv1 = {
        'otro_usuario_id': 5,
        'otro_usuario_nombre': 'Carlos',
        'otro_usuario_correo': 'carlos@utb.edu.co',
        'ultimo_mensaje': 'Sigue disponible el libro?',
        'fecha_ultimo_mensaje': '2026-10-27T10:00:00',
        'mensajes_no_leidos': 2,
        'publicacion_id': 12,
        'publicacion_titulo': 'Cálculo Stewart',
        'precio': 45000.0,
        'estado': 'activa',
      };
      final conv1 = ChatConversation.fromJson(jsonConv1);

      expect(conv1.threadKey, equals('5:12'));
      expect(conv1.precioFormateado, contains('45.000'));
      expect(conv1.isPublicacionBloqueada, isFalse);

      final jsonConv2 = {
        'otro_usuario_id': 5,
        'otro_usuario_nombre': 'Carlos',
        'otro_usuario_correo': 'carlos@utb.edu.co',
        'ultimo_mensaje': 'Hola Carlos, cómo estás?',
        'fecha_ultimo_mensaje': '2026-10-27T10:05:00',
        'mensajes_no_leidos': 0,
        'publicacion_id': null,
      };
      final conv2 = ChatConversation.fromJson(jsonConv2);
      expect(conv2.threadKey, equals('5:general'));
    });
  });
}
