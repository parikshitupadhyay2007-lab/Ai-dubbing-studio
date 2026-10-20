
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/otakumind_service.dart';

const mindPurple = Color(0xFF9747FF);
const mindBackground = Color(0xFF050509);
const mindSurface = Color(0xFF171322);

class OtakuMindScreen extends StatefulWidget {
  const OtakuMindScreen({super.key});

  @override
  State<OtakuMindScreen> createState() => _OtakuMindScreenState();
}

class _OtakuMindScreenState extends State<OtakuMindScreen> {
  final api = OtakuMindService();
  final input = TextEditingController();
  final scroll = ScrollController();

  List<dynamic> personalities = [];
  final List<Map<String, String>> messages = [];

  String personality = 'mentor';
  String language = 'en';
  bool loading = false;
  bool sending = false;
  bool speaking = false;

  @override
  void initState() {
    super.initState();
    loadPersonalities();
  }

  Future<void> loadPersonalities() async {
    try {
      final result = await api.personalities();
      if (!mounted) return;
      setState(() {
        personalities = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showError(e);
    }
  }

  void showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceFirst('Exception: ', ''),
        ),
      ),
    );
  }

  void moveToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> sendMessage() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) return;

    final history = messages
        .map((m) => {
              'role': m['role']!,
              'content': m['content']!,
            })
        .toList();

    final recentHistory = history.length > 12
        ? history.sublist(history.length - 12)
        : history;

    input.clear();

    setState(() {
      sending = true;
      messages.add({
        'role': 'user',
        'content': text,
      });
    });

    moveToBottom();

    try {
      final result = await api.chat(
        personalityId: personality,
        message: text,
        language: language,
        history: recentHistory,
      );

      if (!mounted) return;

      setState(() {
        messages.add({
          'role': 'assistant',
          'content': result['reply'].toString(),
          'voice': result['voice'].toString(),
        });
      });

      moveToBottom();
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  Future<void> playVoice(Map<String, String> message) async {
    if (speaking) return;

    setState(() => speaking = true);

    try {
      final bytes = await api.generateVoice(
        text: message['content']!,
        voice: message['voice']!,
      );

      final directory = await getTemporaryDirectory();

      final file = File(
        '${directory.path}/otakumind_${DateTime.now().microsecondsSinceEpoch}.mp3',
      );

      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
    } catch (e) {
      showError(e);
    } finally {
      if (mounted) {
        setState(() => speaking = false);
      }
    }
  }

  Widget messageBubble(Map<String, String> message) {
    final mine = message['role'] == 'user';

    return Align(
      alignment: mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF452473) : mindSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mine ? mindPurple : const Color(0xFF30283D),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['content'] ?? '',
              style: const TextStyle(
                height: 1.5,
                fontSize: 14,
              ),
            ),
            if (!mine && message['voice'] != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: speaking
                    ? null
                    : () => playVoice(message),
                icon: const Icon(
                  Icons.volume_up_rounded,
                  size: 18,
                ),
                label: Text(
                  speaking ? 'Generating...' : 'Listen',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mindBackground,
      appBar: AppBar(
        title: const Text(
          'OtakuMind',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: mindBackground,
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            onPressed: sending
                ? null
                : () => setState(messages.clear),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(personality),
                    initialValue: personality,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'AI Personality',
                      prefixIcon: Icon(Icons.psychology_rounded),
                    ),
                    items: personalities.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['id'].toString(),
                        child: Text(
                          item['name'].toString(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: sending
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              personality = value;
                              messages.clear();
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'en',
                        label: Text('English'),
                      ),
                      ButtonSegment(
                        value: 'hi',
                        label: Text('Hindi'),
                      ),
                    ],
                    selected: {language},
                    onSelectionChanged: sending
                        ? null
                        : (value) {
                            setState(() {
                              language = value.first;
                              messages.clear();
                            });
                          },
                  ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 65,
                              color: mindPurple,
                            ),
                            SizedBox(height: 18),
                            Text(
                              'Welcome to OtakuMind',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Choose your companion and start a conversation.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: messages.length + (sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text(
                              'OtakuMind is thinking...',
                              style: TextStyle(
                                color: mindPurple,
                              ),
                            ),
                          );
                        }

                        return messageBubble(messages[index]);
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: mindSurface,
                border: Border(
                  top: BorderSide(color: Color(0xFF30283D)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      enabled: !sending && !loading,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Ask OtakuMind anything...',
                        counterText: '',
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: sending || loading
                        ? null
                        : sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: mindPurple,
                    ),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    api.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }
}
