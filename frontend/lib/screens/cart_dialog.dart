import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import 'chat_dialog.dart';
import 'login.dart';

class CartDialog extends StatefulWidget {
  const CartDialog({super.key});

  @override
  State<CartDialog> createState() => _CartDialogState();
}

class _CartDialogState extends State<CartDialog> {
  bool _isProcessing = false;

  String _formatCurrency(double amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return '\$$formatted';
  }

  Future<void> _handleCheckout(BuildContext context) async {
    // -------------------------------------------------------------
    // REGLA 2: No dejar comprar los artículos cuando no esté logueado
    // -------------------------------------------------------------
    if (!authSession.isAuthenticated) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text('Inicio de sesión requerido', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Para tu seguridad y la de la comunidad universitaria, debes iniciar sesión con tu correo institucional (@utb.edu.co) antes de comprar artículos.',
            style: TextStyle(fontSize: 13, color: kTextDark),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: kTextGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => LoginDialog(
                    onLoginSuccess: (user) {
                      authSession.setUser(user);
                    },
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: Colors.white),
              child: const Text('Iniciar Sesión Ahora'),
            ),
          ],
        ),
      );
      return;
    }

    // -------------------------------------------------------------------------------------
    // REGLA 1: Si el moderador bloqueó una publicación, no se debe comprar ese producto
    // -------------------------------------------------------------------------------------
    final blockedItem = cartState.items.where((i) => i.listing.isBloqueada).toList();
    if (blockedItem.isNotEmpty) {
      final itemTitles = blockedItem.map((i) => '• ${i.listing.title}').join('\n');
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.red, size: 28),
              SizedBox(width: 10),
              Text('Artículo bloqueado', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No se puede completar la compra porque el moderador bloqueó el siguiente producto:',
                style: TextStyle(fontSize: 13, color: kTextDark),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  itemTitles,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Por favor retira este artículo de tu carrito para poder continuar con el pedido.',
                style: TextStyle(fontSize: 12, color: kTextGrey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final vendidaItem = cartState.items.where((i) => i.listing.isVendida).toList();
    if (vendidaItem.isNotEmpty) {
      final itemTitles = vendidaItem.map((i) => '• ${i.listing.title}').join('\n');
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.inventory, color: Colors.blueGrey, size: 28),
              SizedBox(width: 10),
              Text('Artículo ya vendido', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'El siguiente producto ya fue adquirido por otro estudiante y no está disponible:',
                style: TextStyle(fontSize: 13, color: kTextDark),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Text(
                  itemTitles,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Por favor retira este producto de tu carrito para poder continuar.',
                style: TextStyle(fontSize: 12, color: kTextGrey),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    // Realizar la compra en el Backend
    setState(() => _isProcessing = true);
    final user = authSession.user!;

    try {
      final payloadItems = cartState.items.map((i) {
        return {
          'publicacion_id': int.tryParse(i.listing.id) ?? 0,
          'cantidad': i.quantity,
        };
      }).toList();

      final firstItem = cartState.items.first.listing;

      await ApiService.realizarCompra(
        token: user.token,
        items: payloadItems,
      );

      final totalItems = cartState.totalItemCount;
      cartState.clear();

      notificationState.addNotification(
        '¡Pedido Confirmado con Éxito!',
        'Se registró tu compra por $totalItems artículos. Puedes coordinar la entrega directamente por el chat interactivo.',
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.pop(context); // Cerrar CartDialog

      // Diálogo de confirmación con acceso directo al chat interactivo (Requisito 3)
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('¡Compra Registrada!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tu pedido ha sido procesado correctamente según las normas del Marketplace UTB.',
                style: TextStyle(fontSize: 13, color: kTextDark),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: kNavy, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Se ha iniciado un chat con el vendedor para acordar punto y hora de entrega en el campus.',
                        style: TextStyle(fontSize: 12, color: kNavyDark, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => ChatDialog(
                    currentUser: user,
                    initialOtherUserId: firstItem.usuarioId,
                    initialOtherUserName: firstItem.vendedorNombre ?? 'Vendedor UTB',
                    initialPublicationId: int.tryParse(firstItem.id),
                    initialPublicationTitle: firstItem.title,
                    initialPublicationPrice: firstItem.price,
                  ),
                );
              },
              icon: const Icon(Icons.chat, size: 16),
              label: const Text('Abrir Chat con el Vendedor'),
              style: ElevatedButton.styleFrom(backgroundColor: kNavy, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Text('No se pudo comprar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              '$e',
              style: const TextStyle(fontSize: 13, color: kTextDark),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartState,
      builder: (context, _) {
        final items = cartState.items;
        final total = cartState.totalPrice;
        final hasBlockedItems = items.any((i) => i.listing.isBloqueada);

        final size = MediaQuery.of(context).size;
        final isMobile = size.width < 600;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 24,
            vertical: isMobile ? 14 : 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: size.height * 0.88,
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart, color: kNavy),
                      const SizedBox(width: 8),
                      Text(
                        'Tu Carrito (${cartState.totalItemCount})',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: kTextDark,
                        ),
                      ),
                      const Spacer(),
                      if (items.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => cartState.clear(),
                          icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.red),
                          label: const Text('Vaciar', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                const Divider(),

                // Alerta de login si no está logueado
                if (!authSession.isAuthenticated && items.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Para realizar compras debes iniciar sesión con tu cuenta UTB.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => LoginDialog(
                                onLoginSuccess: (user) => authSession.setUser(user),
                              ),
                            );
                          },
                          child: const Text('Acceder', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                // Alerta si hay artículos bloqueados por moderador
                if (hasBlockedItems) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.block, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hay publicaciones bloqueadas por el moderador. No se pueden comprar; por favor elimínalas.',
                            style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.remove_shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'Tu carrito está vacío',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextDark),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Agrega productos o servicios de tus compañeros para verlos aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: kTextGrey),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final item = items[idx];
                        final isBlocked = item.listing.isBloqueada;

                        return Container(
                          color: isBlocked ? Colors.red.shade50.withOpacity(0.5) : Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: kBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: item.listing.imageUrl != null && item.listing.imageUrl!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(
                                          item.listing.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.image, color: kTextGrey),
                                        ),
                                      )
                                    : const Icon(Icons.image, color: kTextGrey),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.listing.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        decoration: isBlocked ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                    Text(
                                      item.listing.price,
                                      style: const TextStyle(color: kNavy, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      'Vendedor: ${item.listing.vendedorNombre ?? "Compañero UTB"}',
                                      style: const TextStyle(fontSize: 11, color: kTextGrey),
                                    ),
                                    if (isBlocked) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '🚫 Bloqueado por moderador (No comprable)',
                                          style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                    onPressed: isBlocked ? null : () => cartState.updateQuantity(item.listing.id, -1),
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    onPressed: isBlocked ? null : () => cartState.updateQuantity(item.listing.id, 1),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: 'Quitar del carrito',
                                onPressed: () => cartState.removeItem(item.listing.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                if (items.isNotEmpty) ...[
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total estimado:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(
                        _formatCurrency(total),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kNavy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _isProcessing ? null : () => _handleCheckout(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasBlockedItems ? Colors.grey.shade400 : kNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            hasBlockedItems
                                ? 'Corrige artículos bloqueados para comprar'
                                : (!authSession.isAuthenticated
                                    ? 'Iniciar Sesión para Comprar'
                                    : 'Finalizar Compra y Contactar Vendedor'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
  }
}
