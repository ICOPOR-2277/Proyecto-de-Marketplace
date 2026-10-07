import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const UtbMarketApp());
}

class UtbMarketApp extends StatelessWidget {
  const UtbMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTB Market',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kNavy),
        useMaterial3: true,
      ),
      home: const UtbMarketHomePage(),
    );
  }
}

/// ============================================================================
/// UTB Market — pantalla de inicio interactiva
/// ============================================================================
/// Cambios respecto a la versión anterior:
/// 1) Todas las categorías (barra de navegación, tarjetas "Categorías
///    destacadas") ahora son botones reales que cambian de pestaña (TabBar).
/// 2) Cada pestaña de categoría permite a CUALQUIER usuario publicar un
///    artículo con su propia imagen (cámara o galería), sin que el
///    programador tenga que agregarla a mano. La imagen se sube a un backend
///    mediante [ApiService] (ver TODO más abajo: el backend aún no existe,
///    así que hay un modo "local" de respaldo para que la app funcione ya).
///
/// Dependencias que debes agregar en pubspec.yaml:
///   dependencies:
///     image_picker: ^1.1.2
///     http: ^1.2.2
///
/// Cuando tengas el backend FastAPI, solo debes:
///   1. Cambiar ApiService.baseUrl por la URL real.
///   2. Implementar en FastAPI:
///        POST /listings/upload-image  (multipart, campo "file") -> {"url": "..."}
///        POST /listings               (json: category, title, price, imageUrl)
///          -> devuelve el listing creado con su "id"
///        GET  /listings?category=...  -> lista de listings de esa categoría
///   Mientras eso no exista, la app sigue funcionando: si la llamada al
///   backend falla, el artículo se guarda solo en memoria local (para poder
///   probar el flujo) y se avisa al usuario con un SnackBar.
/// ============================================================================

const Color kNavy = Color(0xFF0D2B4E);
const Color kNavyDark = Color(0xFF0A2038);
const Color kYellow = Color(0xFFFFC531);
const Color kBg = Color(0xFFF4F5F7);
const Color kCardBorder = Color(0xFFE3E6EA);
const Color kTextDark = Color(0xFF13233A);
const Color kTextGrey = Color(0xFF6B7684);

/// -------------------------------------------------------------------------
/// Modelo de una categoría (usado tanto por el TabBar como por las tarjetas).
/// -------------------------------------------------------------------------
class CategoryDef {
  final String label;
  final IconData icon;
  final String countLabel; // texto tipo "124 artículos" (solo decorativo)

  const CategoryDef(this.label, this.icon, this.countLabel);
}

/// Índice 0 = "Inicio". Del 1 en adelante son categorías reales con su propia
/// pestaña y su propio formulario de publicación.
const List<CategoryDef> kCategories = [
  CategoryDef('Inicio', Icons.storefront_outlined, ''),
  CategoryDef('Libros y Apuntes', Icons.menu_book_outlined, '124 artículos'),
  CategoryDef('Electrónica', Icons.devices_other_outlined, '89 artículos'),
  CategoryDef('Ropa y Accesorios', Icons.checkroom_outlined, '54 artículos'),
  CategoryDef('Útiles Escolares', Icons.edit_outlined, '30 artículos'),
  CategoryDef('Transporte y Rides', Icons.directions_car_outlined, '12 ofertas activas'),
  CategoryDef('Servicios Académicos', Icons.school_outlined, '45 tutores'),
  CategoryDef('Alojamiento', Icons.apartment_outlined, '18 vacantes'),
  CategoryDef('Deportes', Icons.fitness_center_outlined, '23 artículos'),
  CategoryDef('Comida y Snacks', Icons.local_cafe_outlined, '32 opciones'),
];

/// -------------------------------------------------------------------------
/// Modelo de una publicación/artículo.
/// -------------------------------------------------------------------------
class Listing {
  final String id;
  final String categoryLabel;
  final String title;
  final String price;
  final String? imageUrl; // URL real ya subida al backend
  final Uint8List? imageBytes; // vista previa local si el backend aún falló

  Listing({
    required this.id,
    required this.categoryLabel,
    required this.title,
    required this.price,
    this.imageUrl,
    this.imageBytes,
  });
}

