import 'dart:async';

import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_service.dart';

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
    final before = _items.length;
    _items.removeWhere((i) => i.listing.id == listingId);
    if (_items.length != before) notifyListeners();
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

  /// Reconcilia el carrito con el catálogo vigente del servidor:
  /// - quita los artículos que ya no existen (eliminados por moderador o vendedor),
  /// - actualiza el estado/precio de los que cambiaron (bloqueada, vendida, pausada...).
  ///
  /// Solo debe llamarse con una respuesta exitosa del servidor.
  void syncWithCatalog(Iterable<Listing> catalog) {
    if (_items.isEmpty) return;
    final byId = {for (final l in catalog) l.id: l};
    var changed = false;
    for (var i = _items.length - 1; i >= 0; i--) {
      final current = _items[i];
      final fresh = byId[current.listing.id];
      if (fresh == null) {
        _items.removeAt(i);
        changed = true;
      } else if (fresh.estado != current.listing.estado ||
          fresh.price != current.listing.price ||
          fresh.title != current.listing.title) {
        _items[i] = CartItem(listing: fresh, quantity: current.quantity);
        changed = true;
      }
    }
    if (changed) notifyListeners();
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
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        message: message,
        time: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}

/// -------------------------------------------------------------------------
/// Notificador global del catálogo.
///
/// Cualquier pantalla que elimine o cambie el estado de una publicación
/// (Dashboard del moderador, "Mis Publicaciones", etc.) lo invoca y la
/// pantalla principal recarga el catálogo de inmediato, sin requerir F5.
/// -------------------------------------------------------------------------
class CatalogState extends ChangeNotifier {
  final Set<String> _pendingRemovedIds = {};
  int _version = 0;

  /// Contador que aumenta con cada solicitud de recarga.
  int get version => _version;

  /// Devuelve (y limpia) los IDs eliminados pendientes de quitar localmente.
  Set<String> takeRemovedIds() {
    final ids = Set<String>.from(_pendingRemovedIds);
    _pendingRemovedIds.clear();
    return ids;
  }

  /// Solicita recargar el catálogo desde el servidor.
  void requestRefresh() {
    _version++;
    notifyListeners();
  }

  /// Una publicación fue eliminada: se quita del carrito y de la vista al instante.
  void listingRemoved(Object id) {
    final key = id.toString();
    _pendingRemovedIds.add(key);
    cartState.removeItem(key);
    requestRefresh();
  }

  /// Una publicación cambió de estado (bloqueada, pausada, vendida, activa...).
  void listingChanged([Object? id]) => requestRefresh();
}

/// Evento emitido cuando llega un mensaje nuevo en algún hilo de chat.
class IncomingChatEvent {
  final ChatConversation conversation;
  const IncomingChatEvent(this.conversation);
}

/// -------------------------------------------------------------------------
/// Servicio de sincronización de chat en segundo plano.
///
/// Mientras haya sesión iniciada consulta periódicamente las conversaciones
/// para mantener [unreadChatCount] y detectar mensajes entrantes nuevos
/// (ignorando la carga inicial tras el login para no notificar mensajes viejos).
/// -------------------------------------------------------------------------
class ChatSyncService extends ChangeNotifier {
  ChatSyncService(this._auth, {this.interval = const Duration(seconds: 4)}) {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthSession _auth;
  final Duration interval;

  Timer? _timer;
  bool _polling = false;
  bool _baselineLoaded = false;
  String? _sessionToken;
  int _unreadChatCount = 0;
  List<ChatConversation> _conversations = const [];

  /// threadKey -> (último id de mensaje, no leídos) del ciclo anterior.
  final Map<String, ({int? lastId, int unread})> _snapshot = {};

  final StreamController<IncomingChatEvent> _incoming =
      StreamController<IncomingChatEvent>.broadcast();

  /// Hilo que el usuario tiene abierto en este momento (no se notifica).
  String? activeThreadKey;

  int get unreadChatCount => _unreadChatCount;
  List<ChatConversation> get conversations => List.unmodifiable(_conversations);
  Stream<IncomingChatEvent> get incomingMessages => _incoming.stream;

  void _onAuthChanged() {
    final token = _auth.user?.token;
    if (token == _sessionToken) return;
    _sessionToken = token;
    _stop();
    if (token != null) {
      _timer = Timer.periodic(interval, (_) => refreshNow());
      refreshNow();
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _snapshot.clear();
    _baselineLoaded = false;
    activeThreadKey = null;
    final hadData = _unreadChatCount != 0 || _conversations.isNotEmpty;
    _unreadChatCount = 0;
    _conversations = const [];
    if (hadData) notifyListeners();
  }

  /// Fuerza una consulta inmediata (por ejemplo, tras leer un hilo).
  Future<void> refreshNow() async {
    final token = _sessionToken;
    if (token == null || _polling) return;
    _polling = true;
    try {
      final convs = await ApiService.fetchConversations(token);
      // La sesión pudo cambiar mientras esperábamos la respuesta.
      if (token != _sessionToken) return;
      // Una respuesta vacía tras tener hilos suele ser un error transitorio
      // (token vencido, red): no se pisa el estado para no generar avisos falsos.
      if (convs.isEmpty && _snapshot.isNotEmpty) return;
      _apply(convs);
    } catch (_) {
      // Error de red silencioso; se reintenta en el siguiente ciclo.
    } finally {
      _polling = false;
    }
  }

  void _apply(List<ChatConversation> convs) {
    final events = <IncomingChatEvent>[];
    if (_baselineLoaded) {
      for (final c in convs) {
        final prev = _snapshot[c.threadKey];
        final isNewThread = prev == null;
        final lastIdChanged = prev != null && c.ultimoMensajeId != prev.lastId;
        final unreadGrew = c.mensajesNoLeidos > (prev?.unread ?? 0);
        if (c.mensajesNoLeidos > 0 &&
            unreadGrew &&
            (isNewThread || lastIdChanged) &&
            c.threadKey != activeThreadKey) {
          events.add(IncomingChatEvent(c));
        }
      }
    }

    _snapshot
      ..clear()
      ..addEntries(convs.map(
        (c) => MapEntry(c.threadKey, (lastId: c.ultimoMensajeId, unread: c.mensajesNoLeidos)),
      ));
    _baselineLoaded = true;

    final newUnread = convs.fold<int>(0, (sum, c) => sum + c.mensajesNoLeidos);
    _conversations = convs;
    _unreadChatCount = newUnread;
    notifyListeners();

    for (final e in events) {
      final c = e.conversation;
      final sobre = c.publicacionTitulo != null ? ' sobre "${c.publicacionTitulo}"' : '';
      notificationState.addNotification(
        'Nuevo mensaje de ${c.otroUsuarioNombre}',
        '${c.ultimoMensaje}$sobre',
      );
      _incoming.add(e);
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _timer?.cancel();
    _incoming.close();
    super.dispose();
  }
}

final authSession = AuthSession();
final cartState = CartState();
final notificationState = NotificationState();
final catalogState = CatalogState();

/// Se crea de forma perezosa la primera vez que se usa (desde la pantalla principal).
final chatSyncService = ChatSyncService(authSession);
