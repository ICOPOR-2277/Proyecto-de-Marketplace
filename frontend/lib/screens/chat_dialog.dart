import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class ChatDialog extends StatefulWidget {
  final CurrentUser? currentUser;
  final int? initialOtherUserId;
  final String? initialOtherUserName;
  final int? initialPublicationId;
  final String? initialPublicationTitle;
  final String? initialPublicationPrice;
  final String? initialPublicationImage;
  final bool initialIsPublicationBlocked;

  const ChatDialog({
    super.key,
    required this.currentUser,
    this.initialOtherUserId,
    this.initialOtherUserName,
    this.initialPublicationId,
    this.initialPublicationTitle,
    this.initialPublicationPrice,
    this.initialPublicationImage,
    this.initialIsPublicationBlocked = false,
  });

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatConversation> _conversations = [];
  List<ChatMessage> _messages = [];
  int? _activeUserId;
  String? _activeUserName;
  bool _loadingConversations = true;
  bool _loadingMessages = false;
  bool _sending = false;
  Timer? _pollingTimer;

  // Datos contextuales del producto en discusión
  int? _currentPubId;
  String? _currentPubTitle;
  String? _currentPubPrice;
  String? _currentPubImage;
  bool _currentPubBlocked = false;

  @override
  void initState() {
    super.initState();
    _activeUserId = widget.initialOtherUserId;
    _activeUserName = widget.initialOtherUserName;
    _currentPubId = widget.initialPublicationId;
    _currentPubTitle = widget.initialPublicationTitle;
    _currentPubPrice = widget.initialPublicationPrice;
    _currentPubImage = widget.initialPublicationImage;
    _currentPubBlocked = widget.initialIsPublicationBlocked;

    if (widget.currentUser != null) {
      _loadConversations();
      if (_activeUserId != null) {
        _loadMessages(_activeUserId!);
      }
      // Sondeo periódico para recibir mensajes en tiempo real
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_activeUserId != null && mounted) {
          _refreshActiveMessagesSilently();
        }
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    final token = widget.currentUser?.token;
    if (token == null) return;
    try {
      final convs = await ApiService.fetchConversations(token);
      if (mounted) {
        setState(() {
          _conversations = convs;
          _loadingConversations = false;
          // Si no había usuario activo y hay conversaciones, seleccionar la primera
          if (_activeUserId == null && convs.isNotEmpty) {
            _activeUserId = convs.first.otroUsuarioId;
            _activeUserName = convs.first.otroUsuarioNombre;
            _loadMessages(_activeUserId!);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConversations = false);
    }
  }

  Future<void> _loadMessages(int otherUserId) async {
    final token = widget.currentUser?.token;
    if (token == null) return;

    setState(() => _loadingMessages = true);
    try {
      final msgs = await ApiService.fetchMessages(token, otherUserId);
      if (mounted) {
        setState(() {
          _messages = msgs;
          _loadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMessages = false);
    }
  }

  Future<void> _refreshActiveMessagesSilently() async {
    final token = widget.currentUser?.token;
    final otherId = _activeUserId;
    if (token == null || otherId == null) return;
    try {
      final msgs = await ApiService.fetchMessages(token, otherId);
      if (mounted && msgs.length != _messages.length) {
        setState(() => _messages = msgs);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = quickText ?? _textController.text.trim();
    final token = widget.currentUser?.token;
    final destId = _activeUserId;

    if (text.isEmpty || token == null || destId == null || _sending) return;

    setState(() => _sending = true);
    if (quickText == null) _textController.clear();

    try {
      final sent = await ApiService.sendMessage(
        token: token,
        destinatarioId: destId,
        contenido: text,
        publicacionId: _currentPubId,
      );

      if (mounted) {
        setState(() {
          _messages.add(sent);
          _sending = false;
        });
        _scrollToBottom();
        _loadConversations();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error enviando mensaje: $e')),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final user = widget.currentUser;

    if (user == null) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_outlined, size: 54, color: kNavy),
              const SizedBox(height: 16),
              const Text(
                'Inicia sesión para chatear',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'El chat con los vendedores está disponible para miembros activos de la comunidad UTB con sesión iniciada.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextGrey),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 720,
          height: 600,
          color: Colors.white,
          child: Row(
            children: [
              // Panel lateral: Lista de conversaciones
              Container(
                width: 250,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      color: kNavy,
                      child: const Row(
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Conversaciones',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _loadingConversations
                          ? const Center(child: CircularProgressIndicator())
                          : _conversations.isEmpty && _activeUserId == null
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Aún no tienes chats activos.\nInicia una consulta en una publicación.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 12, color: kTextGrey),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _conversations.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                                  itemBuilder: (context, idx) {
                                    final conv = _conversations[idx];
                                    final isSelected = conv.otroUsuarioId == _activeUserId;
                                    return ListTile(
                                      selected: isSelected,
                                      selectedTileColor: const Color(0xFFE0E7FF),
                                      dense: true,
                                      leading: CircleAvatar(
                                        backgroundColor: isSelected ? kNavy : Colors.blueGrey.shade200,
                                        child: Text(
                                          conv.otroUsuarioNombre.isNotEmpty
                                              ? conv.otroUsuarioNombre[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      title: Text(
                                        conv.otroUsuarioNombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      subtitle: Text(
                                        conv.ultimoMensaje,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: kTextGrey),
                                      ),
                                      onTap: () {
                                        setState(() {
                                          _activeUserId = conv.otroUsuarioId;
                                          _activeUserName = conv.otroUsuarioNombre;
                                          _currentPubTitle = conv.publicacionTitulo;
                                        });
                                        _loadMessages(conv.otroUsuarioId);
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),

              // Panel principal: Chat activo
              Expanded(
                child: Column(
                  children: [
                    // Cabecera del chat activo
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: kYellow,
                            child: const Icon(Icons.person, color: kNavyDark, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeUserName ?? 'Selecciona un chat',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextDark),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text('En línea en Campus Ternera',
                                        style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Tarjeta de contexto del producto (si aplica)
                    if (_currentPubTitle != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        color: const Color(0xFFF1F5F9),
                        child: Row(
                          children: [
                            if (_currentPubImage != null && _currentPubImage!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  _currentPubImage!,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag_outlined, size: 18, color: kNavy),
                                ),
                              )
                            else
                              const Icon(Icons.shopping_bag_outlined, size: 18, color: kNavy),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _currentPubTitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  if (_currentPubPrice != null)
                                    Text(
                                      _currentPubPrice!,
                                      style: const TextStyle(color: kNavy, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                            ),
                            if (_currentPubBlocked)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: const Text(
                                  '🚫 Bloqueado por moderación',
                                  style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // Banner de advertencia si la publicación está bloqueada
                    if (_currentPubBlocked)
                      Container(
                        width: double.infinity,
                        color: Colors.red.shade50,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Aviso: Esta publicación fue bloqueada por un moderador. No se permiten compras.',
                                style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Historial de mensajes
                    Expanded(
                      child: _activeUserId == null
                          ? const Center(
                              child: Text('Selecciona una conversación para chatear',
                                  style: TextStyle(color: kTextGrey, fontSize: 13)),
                            )
                          : _loadingMessages
                              ? const Center(child: CircularProgressIndicator())
                              : _messages.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade300),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Inicia la conversación con el vendedor',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextDark),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Pregunta por disponibilidad, estado o punto de encuentro.',
                                            style: TextStyle(fontSize: 12, color: kTextGrey),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      itemCount: _messages.length,
                                      itemBuilder: (context, index) {
                                        final msg = _messages[index];
                                        final isMe = msg.esMio;
                                        return Align(
                                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                          child: Container(
                                            margin: const EdgeInsets.symmetric(vertical: 4),
                                            constraints: BoxConstraints(
                                              maxWidth: MediaQuery.of(context).size.width * 0.42,
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isMe ? kNavy : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.only(
                                                topLeft: const Radius.circular(12),
                                                topRight: const Radius.circular(12),
                                                bottomLeft: isMe ? const Radius.circular(12) : const Radius.circular(2),
                                                bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(12),
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.04),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                              children: [
                                                if (!isMe)
                                                  Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Text(
                                                      msg.remitenteNombre,
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: kNavyDark,
                                                      ),
                                                    ),
                                                  ),
                                                Text(
                                                  msg.contenido,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: isMe ? Colors.white : kTextDark,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _formatTime(msg.fechaEnvio),
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        color: isMe ? Colors.white70 : kTextGrey,
                                                      ),
                                                    ),
                                                    if (isMe) ...[
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.done_all, size: 12, color: Colors.white70),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                    ),

                    // Chips de respuestas sugeridas rápidas
                    if (_activeUserId != null) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Row(
                          children: [
                            _buildQuickChip('¿Aún está disponible?'),
                            _buildQuickChip('¿Dónde nos vemos en la UTB?'),
                            _buildQuickChip('¿Aceptas transferencia?'),
                            _buildQuickChip('¡Te confirmo la compra!'),
                          ],
                        ),
                      ),
                    ],

                    // Barra de entrada de texto
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              enabled: _activeUserId != null,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: const InputDecoration(
                                hintText: 'Escribe un mensaje al vendedor...',
                                hintStyle: TextStyle(fontSize: 13, color: kTextGrey),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: (_activeUserId != null && !_sending) ? () => _sendMessage() : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kNavy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.send, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 11, color: kNavyDark)),
        backgroundColor: const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        onPressed: () => _sendMessage(label),
      ),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }
}