/// -------------------------------------------------------------------------
/// Servicio de red. Aquí es lo único que hay que tocar cuando el backend
/// FastAPI exista de verdad.
/// -------------------------------------------------------------------------
class ApiService {
  // TODO: reemplaza esto por la URL real de tu backend FastAPI cuando exista.
  static const String baseUrl = 'http://TU_BACKEND_AQUI:8000';

  /// Sube los bytes de una imagen y devuelve la URL pública que la
  /// identifica en el servidor.
  static Future<String> uploadImage(Uint8List bytes, String filename) async {
    final uri = Uri.parse('$baseUrl/listings/upload-image');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send().timeout(const Duration(seconds: 8));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error subiendo imagen: ${response.statusCode}');
    }
    // Se asume una respuesta {"url": "https://.../foto.jpg"}.
    final match = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(response.body);
    if (match == null) throw Exception('Respuesta de imagen inválida');
    return match.group(1)!;
  }

  /// Crea la publicación en el backend ya con la URL de la imagen.
  static Future<void> createListing({
    required String category,
    required String title,
    required String price,
    required String imageUrl,
  }) async {
    final uri = Uri.parse('$baseUrl/listings');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body:
              '{"category":"$category","title":"$title","price":"$price","imageUrl":"$imageUrl"}',
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error creando publicación: ${response.statusCode}');
    }
  }
}

/// -------------------------------------------------------------------------
/// Pantalla principal: TabBar con "Inicio" + una pestaña por categoría.
/// -------------------------------------------------------------------------
class UtbMarketHomePage extends StatefulWidget {
  const UtbMarketHomePage({super.key});

  @override
  State<UtbMarketHomePage> createState() => _UtbMarketHomePageState();
}

