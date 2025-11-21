// lib/services/chatbot_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_message.dart';

class ChatbotService {
  /// Main entry: returns a textual reply for the user's message.
  /// Does best-effort Firestore lookups for complaint status.
  Future<String> respond(String message, {String? userEmail}) async {
    final m = message.trim().toLowerCase();

    // quick greetings
    if (_matchesAny(m, ['hi', 'hello', 'hey', 'good morning', 'good evening'])) {
      return 'Hello! 👋 I am RailAid assistant. I can help with filing & tracking complaints, train info, and general help. Try: "Track RWCTEC00001" or "How to file a complaint"';
    }

    if (_matchesAny(m, ['thanks', 'thank you', 'thx'])) {
      return 'You\'re welcome — happy to help! 😊';
    }

    if (m.contains('file') && m.contains('complaint') || m.contains('how to file')) {
      return 'To file a complaint, go to New Complaint → fill details → Submit. You can also press "New Complaint" from the Home screen.';
    }

    // Track complaint by id
    final id = _extractComplaintId(m);
    if (id != null) {
      final status = await _lookupComplaintStatus(id);
      if (status != null) {
        return 'Complaint $id status: *${status}*.';
      } else {
        return 'I could not find a complaint with id $id. Please make sure the id is correct or it may be saved locally on your device only.';
      }
    }

    // If user asks about their complaints (by email)
    if (m.contains('my complaints') || (m.contains('complaints') && userEmail != null && m.contains('my'))) {
      final list = await _getComplaintsForUser(userEmail ?? '');
      if (list.isEmpty) return 'No complaints found for $userEmail.';
      return 'Found ${list.length} complaints for you. Latest: ${list.first.id} — status ${list.first.status}.';
    }

    // Train info stub
    if (m.contains('train') && (_matchesAny(m, ['status', 'time', 'arrival', 'departure']) || m.contains('pnr'))) {
      return 'Train info: this offline assistant provides basic stubs. For real-time train status integrate a train API. Example stub: Train 12345 — Expected arrival 14:30, platform 2.';
    }

    // Location/nearby help
    if (m.contains('nearest') || m.contains('nearby') || m.contains('station')) {
      return 'You can include your location when filing a complaint. For nearby stations, please use the station search (not yet implemented offline).';
    }

    // fallback small talk / help
    if (_matchesAny(m, ['help', 'what can you do', 'options', 'menu'])) {
      return 'I can: 1) Help file a complaint, 2) Track a complaint by ID (send "Track RWC..."), 3) Provide basic train info. Try: "Track RWCTEC00001"';
    }

    // Last resort: try keyword extraction and helpful fallback
    final keywords = _extractKeywords(m);
    if (keywords.isNotEmpty) {
      return 'I\'m not sure I fully understood. I detected: ${keywords.join(", ")}. Try asking "Track <complaint id>" or "How to file a complaint".';
    }

    return 'Sorry, I didn\'t get that. Try: "Track RWCTEC00001" or "How to file a complaint".';
  }

  bool _matchesAny(String text, List<String> list) {
    for (final p in list) {
      if (text.contains(p)) return true;
    }
    return false;
  }

  String? _extractComplaintId(String text) {
    // complaint ids in your app look like RWC<CODE><00001>
    final reg = RegExp(r'(rwc[a-z]{3}\d{5})', caseSensitive: false);
    final m = reg.firstMatch(text);
    if (m != null) return m.group(1)!.toUpperCase();
    // also allow user to say: "track 00001" or "track 12345"
    final reg2 = RegExp(r'\b(rwc)?([A-Za-z]{0,3}\d{3,6})\b', caseSensitive: false);
    final m2 = reg2.firstMatch(text);
    if (m2 != null) {
      final g = m2.group(2);
      if (g != null && g.length >= 5) {
        return (m2.group(1) != null ? '' : 'RWC') + g.toUpperCase();
      }
    }
    return null;
  }

  List<String> _extractKeywords(String text) {
    final stop = <String>{'the','a','an','is','are','to','for','i','you','and','or','in','on','my'};
    final words = text.split(RegExp(r'\s+')).map((s) => s.replaceAll(RegExp(r'[^\w]'), '')).where((s) => s.isNotEmpty).toList();
    return words.where((w) => !stop.contains(w)).take(6).toList();
  }

  Future<String?> _lookupComplaintStatus(String id) async {
    // 1) try Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('complaints').doc(id).get();
      if (doc.exists) {
        final data = doc.data()!;
        final status = (data['status'] ?? data['state'] ?? 'open').toString();
        return status;
      }
    } catch (e) {
      // Firestore unavailable or permission denied – fall back
    }

    // 2) try SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('complaints') ?? [];
      for (final s in list) {
        try {
          final m = json.decode(s) as Map<String, dynamic>;
          final mid = (m['id'] ?? '').toString().toUpperCase();
          if (mid == id.toUpperCase()) {
            return (m['status'] ?? 'open').toString();
          }
        } catch (_) {}
      }
    } catch (_) {}

    return null;
  }

  Future<List<_LocalComplaint>> _getComplaintsForUser(String userEmail) async {
    final out = <_LocalComplaint>[];
    // try firestore first
    try {
      final q = await FirebaseFirestore.instance.collection('complaints').where('userEmail', isEqualTo: userEmail).orderBy('createdAt', descending: true).limit(100).get();
      for (final d in q.docs) {
        final m = d.data();
        out.add(_LocalComplaint(id: d.id, status: (m['status'] ?? 'open').toString(), createdAt: _tsToDate(m['createdAt'])));
      }
      return out;
    } catch (_) {
      // ignore
    }

    // fallback local
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('complaints') ?? [];
      for (final s in list) {
        try {
          final m = json.decode(s) as Map<String, dynamic>;
          final email = (m['userEmail'] ?? '').toString();
          if (email.isEmpty) continue;
          if (email == userEmail) {
            out.add(_LocalComplaint(id: (m['id'] ?? '').toString(), status: (m['status'] ?? 'open').toString(), createdAt: DateTime.tryParse((m['createdAt'] ?? '')) ?? DateTime.now()));
          }
        } catch (_) {}
      }
    } catch (_) {}

    return out;
  }

  DateTime _tsToDate(dynamic ts) {
    if (ts is Timestamp) return ts.toDate();
    if (ts is String) return DateTime.tryParse(ts) ?? DateTime.now();
    if (ts is DateTime) return ts;
    return DateTime.now();
  }
}

class _LocalComplaint {
  final String id;
  final String status;
  final DateTime createdAt;
  _LocalComplaint({required this.id, required this.status, required this.createdAt});
}
