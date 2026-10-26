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
  });
}
