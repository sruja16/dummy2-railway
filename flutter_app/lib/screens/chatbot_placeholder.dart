// lib/screens/chatbot_placeholder.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatbotPlaceholder extends StatefulWidget {
  const ChatbotPlaceholder({Key? key}) : super(key: key);

  @override
  State<ChatbotPlaceholder> createState() => _ChatbotPlaceholderState();
}

class _ChatbotPlaceholderState extends State<ChatbotPlaceholder> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // {"from":"user"/"bot","msg":String, "typing":bool?}

  bool _sending = false;

  // Simple patterns
  final RegExp _complaintIdPattern = RegExp(r'\bRWC[A-Z]{3}\d{5}\b', caseSensitive: false);

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add({"from": "user", "msg": text});
    });
  }

  void _addBotTyping() {
    setState(() {
      _messages.add({"from": "bot", "msg": "typing...", "typing": true});
    });
  }

  void _replaceBotMessageWith(String reply) {
    setState(() {
      // remove last bot typing message if exists
      for (var i = _messages.length - 1; i >= 0; i--) {
        if (_messages[i]["from"] == "bot" && (_messages[i]["typing"] ?? false) == true) {
          _messages[i] = {"from": "bot", "msg": reply};
          return;
        }
      }
      // otherwise just add
      _messages.add({"from": "bot", "msg": reply});
    });
  }

  Future<void> _sendMessage() async {
    if (_sending) return;
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _addUserMessage(text);
    _msgCtrl.clear();

    _sending = true;
    _addBotTyping();

    try {
      // Check for complaint ID first
      final idMatch = _complaintIdPattern.firstMatch(text);
      if (idMatch != null) {
        final id = idMatch.group(0)!.toUpperCase();
        final reply = await _handleComplaintQuery(id);
        // small delay for UX
        await Future.delayed(const Duration(milliseconds: 550));
        _replaceBotMessageWith(reply);
        return;
      }

      // simple rule-based bot
      final low = text.toLowerCase();
      if (low.contains('hello') || low.contains('hi') || low.contains('hey')) {
        await Future.delayed(const Duration(milliseconds: 600));
        _replaceBotMessageWith("Hello! 👋 How can I assist you today? You can ask about complaint status by sending your Complaint ID (e.g. RWCTEC00001) or ask how to file a complaint.");
        return;
      }

      if (low.contains('how') && (low.contains('file') || low.contains('submit') || low.contains('complaint'))) {
        await Future.delayed(const Duration(milliseconds: 600));
        _replaceBotMessageWith("To file a complaint: Tap New Complaint → fill details → Upload image (optional) → Submit. Complaints are saved locally and synced to cloud when available.");
        return;
      }

      if (low.contains('status') && low.contains('complaint')) {
        await Future.delayed(const Duration(milliseconds: 600));
        _replaceBotMessageWith("Please provide your Complaint ID (it starts with `RWC`). I'll fetch the latest status for you.");
        return;
      }

      if (low.contains('thanks') || low.contains('thank you')) {
        await Future.delayed(const Duration(milliseconds: 400));
        _replaceBotMessageWith("You're welcome! If you need anything else, ask away 🙂");
        return;
      }

      // fallback helpful response: try to detect any complaint id inside text (looser)
      final looseId = _findLooseComplaintId(text);
      if (looseId != null) {
        final reply = await _handleComplaintQuery(looseId);
        await Future.delayed(const Duration(milliseconds: 400));
        _replaceBotMessageWith(reply);
        return;
      }

      // Default fallback
      await Future.delayed(const Duration(milliseconds: 600));
      _replaceBotMessageWith(
          "I didn't fully understand. Try sending a Complaint ID (like `RWCTEC00001`) to check status, or ask 'How to file a complaint'.");
    } finally {
      _sending = false;
    }
  }

  String? _findLooseComplaintId(String text) {
    // attempt to find things like RWC + letters + digits without strict length
    final r = RegExp(r'\bRWC[A-Z]{2,4}\d{3,6}\b', caseSensitive: false);
    final m = r.firstMatch(text);
    return m?.group(0)?.toUpperCase();
  }

  Future<String> _handleComplaintQuery(String id) async {
    // Try Firestore first (best-effort). If error or not found -> fallback to SharedPreferences
    try {
      final doc = await FirebaseFirestore.instance.collection('complaints').doc(id).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        // Normalize createdAt
        String createdAtStr = '';
        final ca = data['createdAt'];
        if (ca is Timestamp) {
          createdAtStr = ca.toDate().toLocal().toString();
        } else if (ca is String) {
          createdAtStr = DateTime.tryParse(ca)?.toLocal().toString() ?? ca.toString();
        } else if (ca is DateTime) {
          createdAtStr = ca.toLocal().toString();
        }

        final status = (data['status'] ?? 'open').toString();
        final desc = (data['description'] ?? '').toString();
        final category = (data['category'] ?? '').toString();
        final responder = (data['lastUpdatedBy'] ?? data['userEmail'] ?? '').toString();

        return "Complaint **$id**\n• Status: **$status**\n• Department: $category\n• Submitted: ${createdAtStr.isNotEmpty ? createdAtStr.split('.').first : 'Unknown'}\n• Summary: ${_short(desc)}\n\nIf you'd like more details, open the app complaint view or tell me 'details $id'.";
      }
    } catch (e) {
      debugPrint('Firestore complaint lookup failed: $e');
      // continue to fallback
    }

    // Fallback to SharedPreferences local lookup
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('complaints') ?? [];
      for (final item in list) {
        try {
          final m = json.decode(item) as Map<String, dynamic>;
          final existingId = (m['id'] ?? m['docId'] ?? '').toString().toUpperCase();
          if (existingId == id.toUpperCase()) {
            final status = (m['status'] ?? 'open').toString();
            final desc = (m['description'] ?? '').toString();
            final category = (m['category'] ?? '').toString();
            final createdAtRaw = m['createdAt'];
            final createdAt = createdAtRaw != null ? createdAtRaw.toString() : 'Unknown';
            return "Complaint **$id** (local)\n• Status: **$status**\n• Department: $category\n• Submitted: ${createdAt.split('.').first}\n• Summary: ${_short(desc)}\n\nThis record is stored locally on your device. It will sync to cloud when online.";
          }
        } catch (_) {
          // ignore malformed item
        }
      }
    } catch (e) {
      debugPrint('Local complaint lookup failed: $e');
    }

    return "I couldn't find a complaint with ID $id. Please check the ID and try again. If you just filed it, make sure the app finished saving (you can check 'Track Complaint').";
  }

  String _short(String s, [int max = 120]) {
    final trimmed = s.trim();
    if (trimmed.length <= max) return trimmed.isEmpty ? "(no description provided)" : trimmed;
    return '${trimmed.substring(0, max)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffE5F1FF),

      appBar: AppBar(
        title: const Text("Railway Assistant"),
        backgroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          )
        ],
      ),

      body: Column(
        children: [
          // Railway theme header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade700, Colors.blueAccent],
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8)
              ],
            ),
            child: Column(
              children: const [
                Icon(Icons.train, color: Colors.white, size: 60),
                SizedBox(height: 6),
                Text(
                  "AI Railway Chatbot",
                  style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  "Ask anything related to railway complaints 🚉",
                  style: TextStyle(color: Colors.white70),
                )
              ],
            ),
          ),

          // Messages List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["from"] == "user";
                final typing = (msg["typing"] ?? false) == true;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue.shade600 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: typing
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 8,
                                height: 8,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 10),
                              Text("Assistant is typing...", style: TextStyle(fontSize: 14, color: Colors.black54)),
                            ],
                          )
                        : Text(
                            msg["msg"],
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),

          // Message Input Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: "Ask something...",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Colors.blue,
                  mini: true,
                  child: const Icon(Icons.send, color: Colors.white),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
