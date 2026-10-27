import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';

class MyListingsDialog extends StatefulWidget {
  final String token;
  final VoidCallback? onListingChanged;

  const MyListingsDialog({
    super.key,
    required this.token,
    this.onListingChanged,
  });

  @override
  State<MyListingsDialog> createState() => _MyListingsDialogState();
}

class _MyListingsDialogState extends State<MyListingsDialog> {
  late Future<List<Listing>> _futureListings;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  void _loadListings() {
    setState(() {
      _futureListings = ApiService.fetchMisPublicaciones(widget.token);
    });
  }

  Future<void> _cambiarEstado(Listing listing, String nuevoEstado) async {
    final idInt = int.tryParse(listing.id);
    if (idInt == null) return;

    setState(() => _isProcessing = true);
    try {
      await ApiService.updateMiPublicacionEstado(widget.token, idInt, nuevoEstado);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publicación marcada como "$nuevoEstado"'),
            backgroundColor: kUtbBluePrimary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      catalogState.listingChanged(idInt);
      widget.onListingChanged?.call();
      _loadListings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmarEliminar(Listing listing) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Eliminar Publicación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('¿Estás seguro de que deseas eliminar permanentemente "${listing.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    final idInt = int.tryParse(listing.id);
    if (idInt == null) return;

    setState(() => _isProcessing = true);
    try {
      await ApiService.deleteMiPublicacion(widget.token, idInt);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publicación "${listing.title}" eliminada'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      catalogState.listingRemoved(idInt);
      widget.onListingChanged?.call();
      _loadListings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Color _badgeColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activa':
        return Colors.green.shade600;
      case 'vendida':
        return Colors.blueGrey;
      case 'pausada':
        return Colors.orange.shade800;
      case 'bloqueada':
        return Colors.red.shade600;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 650;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 14 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 750,
          maxHeight: size.height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kUtbBluePrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, color: kUtbBluePrimary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis Publicaciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kUtbBlueDark,
                          ),
                        ),
                        Text(
                          'Gestiona tus artículos, cámbialos a vendidos o paúsalos',
                          style: TextStyle(fontSize: 11, color: kTextGrey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: kUtbBluePrimary),
                    tooltip: 'Recargar',
                    onPressed: _isProcessing ? null : _loadListings,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Content
              Expanded(
                child: FutureBuilder<List<Listing>>(
                  future: _futureListings,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 12),
                            Text('Error al cargar publicaciones:\n${snapshot.error}', textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _loadListings,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }

                    final listings = snapshot.data ?? [];
                    if (listings.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'Aún no has publicado ningún artículo o servicio.',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextDark),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Usa el botón "+ Publicar" en la barra superior para ofertar a tus compañeros.',
                                style: TextStyle(fontSize: 13, color: kTextGrey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: listings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final listing = listings[index];
                        final badgeCol = _badgeColor(listing.estado);

                        final imageWidget = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: isMobile ? 50 : 60,
                            height: isMobile ? 50 : 60,
                            color: kUtbBgLight,
                            child: listing.imageUrl != null && listing.imageUrl!.isNotEmpty
                                ? Image.network(
                                    listing.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                                  )
                                : const Icon(Icons.shopping_bag_outlined, color: kUtbBluePrimary),
                          ),
                        );

                        final infoWidget = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    listing.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isMobile ? 13 : 14,
                                      color: kTextDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeCol.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: badgeCol.withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    listing.estado.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: badgeCol,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${listing.categoryLabel} • ${listing.price}',
                              style: const TextStyle(
                                color: kUtbBluePrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );

                        final actionsWidget = Row(
                          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                          mainAxisAlignment: isMobile ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (listing.isActiva) ...[
                              IconButton(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.teal, size: 20),
                                tooltip: 'Marcar como Vendido',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: _isProcessing ? null : () => _cambiarEstado(listing, 'vendida'),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.pause_circle_outline, color: Colors.orange, size: 20),
                                tooltip: 'Pausar publicación',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: _isProcessing ? null : () => _cambiarEstado(listing, 'pausada'),
                              ),
                            ] else if (listing.isVendida || listing.isPausada) ...[
                              IconButton(
                                icon: const Icon(Icons.play_circle_outline, color: Colors.green, size: 20),
                                tooltip: 'Reactivar en catálogo',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: _isProcessing ? null : () => _cambiarEstado(listing, 'activa'),
                              ),
                            ],
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              tooltip: 'Eliminar',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: _isProcessing ? null : () => _confirmarEliminar(listing),
                            ),
                          ],
                        );

                        return Container(
                          padding: EdgeInsets.all(isMobile ? 10 : 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: kCardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isMobile
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        imageWidget,
                                        const SizedBox(width: 10),
                                        Expanded(child: infoWidget),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    actionsWidget,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    imageWidget,
                                    const SizedBox(width: 14),
                                    Expanded(child: infoWidget),
                                    const SizedBox(width: 12),
                                    actionsWidget,
                                  ],
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