class _UtbMarketHomePageState extends State<UtbMarketHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Publicaciones por categoría, en memoria (sirve para probar el flujo
  // completo mientras el backend no está listo).
  final Map<String, List<Listing>> _listingsByCategory = {
    for (final c in kCategories.skip(1)) c.label: <Listing>[],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kCategories.length, vsync: this);
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
      _listingsByCategory[category]!.insert(0, listing);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),
            const _MainHeader(),
            _CategoryNav(tabController: _tabController, onTap: _goToCategory),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _HomeTab(onCategoryTap: _goToCategory),
                  for (final category in kCategories.skip(1))
                    _CategoryTab(
                      category: category,
                      listings: _listingsByCategory[category.label]!,
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
/// Barra superior delgada (igual que antes).
/// -------------------------------------------------------------------------
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
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
          const Text('¡Hola, Estudiante UTB!', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 16),
          const Icon(Icons.notifications_none, color: Colors.white70, size: 18),
          const SizedBox(width: 12),
          const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Logo + buscador (igual que antes).
/// -------------------------------------------------------------------------
class _MainHeader extends StatelessWidget {
  const _MainHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kNavy,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: kYellow, borderRadius: BorderRadius.circular(6)),
            alignment: Alignment.center,
            child: const Text('UTB',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: kNavy)),
          ),
          const SizedBox(width: 8),
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
              height: 38,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Buscar libros, tecnología, apuntes y más...',
                        hintStyle: TextStyle(fontSize: 13, color: kTextGrey),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  Icon(Icons.search, color: kTextGrey, size: 20),
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
/// Barra de categorías: ahora son pestañas reales (TabBar).
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
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: [for (final c in kCategories) Tab(text: c.label, icon: Icon(c.icon, size: 16))],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Pestaña "Inicio": banner y categorías destacadas (tarjetas tappables que
/// llaman a onCategoryTap para cambiar de pestaña).
/// -------------------------------------------------------------------------
class _HomeTab extends StatelessWidget {
  final void Function(String label) onCategoryTap;
  const _HomeTab({required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroBanner(onExplore: () => onCategoryTap('Libros y Apuntes')),
          const SizedBox(height: 32),
          const Text('Categorías destacadas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextDark)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: [
                  for (final c in kCategories.skip(1))
                    _CategoryCard(category: c, onTap: () => onCategoryTap(c.label)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _SellCtaBanner(onPressed: () => onCategoryTap('Libros y Apuntes')),
        ],
      ),
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
              child: const Text('¡Temporada de Parciales!',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kNavy)),
            ),
            const SizedBox(height: 12),
            const Text('Libros y Apuntes\ncon hasta 50% OFF',
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
              child: const Text('Explorar Descuentos', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryDef category;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kCardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(color: kBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(category.icon, size: 18, color: kNavy),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
                  Text(category.countLabel, style: const TextStyle(fontSize: 11, color: kTextGrey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellCtaBanner extends StatelessWidget {
  final VoidCallback onPressed;
  const _SellCtaBanner({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: kYellow, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Expanded(
            child: Text('¿Tienes cosas que ya no usas en el semestre? ¡Publícalas gratis!',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kNavy)),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Vender un Artículo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// -------------------------------------------------------------------------
/// Pestaña de una categoría: grilla de publicaciones + botón flotante para
/// que CUALQUIER usuario agregue su artículo con su propia imagen.
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

  Future<void> _openAddListingSheet(BuildContext context) async {
    final created = await showModalBottomSheet<Listing>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddListingSheet(category: category.label),
    );
    if (created != null) onListingCreated(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kYellow,
        foregroundColor: kNavy,
        onPressed: () => _openAddListingSheet(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Publicar'),
      ),
      body: listings.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(category.icon, size: 40, color: kTextGrey),
                    const SizedBox(height: 12),
                    Text('Aún no hay publicaciones en ${category.label}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kTextGrey)),
                    const SizedBox(height: 4),
                    const Text('Sé el primero en publicar tocando el botón de abajo.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: kTextGrey, fontSize: 12)),
                  ],
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) => _ListingCard(listing: listings[index]),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kCardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ListingImage(listing: listing)),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
                const SizedBox(height: 2),
                Text(listing.price,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kNavy)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Muestra la imagen real del usuario: primero intenta la URL del backend;
/// si aún no hay backend, usa la vista previa local guardada en memoria.
class _ListingImage extends StatelessWidget {
  final Listing listing;
  const _ListingImage({required this.listing});

  @override
  Widget build(BuildContext context) {
    if (listing.imageUrl != null && listing.imageUrl!.isNotEmpty) {
      return Image.network(
        listing.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (listing.imageBytes != null) {
      return Image.memory(listing.imageBytes!, fit: BoxFit.cover);
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFE9EBEE),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, color: kTextGrey, size: 32),
      );
}

/// -------------------------------------------------------------------------
/// Formulario para publicar un artículo con imagen propia del usuario.
/// -------------------------------------------------------------------------
class _AddListingSheet extends StatefulWidget {
  final String category;
  const _AddListingSheet({required this.category});

  @override
  State<_AddListingSheet> createState() => _AddListingSheetState();
}

class _AddListingSheetState extends State<_AddListingSheet> {
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _submitting = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedBytes = bytes;
      _pickedName = file.name;
    });
  }

  void _showImageSourceMenu() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Completa título y precio')));
      return;
    }
    setState(() => _submitting = true);

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    String? uploadedUrl;

    try {
      if (_pickedBytes != null) {
        // 1) sube la imagen al backend y obtiene su URL pública
        uploadedUrl = await ApiService.uploadImage(_pickedBytes!, _pickedName ?? '$id.jpg');
      }
      // 2) crea la publicación en el backend
      await ApiService.createListing(
        category: widget.category,
        title: _titleController.text.trim(),
        price: _priceController.text.trim(),
        imageUrl: uploadedUrl ?? '',
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        Listing(
          id: id,
          categoryLabel: widget.category,
          title: _titleController.text.trim(),
          price: _priceController.text.trim(),
          imageUrl: uploadedUrl,
        ),
      );
    } catch (_) {
      // El backend todavía no existe / no responde: guardamos la
      // publicación solo en memoria local para no bloquear el flujo,
      // usando la imagen que el usuario acaba de tomar/elegir.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Backend no disponible todavía: se guardó solo en esta sesión.'),
      ));
      Navigator.pop(
        context,
        Listing(
          id: id,
          categoryLabel: widget.category,
          title: _titleController.text.trim(),
          price: _priceController.text.trim(),
          imageBytes: _pickedBytes,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Publicar en ${widget.category}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: kTextDark)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _showImageSourceMenu,
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kCardBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: _pickedBytes == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 28, color: kTextGrey),
                          SizedBox(height: 6),
                          Text('Toca para agregar tu foto', style: TextStyle(color: kTextGrey, fontSize: 12)),
                        ],
                      ),
                    )
                  : Image.memory(_pickedBytes!, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Título del artículo', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Precio', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Publicar artículo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}