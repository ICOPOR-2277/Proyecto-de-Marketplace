import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/app_state.dart';

class CartDialog extends StatelessWidget {
  const CartDialog({super.key});

  String _formatCurrency(double amount) {
    final intVal = amount.round();
    final str = intVal.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return '\$$formatted';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartState,
      builder: (context, _) {
        final items = cartState.items;
        final total = cartState.totalPrice;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 580),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: kNavy),
                    const SizedBox(width: 8),
                    Text(
                      'Tu Carrito (${cartState.totalItemCount})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
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
                        return Padding(
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
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      item.listing.price,
                                      style: const TextStyle(color: kNavy, fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                                    onPressed: () => cartState.updateQuantity(item.listing.id, -1),
                                  ),
                                  Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 18),
                                    onPressed: () => cartState.updateQuantity(item.listing.id, 1),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
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
                    onPressed: () {
                      Navigator.pop(context);
                      notificationState.addNotification(
                        '¡Pedido Iniciado!',
                        'Se ha guardado tu interés por ${cartState.totalItemCount} artículos. Coordina el pago con los vendedores.',
                      );
                      cartState.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('¡Pedido enviado! Revisa tus notificaciones y contacta al vendedor.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Contactar y Finalizar Pedido', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
