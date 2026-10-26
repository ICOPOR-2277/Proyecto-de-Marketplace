import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/services/app_state.dart';

void main() {
  group('Validaciones de Requerimientos de Compra y Chat', () {
    test('Requerimiento 1: Listing identifica correctamente si está bloqueado por moderador', () {
      final pubActiva = Listing(
        id: '1',
        categoryLabel: 'Libros',
        title: 'Cálculo Stewart',
        price: r'$45.000',
        estado: 'activa',
      );
      expect(pubActiva.isBloqueada, isFalse);
      expect(pubActiva.isActiva, isTrue);

      final pubBloqueada = Listing(
        id: '2',
        categoryLabel: 'Electrónica',
        title: 'Celular Bloqueado',
        price: r'$500.000',
        estado: 'bloqueada',
      );
      expect(pubBloqueada.isBloqueada, isTrue);
      expect(pubBloqueada.isActiva, isFalse);
    });

    test('Requerimiento 2: AuthSession detecta si el usuario está logueado para permitir compras', () {
      final session = AuthSession();
      expect(session.isAuthenticated, isFalse);
      expect(session.user, isNull);

      session.setUser(
        const CurrentUser(
          id: 10,
          nombre: 'Juan Perez',
          correo: 'jperez@utb.edu.co',
          esAdministrador: false,
          token: 'jwt_token_fake',
        ),
      );

      expect(session.isAuthenticated, isTrue);
      expect(session.user?.nombre, equals('Juan Perez'));

      session.logout();
      expect(session.isAuthenticated, isFalse);
    });

    test('Requerimiento 3: ChatMessage y ChatConversation parsean JSON y reconocen emisor/receptor', () {
      final jsonMsg = {
        'id': 101,
        'remitente_id': 1,
        'remitente_nombre': 'Moderador UTB',
        'destinatario_id': 2,
        'contenido': 'Hola, ¿aún disponible en campus Ternera?',
        'fecha_envio': '2026-10-25T10:00:00',
        'leido': false,
        'publicacion_id': 5,
        'es_mio': true,
      };

      final msg = ChatMessage.fromJson(jsonMsg);
      expect(msg.id, equals(101));
      expect(msg.remitenteNombre, equals('Moderador UTB'));
      expect(msg.contenido, contains('campus Ternera'));
      expect(msg.esMio, isTrue);

      final jsonConv = {
        'otro_usuario_id': 2,
        'otro_usuario_nombre': 'María Vendedora',
        'otro_usuario_correo': 'mvendedora@utb.edu.co',
        'ultimo_mensaje': 'Nos vemos a las 2 en biblioteca',
        'fecha_ultimo_mensaje': '2026-10-25T11:00:00',
        'mensajes_no_leidos': 1,
        'publicacion_id': 5,
        'publicacion_titulo': 'Libro Álgebra Lineal',
      };

      final conv = ChatConversation.fromJson(jsonConv);
      expect(conv.otroUsuarioNombre, equals('María Vendedora'));
      expect(conv.mensajesNoLeidos, equals(1));
      expect(conv.publicacionTitulo, equals('Libro Álgebra Lineal'));
    });

    test('Requerimiento 4: Listing identifica correctamente estados vendida y pausada', () {
      final pubVendida = Listing(
        id: '3',
        categoryLabel: 'Electrónica',
        title: 'Calculadora HP',
        price: r'$120.000',
        estado: 'vendida',
      );
      expect(pubVendida.isVendida, isTrue);
      expect(pubVendida.isActiva, isFalse);
      expect(pubVendida.isBloqueada, isFalse);

      final pubPausada = Listing(
        id: '4',
        categoryLabel: 'Libros',
        title: 'Física Sears',
        price: r'$50.000',
        estado: 'pausada',
      );
      expect(pubPausada.isPausada, isTrue);
      expect(pubPausada.isActiva, isFalse);
    });
  });
}
