import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'chat_controller.dart';
import 'chat_model.dart';
import 'package:intl/intl.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showEmoji = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() => _showEmoji = false);
      }
    });
  }

  void _sendMessage() {
    ref.read(chatControllerProvider.notifier).sendMessage(_textController.text);
    _textController.clear();
  }

  Future<void> _createPoll() async {
    final questionCtrl = TextEditingController();
    final optionCtrls = [TextEditingController(), TextEditingController()];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Crear Encuesta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionCtrl,
                      decoration: const InputDecoration(labelText: 'Pregunta'),
                    ),
                    const Divider(),
                    ...optionCtrls.asMap().entries.map((entry) {
                      return TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: 'Opción ${entry.key + 1}',
                          suffixIcon: optionCtrls.length > 2
                              ? IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setDialogState(() => optionCtrls.removeAt(entry.key));
                                  },
                                )
                              : null,
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() => optionCtrls.add(TextEditingController()));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar opción'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final options = optionCtrls
                        .map((c) => c.text.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();
                    if (questionCtrl.text.trim().isNotEmpty && options.length >= 2) {
                      ref.read(chatControllerProvider.notifier).sendPoll(
                            questionCtrl.text.trim(),
                            options,
                          );
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    _textController.text += emoji.emoji;
  }

  void _onBackspacePressed() {
    _textController
      ..text = _textController.text.characters.skipLast(1).toString()
      ..selection = TextSelection.fromPosition(
          TextPosition(offset: _textController.text.length));
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatStreamProvider);
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Use theme background or fallback
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.grey[200], 
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              data: (msgs) {
                if (msgs.isEmpty) {
                  return const Center(child: Text('¡Escribe el primer mensaje!'));
                }
                return ListView.builder(
                  reverse: true, // Empezar desde abajo
                  controller: _scrollController,
                  itemCount: msgs.length,
                  itemBuilder: (context, index) {
                    final msg = msgs[index];
                    final isMe = msg.senderId == currentUser?.uid;
                    
                    // Logic for Date Header (List is reversed: 0 is newest)
                    bool showDateHeader = false;
                    if (index == msgs.length - 1) {
                      showDateHeader = true; // Always show for oldest message
                    } else {
                      final nextMsg = msgs[index + 1]; // Message sent *before* current one
                      if (!isSameDay(msg.timestamp, nextMsg.timestamp)) {
                        showDateHeader = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateHeader) _DateHeader(timestamp: msg.timestamp),
                        if (msg.type == 'poll')
                          _PollBubble(message: msg, isMe: isMe)
                        else
                          _MessageBubble(message: msg, isMe: isMe),
                      ],
                    );
                  },
                );
              },
              error: (err, st) => Center(child: Text('Error: $err')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
          
          // ... (Input Area same) ...
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                    child: IconButton(
                      icon: Icon(
                        _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () async {
                        if (_showEmoji) {
                          setState(() => _showEmoji = false);
                          await Future.delayed(const Duration(milliseconds: 50));
                          _focusNode.requestFocus();
                        } else {
                          _focusNode.unfocus();
                          await Future.delayed(const Duration(milliseconds: 50));
                          setState(() => _showEmoji = true);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: 'Escribe algo...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.poll_outlined, color: Theme.of(context).colorScheme.primary),
                    onPressed: _createPoll,
                  ),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Emoji Picker
          if (_showEmoji)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                 onEmojiSelected: _onEmojiSelected,
                 onBackspacePressed: _onBackspacePressed,
                 config: const Config(),
              ),
            ),
        ],
      ),
    );
  }

  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month && date1.day == date2.day;
  }
}

class _DateHeader extends StatelessWidget {
  final DateTime timestamp;

  const _DateHeader({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    String text;
    if (date == today) {
      text = 'Hoy';
    } else if (date == today.subtract(const Duration(days: 1))) {
      text = 'Ayer';
    } else {
      text = DateFormat('d MMM yyyy', 'es_MX').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.timestamp);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final theme = Theme.of(context);
    final bubbleColor = isMe
        ? (isDark ? theme.colorScheme.primary : theme.colorScheme.primary)
        : (isDark ? Colors.grey[850] : Colors.grey[200]);
    final txtColor = isMe
        ? (isDark ? Colors.white : Colors.white)
        : (isDark ? Colors.white : Colors.black87);

    return Padding( // Padding for Row
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMe) ...[
             CircleAvatar(
               radius: 12,
               backgroundColor: Colors.blueGrey,
               child: Text(
                 _getInitials(message.senderName),
                 style: const TextStyle(fontSize: 10, color: Colors.white),
               ),
             ),
             const SizedBox(width: 8),
          ],
          
          Flexible( // Flexible bubble
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.70),
              decoration: BoxDecoration(
                 color: bubbleColor, 
                 borderRadius: BorderRadius.only(
                   topLeft: const Radius.circular(12),
                   topRight: const Radius.circular(12),
                   bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                   bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                 ),
                 boxShadow: [
                   BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, 1), blurRadius: 1)
                 ]
              ),
              padding: const EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, // Wrap content
                children: [
                  if (!isMe) ...[
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                        fontSize: 12,
                      ),
                    ),
                  ],
                  // Text and Time in Wrap/Row
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                       Text(
                         message.text, 
                         style: TextStyle(fontSize: 15, color: txtColor)
                       ),
                       const SizedBox(width: 8), // Gap before time
                       Padding(
                         padding: const EdgeInsets.only(bottom: 2),
                         child: Text(
                          timeStr,
                          style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : (isDark ? Colors.grey[400] : Colors.grey)),
                         ),
                       ),
                    ],
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

class _PollBubble extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;

  const _PollBubble({required this.message, required this.isMe});

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    final votes = message.votes ?? {};
    final options = message.pollOptions ?? [];
    
    // Calculate total votes
    int totalVotes = 0;
    votes.forEach((_, list) => totalVotes += (list as List).length);

    final bubbleColor = isDark ? const Color(0xFF202C33) : Colors.white;
    final txtColor = isDark ? Colors.white : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.blueGrey,
              child: Text(
                _getInitials(message.senderName),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.poll, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Encuesta',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.text,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: txtColor),
                  ),
                  const SizedBox(height: 12),
                  ...options.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final text = entry.value;
                    final optionVotes = (votes[idx.toString()] as List? ?? []);
                    final count = optionVotes.length;
                    final isSelected = optionVotes.contains(currentUserId);
                    final percent = totalVotes == 0 ? 0.0 : count / totalVotes;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () => ref.read(chatControllerProvider.notifier).vote(message.id, idx),
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    text,
                                    style: TextStyle(
                                      color: txtColor,
                                      fontSize: 14,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (count > 0)
                                  Text(
                                    '$count',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Stack(
                              children: [
                                Container(
                                  height: 10,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white12 : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutQuart,
                                  tween: Tween<double>(begin: 0, end: percent),
                                  builder: (context, value, _) {
                                    return FractionallySizedBox(
                                      widthFactor: value,
                                      child: Container(
                                        height: 10,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Theme.of(context).colorScheme.primary,
                                              Theme.of(context).colorScheme.secondary,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(5),
                                          boxShadow: [
                                            if (isSelected)
                                              BoxShadow(
                                                color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              )
                                          ],
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
                    );
                  }),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '$totalVotes votos • Toca para votar',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600], fontStyle: FontStyle.italic),
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

