import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'constants/colors.dart';
import 'models/models.dart';
import 'services/api_service.dart';
import 'services/app_state.dart';
import 'screens/cart_dialog.dart';
import 'screens/notifications_dialog.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const UtbMarketApp());
}

/// Estado global de autenticación en la app
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

final authSession = AuthSession();

class UtbMarketApp extends StatelessWidget {
  const UtbMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authSession,
      builder: (context, _) {
        return MaterialApp(
          title: 'UTB Market',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: kUtbBluePrimary,
              primary: kUtbBluePrimary,
              secondary: kUtbAccentYellow,
              surface: kUtbWhite,
            ),
            scaffoldBackgroundColor: kUtbBgLight,
            fontFamily: 'Roboto',
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: kUtbBorder),
              ),
              color: kUtbWhite,
            ),
          ),
          home: const UtbMarketHomePage(),
        );
      },
    );
  }
}

/// -------------------------------------------------------------------------
/// Pantalla principal: TabBar con "Inicio" + pestañas por categoría.
/// -------------------------------------------------------------------------
class UtbMarketHomePage extends StatefulWidget {
  const UtbMarketHomePage({super.key});

  @override
  State<UtbMarketHomePage> createState() => _UtbMarketHomePageState();
}

class _UtbMarketHomePageState extends State<UtbMarketHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  final Map<String, List<Listing>> _listingsByCategory = {
    for (final c in kCategories.skip(1)) c.label: <Listing>[],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kCategories.length, vsync: this);
    _loadListingsFromBackend();
  }

  Future<void> _loadListingsFromBackend() async {
    try {
      final items = await ApiService.fetchListings();
      if (!mounted) return;
      setState(() {
        for (final item in items) {
          if (_listingsByCategory.containsKey(item.categoryLabel)) {
            if (!_listingsByCategory[item.categoryLabel]!.any((l) => l.id == item.id)) {
              _listingsByCategory[item.categoryLabel]!.add(item);
            }
          }
        }
      });
    } catch (_) {
      // Backend desconectado o error silencioso
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _goToCategory(String label) {
    final index = kCategories.indexWhere((c) => c.label == label);
    if (index != -1) _tabController.animateTo(index);
  }

  void _addListing(String category, Listing listing) {
    setState(() {
      _listingsByCategory[category]?.insert(0, listing);
    });
  }

  void _handleSearch(String query) {
    if (query.trim().isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SearchResultsPage(query: query.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            _MainHeader(onSearch: _handleSearch),
            _CategoryNav(tabController: _tabController, onTap: _goToCategory),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _HomeTab(
                    onCategoryTap: _goToCategory,
                    listingsByCategory: _listingsByCategory,
                  ),
                  for (final category in kCategories.skip(1))
                    _CategoryTab(
                      category: category,
                      listings: _listingsByCategory[category.label] ?? [],
                      onListingCreated: (listing) => _addListing(category.label, listing),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Barra superior institucional con Login/Usuario, Notificaciones y Carrito
/// -------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar();

  void _openAuthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => LoginDialog(
        onLoginSuccess: (user) {
          authSession.setUser(user);
          if (user.esAdministrador) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => _RoleSelectionDialog(user: user),
            );
          }
        },
      ),
    );
  }

  void _openRoleSelectionModal(BuildContext context, CurrentUser user) {
    showDialog(
      context: context,
      builder: (_) => _RoleSelectionDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: authSession,
      builder: (context, _) {
        final user = authSession.user;

        return Container(
          color: kNavyDark,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              const Text('Enviar a Cartagena, Campus Ternera',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              if (user != null) ...[
                Text('¡Hola, ${user.nombre.split(" ").first}!',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                if (user.esAdministrador) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      if (user.modoModeradorActivo) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ModeratorDashboardPage(token: user.token),
                          ),
                        );
                      } else {
                        _openRoleSelectionModal(context, user);
                      }
                    },
                    icon: const Icon(Icons.dashboard_outlined, size: 14),
                    label: Text(
                      user.modoModeradorActivo ? 'Dashboard Moderador' : 'Cambiar Rol',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kYellow,
                      foregroundColor: kNavyDark,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                  tooltip: 'Cerrar Sesión',
                  onPressed: () => authSession.logout(),
                ),
              ] else ...[
                TextButton.icon(
                  onPressed: () => _openAuthDialog(context),
                  icon: const Icon(Icons.person_outline, color: Colors.white, size: 16),
                  label: const Text('Iniciar Sesión',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
              const SizedBox(width: 8),

              // Botón Notificaciones con insignia activa
              AnimatedBuilder(
                animation: notificationState,
                builder: (context, _) {
                  final unread = notificationState.unreadCount;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                        tooltip: 'Notificaciones',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const NotificationsDialog(),
                          );
                        },
                      ),
                      if (unread > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$unread',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(width: 14),

              // Botón Carrito con contador
              AnimatedBuilder(
                animation: cartState,
                builder: (context, _) {
                  final count = cartState.totalItemCount;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                        tooltip: 'Carrito de compras',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const CartDialog(),
                          );
                        },
                      ),
                      if (count > 0)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: kYellow,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: kNavyDark, fontSize: 9, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// -------------------------------------------------------------------------
/// Modal para seleccionar si entra como Usuario o Moderador
/// -------------------------------------------------------------------------
class _RoleSelectionDialog extends StatelessWidget {
  final CurrentUser user;
  const _RoleSelectionDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.security, size: 48, color: kUtbBluePrimary),
            const SizedBox(height: 12),
            const Text(
              'Elige tu modo de acceso',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Hola ${user.nombre}, tu cuenta cuenta con privilegios de Moderador institucional. ¿Cómo deseas ingresar hoy?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kTextGrey),
            ),
            const SizedBox(height: 24),
            // Opción Modo Usuario
            InkWell(
              onTap: () {
                authSession.toggleModeratorMode(false);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresaste en modo Usuario / Estudiante')),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: kCardBorder),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kBg,
                      child: Icon(Icons.school, color: kNavy),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entrar como Usuario / Estudiante',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextDark)),
                          Text('Explora servicios, compra y publica tus artículos normalmente.',
                              style: TextStyle(fontSize: 11, color: kTextGrey)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: kTextGrey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Opción Modo Moderador
            InkWell(
              onTap: () {
                authSession.toggleModeratorMode(true);
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ModeratorDashboardPage(token: user.token)),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: kYellow, width: 2),
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFFFFBEB),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kYellow,
                      child: Icon(Icons.admin_panel_settings, color: kNavyDark),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entrar como Moderador',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kNavyDark)),
                          Text('Acceso completo al Dashboard, monitoreo de publicaciones y control de usuarios.',
                              style: TextStyle(fontSize: 11, color: kTextGrey)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: kNavyDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Logo institucional oficial UTB + buscador funcional tolerante a errores
/// -------------------------------------------------------------------------
class _MainHeader extends StatefulWidget {
  final void Function(String query) onSearch;
  const _MainHeader({required this.onSearch});

  @override
  State<_MainHeader> createState() => _MainHeaderState();
}

class _MainHeaderState extends State<_MainHeader> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    final q = _searchController.text.trim();
    if (q.isNotEmpty) widget.onSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kNavy,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.asset(
              'assets/images/utb_logo.png',
              height: 34,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(color: kYellow, borderRadius: BorderRadius.circular(6)),
                    alignment: Alignment.center,
                    child: const Text('UTB',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: kNavy)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('UTB Market',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Mercado Estudiantil', style: TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        hintText: 'Buscar libros, apuntes, cálculo, transporte...',
                        hintStyle: TextStyle(fontSize: 13, color: kTextGrey),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: kYellow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.search, color: kNavyDark, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Barra de navegación horizontal de categorías
/// -------------------------------------------------------------------------
class _CategoryNav extends StatelessWidget {
  final TabController tabController;
  final void Function(String label) onTap;

  const _CategoryNav({required this.tabController, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        labelColor: kNavy,
        unselectedLabelColor: kTextGrey,
        indicatorColor: kYellow,
        indicatorWeight: 3,
        tabAlignment: TabAlignment.start,
        tabs: [
          for (final c in kCategories)
            Tab(
              icon: Icon(c.icon, size: 18),
              text: c.label,
              iconMargin: const EdgeInsets.only(bottom: 2),
            ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Pestaña "Inicio"
/// -------------------------------------------------------------------------
class _HomeTab extends StatelessWidget {
  final void Function(String label) onCategoryTap;
  final Map<String, List<Listing>> listingsByCategory;

  const _HomeTab({
    required this.onCategoryTap,
    required this.listingsByCategory,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _HeroBanner(onExplore: () => onCategoryTap('Libros y Apuntes')),
        const SizedBox(height: 20),
        const Text(
          'Categorías Destacadas',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final category in kCategories.skip(1))
              _CategoryCard(
                category: category,
                itemCount: (listingsByCategory[category.label] ?? []).length,
                onTap: () => onCategoryTap(category.label),
              ),
          ],
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  final VoidCallback onExplore;
  const _HeroBanner({required this.onExplore});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [kNavy, kNavyDark]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kYellow, borderRadius: BorderRadius.circular(4)),
              child: const Text('¡Temporada de Parciales UTB!',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kNavy)),
            ),
            const SizedBox(height: 12),
            const Text('Libros, Apuntes y Tutorías\ncon hasta 50% OFF',
                style: TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.15)),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onExplore,
              style: ElevatedButton.styleFrom(
                backgroundColor: kYellow,
                foregroundColor: kNavy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Explorar Servicios', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryDef category;
  final int itemCount;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.itemCount,
    required this.onTap,
  });

  String _getCountText() {
    if (itemCount == 0) return 'Sin artículos';
    if (itemCount == 1) return '1 artículo';
    return '$itemCount artículos';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 165,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: kBg, shape: BoxShape.circle),
              child: Icon(category.icon, size: 18, color: kNavy),
            ),
            const SizedBox(height: 10),
            Text(category.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
            const SizedBox(height: 2),
            Text(_getCountText(), style: const TextStyle(fontSize: 11, color: kTextGrey)),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Pestaña de una categoría específica
/// -------------------------------------------------------------------------
class _CategoryTab extends StatelessWidget {
  final CategoryDef category;
  final List<Listing> listings;
  final void Function(Listing listing) onListingCreated;

  const _CategoryTab({
    required this.category,
    required this.listings,
    required this.onListingCreated,
  });

  void _openAddListingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddListingSheet(
        category: category,
        onCreated: onListingCreated,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddListingSheet(context),
        backgroundColor: kYellow,
        foregroundColor: kNavy,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Publicar artículo', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: listings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(category.icon, size: 56, color: kTextGrey.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    Text('Aún no hay publicaciones en ${category.label}',
                        style: const TextStyle(color: kTextDark, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Sé el primero en compartir un artículo o servicio con tu comunidad.',
                        style: TextStyle(color: kTextGrey, fontSize: 13), textAlign: TextAlign.center),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisExtent: 260,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) {
                return _ListingCard(listing: listings[index]);
              },
            ),
    );
  }
}

class _ListingCard extends StatelessWidget {
  final Listing listing;
  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildImage()),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      listing.price,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kNavy),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_shopping_cart, size: 18, color: kNavy),
                      tooltip: 'Agregar al carrito',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        cartState.addItem(listing);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${listing.title}" agregado al carrito'),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: 'Ver Carrito',
                              textColor: kYellow,
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => const CartDialog(),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (listing.imageUrl != null && listing.imageUrl!.isNotEmpty) {
      return Image.network(
        listing.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (listing.imageBytes != null) {
      return Image.memory(listing.imageBytes!, fit: BoxFit.cover, width: double.infinity);
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: kBg,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: kTextGrey, size: 32),
      );
}

/// -------------------------------------------------------------------------
/// Formulario para publicar un artículo
/// -------------------------------------------------------------------------
class _AddListingSheet extends StatefulWidget {
  final CategoryDef category;
  final void Function(Listing listing) onCreated;

  const _AddListingSheet({required this.category, required this.onCreated});

  @override
  State<_AddListingSheet> createState() => _AddListingSheetState();
}

class _AddListingSheetState extends State<_AddListingSheet> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  XFile? _pickedFile;
  bool _uploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _pickedFile = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final price = _priceController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor escribe un título')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      String imageUrl = '';
      if (_pickedFile != null) {
        imageUrl = await ApiService.uploadImage(_pickedFile!);
      }

      final created = await ApiService.createListing(
        category: widget.category.label,
        title: title,
        price: price.isEmpty ? 'Gratis' : price,
        imageUrl: imageUrl,
      );

      widget.onCreated(created);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Publicar en ${widget.category.label}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título del artículo o servicio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Precio (ej: \$25.000 o Gratis)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  border: Border.all(color: kCardBorder, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(8),
                  color: kBg,
                ),
                alignment: Alignment.center,
                child: _pickedFile != null
                  ? Text('Imagen seleccionada: ${_pickedFile!.name}',
                      style: const TextStyle(color: kNavy, fontWeight: FontWeight.bold))
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, size: 36, color: kTextGrey),
                        SizedBox(height: 6),
                        Text('Seleccionar foto', style: TextStyle(color: kTextGrey)),
                      ],
                    ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Publicar Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Pantalla de resultados de búsqueda inteligente / flexible
/// -------------------------------------------------------------------------
class _SearchResultsPage extends StatefulWidget {
  final String query;
  const _SearchResultsPage({required this.query});

  @override
  State<_SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<_SearchResultsPage> {
  List<Listing> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    try {
      final results = await ApiService.searchListings(widget.query);
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        title: Text('Resultados para: "${widget.query}"',
            style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      backgroundColor: kBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: kTextGrey),
                        const SizedBox(height: 12),
                        Text(
                          'No se encontraron coincidencias para "${widget.query}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kTextGrey, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final listing = _results[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kCardBorder),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: kBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: listing.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      listing.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image_outlined, color: kTextGrey),
                                    ),
                                  )
                                : const Icon(Icons.image_outlined, color: kTextGrey),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: kTextDark),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  listing.categoryLabel,
                                  style: const TextStyle(fontSize: 12, color: kTextGrey),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            listing.price,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14, color: kNavy),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
