import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminAnalysis extends StatefulWidget {
  const AdminAnalysis({Key? key}) : super(key: key);

  @override
  State<AdminAnalysis> createState() => _AdminAnalysisState();
}

class _AdminAnalysisState extends State<AdminAnalysis> {
  bool _loading = true;
  List<Map<String, dynamic>> _complaints = [];

  final List<String> _departments = [
    'Technical',
    'Cleaning',
    'Infrastructure',
    'Safety',
    'Misconduct',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('complaints') ?? <String>[];

    final list = raw.map<Map<String, dynamic>>((e) {
      try {
        return json.decode(e) as Map<String, dynamic>;
      } catch (_) {
        return <String, dynamic>{};
      }
    }).where((m) => m.isNotEmpty).toList();

    setState(() {
      _complaints = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Analysis"),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, "/settings"),
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildKpiRow(),
                    const SizedBox(height: 20),

                    const Text(
                      "Complaints by Department",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildDepartmentBars(),
                    const SizedBox(height: 20),

                    const Text(
                      "Status Breakdown",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildStatusBreakdown(),
                    const SizedBox(height: 20),

                    const Text(
                      "Recent Complaints",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    _buildRecentList(),
                  ],
                ),
              ),
            ),
    );
  }

  // ------------------------ KPI CARDS ------------------------

  Widget _buildKpiRow() {
    final total = _complaints.length;
    final resolved =
        _complaints.where((m) => m["status"] == "resolved").length;
    final inProgress =
        _complaints.where((m) => m["status"] == "in-progress").length;
    final open = _complaints.where((m) => m["status"] == "open").length;

    Widget card(String label, String value, {Color? color}) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color ?? Colors.black),
                )
              ],
            ),
          ),
        );

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width < 520) {
        // show two cards per row on narrow screens
        final cardWidth = (width - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(width: cardWidth, child: card("Total", "$total")),
            SizedBox(width: cardWidth, child: card("Resolved", "$resolved", color: Colors.green)),
            SizedBox(width: cardWidth, child: card("In-Progress", "$inProgress", color: Colors.orange)),
            SizedBox(width: cardWidth, child: card("Open", "$open", color: Colors.red)),
          ],
        );
      }

      return Row(
        children: [
          Expanded(child: card("Total", "$total")),
          const SizedBox(width: 8),
          Expanded(child: card("Resolved", "$resolved", color: Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: card("In-Progress", "$inProgress", color: Colors.orange)),
          const SizedBox(width: 8),
          Expanded(child: card("Open", "$open", color: Colors.red)),
        ],
      );
    });
  }

  // ------------------------ DEPARTMENT BAR CHART ------------------------

  Widget _buildDepartmentBars() {
    final counts = {
      for (var d in _departments)
        d: _complaints.where((m) => m["category"] == d).length
    };

    final maxValue = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b);

    return Column(
      children: _departments.map((dept) {
        final count = counts[dept] ?? 0;

        // FIXED: safe widthFactor
        final double pct =
            maxValue == 0 ? 0.0 : (count / maxValue).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(flex: 2, child: Text(dept)),
              const SizedBox(width: 12),

              Expanded(
                flex: 6,
                child: Stack(
                  children: [
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),

                    FractionallySizedBox(
                      widthFactor: pct.isNaN ? 0 : pct,
                      child: Container(
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Text("$count"),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ------------------------ STATUS BREAKDOWN ------------------------

  Widget _buildStatusBreakdown() {
    final total = _complaints.length.toDouble();

    if (total == 0) {
      return const Center(child: Text("No complaints available"));
    }

    final res = _complaints.where((m) => m["status"] == "resolved").length;
    final prog = _complaints.where((m) => m["status"] == "in-progress").length;
    final open = _complaints.where((m) => m["status"] == "open").length;

    Widget bar(Color c, String label, int value) {
      final pct = (value / total * 100).round();
      return Row(
        children: [
          Container(width: 12, height: 12, color: c),
          const SizedBox(width: 8),
          Text("$label ($pct%)"),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            bar(Colors.green, "Resolved", res),
            const SizedBox(height: 8),
            bar(Colors.orange, "In-Progress", prog),
            const SizedBox(height: 8),
            bar(Colors.red, "Open", open),
          ],
        ),
      ),
    );
  }

  // ------------------------ RECENT LIST ------------------------

  Widget _buildRecentList() {
    final recent = _complaints.take(6).toList();

    if (recent.isEmpty) {
      return const Center(child: Text("No complaints yet"));
    }

    return Column(
      children: recent.map((m) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.report),
            title: Text("${m['id']}  —  ${m['category']}"),
            subtitle: Text(m['description'] ?? ""),
            trailing: Text(
              m['status'] ?? "",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
    );
  }
}
