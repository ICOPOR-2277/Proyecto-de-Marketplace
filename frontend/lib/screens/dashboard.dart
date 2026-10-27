import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';

class ModeratorDashboardPage extends StatefulWidget {
  final String? token;
  const ModeratorDashboardPage({super.key, this.token});

  @override
  State<ModeratorDashboardPage> createState() => _ModeratorDashboardPageState();
}

class _ModeratorDashboardPageState extends State<ModeratorDashboardPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _stats;
  List<dynamic> _listings = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final token = widget.token;
    if (token == null) {
      setState(() {
        _error = 'Sesión no válida o sin permisos';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await ApiService.fetchModeratorStats(token);
      final listings = await ApiService.fetchModeratorListings(token);
      if (mounted) {
        setState(() {
          _stats = stats;
          _listings = listings;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _changeStatus(int id, String nuevoEstado) async {
    final token = widget.token;
    if (token == null) return;
    try {
      await ApiService.updateListingStatus(token, id, nuevoEstado);
      if (nuevoEstado == 'eliminada') {
        catalogState.listingRemoved(id);
      } else {
        catalogState.listingChanged(id);
      }
      _loadDashboardData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _delete(int id) async {
    final token = widget.token;
    if (token == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar publicación?'),
        content: const Text('Esta acción eliminará el artículo permanentemente del marketplace.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteListing(token, id);
        catalogState.listingRemoved(id);
        _loadDashboardData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 650;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: kYellow),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Panel de Moderación UTB',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: kNavyDark,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar datos',
            onPressed: _loadDashboardData,
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isMobile ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tarjetas de Métricas responsivas
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildStatCard(
                            title: 'Total Publicaciones',
                            value: '${_stats?['total_publicaciones'] ?? 0}',
                            icon: Icons.list_alt,
                            color: kNavy,
                            isMobile: isMobile,
                          ),
                          _buildStatCard(
                            title: 'Publicaciones Activas',
                            value: '${_stats?['publicaciones_activas'] ?? 0}',
                            icon: Icons.check_circle_outline,
                            color: Colors.green,
                            isMobile: isMobile,
                          ),
                          _buildStatCard(
                            title: 'Bloqueadas / Pausadas',
                            value: '${_stats?['publicaciones_bloqueadas'] ?? 0}',
                            icon: Icons.block,
                            color: Colors.red,
                            isMobile: isMobile,
                          ),
                          _buildStatCard(
                            title: 'Usuarios Registrados',
                            value: '${_stats?['total_usuarios'] ?? 0}',
                            icon: Icons.people_outline,
                            color: Colors.blueGrey,
                            isMobile: isMobile,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Monitoreo de Publicaciones en Tiempo Real',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: kTextDark),
                      ),
                      const SizedBox(height: 12),
                      if (_listings.isEmpty)
                        const Text('No hay publicaciones registradas.')
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _listings.length,
                          itemBuilder: (context, idx) {
                            final item = _listings[idx];
                            final id = item['id'] as int;
                            final estado = item['estado'] as String;
                            final isBloqueada = estado == 'bloqueada';

                            final imageWidget = Container(
                              width: isMobile ? 52 : 60,
                              height: isMobile ? 52 : 60,
                              decoration: BoxDecoration(
                                color: kBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: item['imagen_url'] != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        item['imagen_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.image, color: kTextGrey),
                                      ),
                                    )
                                  : const Icon(Icons.image, color: kTextGrey),
                            );

                            final infoWidget = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['titulo'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 14 : 15,
                                          color: kTextDark,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isBloqueada ? Colors.red.shade50 : Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isBloqueada ? Colors.red.shade300 : Colors.green.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        estado.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isBloqueada ? Colors.red : Colors.green,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item['categoria']} • ${item['usuario_nombre'] ?? 'Anónimo'}',
                                  style: const TextStyle(fontSize: 11, color: kTextGrey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Precio: \$${item['precio'] ?? 0}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: kNavy,
                                  ),
                                ),
                              ],
                            );

                            final actionsWidget = Row(
                              mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                              mainAxisAlignment: isMobile ? MainAxisAlignment.end : MainAxisAlignment.start,
                              children: [
                                if (isBloqueada)
                                  ElevatedButton.icon(
                                    onPressed: () => _changeStatus(id, 'activa'),
                                    icon: const Icon(Icons.check, size: 14),
                                    label: const Text('Reactivar', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () => _changeStatus(id, 'bloqueada'),
                                    icon: const Icon(Icons.block, size: 14),
                                    label: const Text('Bloquear', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade800,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      minimumSize: Size.zero,
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: 'Eliminar permanentemente',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _delete(id),
                                )
                              ],
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: EdgeInsets.all(isMobile ? 12 : 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isBloqueada ? Colors.red.shade300 : kCardBorder,
                                ),
                              ),
                              child: isMobile
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            imageWidget,
                                            const SizedBox(width: 12),
                                            Expanded(child: infoWidget),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1),
                                        const SizedBox(height: 6),
                                        actionsWidget,
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        imageWidget,
                                        const SizedBox(width: 14),
                                        Expanded(child: infoWidget),
                                        const SizedBox(width: 12),
                                        Column(children: [actionsWidget]),
                                      ],
                                    ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      width: isMobile ? double.infinity : 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kCardBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kTextGrey),
                ),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
