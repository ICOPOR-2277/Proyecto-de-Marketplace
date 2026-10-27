import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';

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

  // Control de vista móvil: lista vs chat activo
  bool _showMobileChat = false;

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

    if (_activeUserId != null) {
      _showMobileChat = true;
      chatSyncService.activeThreadKey = chatThreadKey(_activeUserId!, _currentPubId);
    }

    if (widget.currentUser != null) {
      _loadConversations();
      if (_activeUserId != null) {
        _loadMessages(_activeUserId!, publicationId: _currentPubId);
      }
      // Sondeo periódico para recibir mensajes en tiempo real
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted && widget.currentUser != null) {
          if (_activeUserId != null) {
            _refreshActiveMessagesSilently();
          }
          _refreshConversationsSilently();
        }
      });
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    chatSyncService.activeThreadKey = null;
    chatSyncService.refreshNow();
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
          // Si no había usuario activo y hay conversaciones, seleccionar la primera en pantallas grandes
          if (_activeUserId == null && convs.isNotEmpty) {
            final first = convs.first;
            _activeUserId = first.otroUsuarioId;
            _activeUserName = first.otroUsuarioNombre;
            _currentPubId = first.publicacionId;
            _currentPubTitle = first.publicacionTitulo;
            _currentPubPrice = first.precioFormateado;
            _currentPubImage = first.imagenUrl;
            _currentPubBlocked = first.isPublicacionBloqueada;
            chatSyncService.activeThreadKey = first.threadKey;
            _loadMessages(_activeUserId!, publicationId: _currentPubId);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingConversations = false);
    }
  }

  Future<void> _refreshConversationsSilently() async {
    final token = widget.currentUser?.token;
    if (token == null) return;
    try {
      final convs = await ApiService.fetchConversations(token);
      if (mounted && convs.isNotEmpty) {
        setState(() {
          _conversations = convs;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMessages(int otherUserId, {int? publicationId}) async {
    final token = widget.currentUser?.token;
    if (token == null) return;

    setState(() => _loadingMessages = true);
    try {
      final msgs = await ApiService.fetchMessages(
        token,
        otherUserId,
        publicacionId: publicationId,
        hiloGeneral: publicationId == null,
      );
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
      final msgs = await ApiService.fetchMessages(
        token,
        otherId,
        publicacionId: _currentPubId,
        hiloGeneral: _currentPubId == null,
      );
      if (mounted) {
        final countDiff = msgs.length != _messages.length;
        final lastDiff = msgs.isNotEmpty &&
            _messages.isNotEmpty &&
            msgs.last.id != _messages.last.id;
        if (countDiff || lastDiff) {
          setState(() => _messages = msgs);
          _scrollToBottom();
        }
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

  void _selectConversation(ChatConversation conv) {
    setState(() {
      _activeUserId = conv.otroUsuarioId;
      _activeUserName = conv.otroUsuarioNombre;
      _currentPubId = conv.publicacionId;
      _currentPubTitle = conv.publicacionTitulo;
      _currentPubPrice = conv.precioFormateado;
      _currentPubImage = conv.imagenUrl;
      _currentPubBlocked = conv.isPublicacionBloqueada;
      _showMobileChat = true;
    });
    chatSyncService.activeThreadKey = conv.threadKey;
    _loadMessages(conv.otroUsuarioId, publicationId: conv.publicacionId);
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
        chatSyncService.refreshNow();
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
    final media = MediaQuery.of(context);
    final isMobile = media.size.width < 700;

    if (user == null) {
      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: isMobile ? double.infinity : 440,
          padding: const EdgeInsets.all(24),
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
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 24,
        vertical: isMobile ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 740,
            maxHeight: isMobile ? media.size.height * 0.92 : 620,
          ),
          child: Container(
            width: isMobile ? double.infinity : 740,
            height: isMobile ? media.size.height * 0.90 : 600,
            color: Colors.white,
            child: isMobile
                ? (_showMobileChat && _activeUserId != null
                    ? _buildChatPanel(isMobile: true)
                    : _buildConversationsPanel(isMobile: true))
                : Row(
                    children: [
                      _buildConversationsPanel(isMobile: false),
                      Expanded(child: _buildChatPanel(isMobile: false)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsPanel({required bool isMobile}) {
    return Container(
      width: isMobile ? double.infinity : 260,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: isMobile
            ? null
            : const Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: kNavy,
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Conversaciones',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isMobile)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                        itemBuilder: (context, idx) {
                          final conv = _conversations[idx];
                          final isSelected = !isMobile &&
                              _activeUserId != null &&
                              conv.threadKey ==
                                  chatThreadKey(_activeUserId!, _currentPubId);

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: const Color(0xFFE0E7FF),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: isSelected
                                      ? kNavy
                                      : Colors.blueGrey.shade200,
                                  child: Text(
                                    conv.otroUsuarioNombre.isNotEmpty
                                        ? conv.otroUsuarioNombre[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (conv.imagenUrl != null &&
                                    conv.imagenUrl!.isNotEmpty)
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(3),
                                      child: Image.network(
                                        conv.imagenUrl!,
                                        width: 14,
                                        height: 14,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    conv.otroUsuarioNombre,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                if (conv.mensajesNoLeidos > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: kYellow,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${conv.mensajesNoLeidos}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: kNavyDark,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (conv.publicacionTitulo != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                                    child: Text(
                                      conv.publicacionTitulo!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: kNavy,
                                      ),
                                    ),
                                  ),
                                Text(
                                  conv.ultimoMensaje,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextGrey,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () => _selectConversation(conv),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPanel({required bool isMobile}) {
    final media = MediaQuery.of(context);
    final bubbleMaxWidth = isMobile ? media.size.width * 0.74 : 380.0;

    return Column(
      children: [
        // Cabecera del chat activo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: kNavy),
                  onPressed: () {
                    setState(() {
                      _showMobileChat = false;
                    });
                  },
                ),
              CircleAvatar(
                radius: 17,
                backgroundColor: kYellow,
                child: const Icon(Icons.person, color: kNavyDark, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _activeUserName ?? 'Selecciona un chat',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: kTextDark,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'En línea en Campus Ternera',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_outlined,
                        size: 18,
                        color: kNavy,
                      ),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      if (_currentPubPrice != null)
                        Text(
                          _currentPubPrice!,
                          style: const TextStyle(
                            color: kNavy,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_currentPubBlocked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: const Text(
                      '🚫 Bloqueado',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 15, color: Colors.red),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Aviso: Esta publicación fue bloqueada por moderación.',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Historial de mensajes
        Expanded(
          child: _activeUserId == null
              ? const Center(
                  child: Text(
                    'Selecciona una conversación para chatear',
                    style: TextStyle(color: kTextGrey, fontSize: 13),
                  ),
                )
              : _loadingMessages
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.forum_outlined,
                                  size: 42,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Inicia la conversación',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: kTextDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Pregunta por disponibilidad o punto de encuentro en la UTB.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: kTextGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isMe = msg.esMio;
                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                constraints:
                                    BoxConstraints(maxWidth: bubbleMaxWidth),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? kNavy : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: isMe
                                        ? const Radius.circular(12)
                                        : const Radius.circular(2),
                                    bottomRight: isMe
                                        ? const Radius.circular(2)
                                        : const Radius.circular(12),
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
                                  crossAxisAlignment: isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
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
                                            color: isMe
                                                ? Colors.white70
                                                : kTextGrey,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.done_all,
                                            size: 12,
                                            color: Colors.white70,
                                          ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    hintText: 'Escribe un mensaje...',
                    hintStyle: TextStyle(fontSize: 13, color: kTextGrey),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                onPressed: (_activeUserId != null && !_sending)
                    ? () => _sendMessage()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kNavy,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, size: 16),
              ),
            ],
          ),
        ),
      ],
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
