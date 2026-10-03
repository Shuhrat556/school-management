import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

const _ink = Color(0xFF0D3B66);

// The data calls behind the messages screens; replaceable in tests (defaults go to the API).
class MessagingApi {
  final Future<List<ConversationDto>> Function() conversations;
  final Future<List<MessageContactDto>> Function() contacts;
  final Future<ConversationDto?> Function(MessageContactDto contact) start;
  final Future<List<ChatMessageDto>> Function(String conversationId) messages;
  final Future<String?> Function(String conversationId, String body) send;
  final Future<void> Function(String conversationId) markRead;

  const MessagingApi({
    required this.conversations,
    required this.contacts,
    required this.start,
    required this.messages,
    required this.send,
    required this.markRead,
  });

  factory MessagingApi.live() {
    final api = ApiService();
    return MessagingApi(
      conversations: api.getConversations,
      contacts: api.getMessageContacts,
      start: api.startConversation,
      messages: api.getMessages,
      send: api.sendMessage,
      markRead: api.markConversationRead,
    );
  }
}

// Messages tab for teachers, students and parents: one-to-one conversations along class
// relationships (school-service D18). It replaced sample chats that reached no one (B42).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.api});

  final MessagingApi? api;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final MessagingApi _api = widget.api ?? MessagingApi.live();
  List<ConversationDto> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final conversations = await _api.conversations();
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _loading = false;
    });
  }

  Future<void> _open(ConversationDto conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation, api: _api)),
    );
    await _load(); // unread counts and last messages changed
  }

  Future<void> _newMessage() async {
    final contacts = await _api.contacts();
    if (!mounted) return;
    final contact = await showModalBottomSheet<MessageContactDto>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: contacts.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'There is no one you can write to yet. Teachers and families of the same classes can message each other.',
                  style: GoogleFonts.inter(color: Colors.grey.shade600, height: 1.4),
                ),
              )
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  for (final c in contacts)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _ink.withValues(alpha: 0.1),
                        child: Text(c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                            style: const TextStyle(color: _ink, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(c.name, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                      subtitle: Text(c.context ?? c.kind, style: GoogleFonts.inter(color: Colors.grey.shade600)),
                      onTap: () => Navigator.pop(sheetContext, c),
                    ),
                ],
              ),
      ),
    );
    if (contact == null || !mounted) return;
    final conversation = await _api.start(contact);
    if (!mounted) return;
    if (conversation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The conversation could not be started.')));
      return;
    }
    await _open(conversation);
  }

  @override
  Widget build(BuildContext context) {
    final unread = _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70),
        child: FloatingActionButton.extended(
          key: const ValueKey('new-message'),
          onPressed: _newMessage,
          backgroundColor: _ink,
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
          label: Text('New message', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 140),
            children: [
              Text('Messages', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: _ink)),
              Text(
                unread == 0 ? 'No unread messages' : '$unread unread',
                style: GoogleFonts.inter(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_conversations.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'No conversations yet. Tap "New message" to write to a teacher or a family of your classes.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.grey.shade500, height: 1.4),
                  ),
                )
              else
                for (final c in _conversations) _conversationTile(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conversationTile(ConversationDto c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onTap: () => _open(c),
            leading: CircleAvatar(
              backgroundColor: _ink.withValues(alpha: 0.1),
              child: Text(c.title.isEmpty ? '?' : c.title[0].toUpperCase(),
                  style: const TextStyle(color: _ink, fontWeight: FontWeight.bold)),
            ),
            title: Text(c.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _ink)),
            subtitle: Text(
              c.lastMessage ?? c.subtitle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(color: Colors.grey.shade600),
            ),
            trailing: c.unreadCount == 0
                ? (c.lastMessageAt == null
                    ? null
                    : Text(DateFormat('MMM d').format(c.lastMessageAt!), style: GoogleFonts.inter(fontSize: 12, color: Colors.grey)))
                : CircleAvatar(
                    radius: 12,
                    backgroundColor: const Color(0xFFF95738),
                    child: Text('${c.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
          ),
        ),
      );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversation, required this.api});

  final ConversationDto conversation;
  final MessagingApi api;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  List<ChatMessageDto> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final messages = await widget.api.messages(widget.conversation.id);
    await widget.api.markRead(widget.conversation.id);
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loading = false;
    });
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await widget.api.send(widget.conversation.id, body);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _input.clear();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
            if (widget.conversation.subtitle != null)
              Text(widget.conversation.subtitle!, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text('Say hello 👋', style: GoogleFonts.inter(color: Colors.grey.shade500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _bubble(_messages[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('message-input'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        hintText: 'Write a message',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('send-message'),
                    onPressed: _sending ? null : _send,
                    style: IconButton.styleFrom(backgroundColor: _ink),
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(ChatMessageDto m) => Align(
        alignment: m.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: m.isMine ? _ink : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.body, style: GoogleFonts.inter(color: m.isMine ? Colors.white : Colors.black87, height: 1.35)),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, HH:mm').format(m.sentAt),
                style: GoogleFonts.inter(fontSize: 10, color: m.isMine ? Colors.white70 : Colors.grey),
              ),
            ],
          ),
        ),
      );
}
