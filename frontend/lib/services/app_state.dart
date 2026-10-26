import 'package:flutter/material.dart';
import '../models/models.dart';

class AuthSession extends ChangeNotifier {
  CurrentUser? _user;

  CurrentUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isModeratorMode => _user != null && _user!.modoModeradorActivo;

  void setUser(CurrentUser user) {
    _user = user;
    notifyListeners();
  }

  void toggleModeratorMode(bool active) {
    if (_user != null && _user!.esAdministrador) {
      _user = _user!.copyWith(modoModeradorActivo: active);
      notifyListeners();
    }
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

class CartState extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalItemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double get totalPrice => _items.fold(0.0, (sum, i) => sum + i.total);

  void addItem(Listing listing) {
    final idx = _items.indexWhere((i) => i.listing.id == listing.id);
    if (idx != -1) {
      _items[idx].quantity += 1;
    } else {
      _items.add(CartItem(listing: listing, quantity: 1));
    }
    notifyListeners();
  }

  void removeItem(String listingId) {
    _items.removeWhere((i) => i.listing.id == listingId);
    notifyListeners();
  }

  void updateQuantity(String listingId, int delta) {
    final idx = _items.indexWhere((i) => i.listing.id == listingId);
    if (idx != -1) {
      final newQty = _items[idx].quantity + delta;
      if (newQty <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity = newQty;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

class NotificationState extends ChangeNotifier {
  final List<AppNotification> _notifications = [
    AppNotification(
      id: '1',
      title: '¡Bienvenido al Marketplace UTB!',
      message: 'Explora publicaciones, contacta con compañeros y publica tus propios servicios o productos.',
      time: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: '2',
      title: 'Consejo de Seguridad',
      message: 'Recuerda hacer transacciones y entregas dentro del campus universitario o puntos seguros.',
      time: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.read).length;

  void markAllAsRead() {
    for (var n in _notifications) {
      n.read = true;
    }
    notifyListeners();
  }

  void addNotification(String title, String message) {
    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        message: message,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}

final authSession = AuthSession();
final cartState = CartState();
final notificationState = NotificationState();
