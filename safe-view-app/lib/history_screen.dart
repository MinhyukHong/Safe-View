import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'analysis_report_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    try {
      final url = Uri.parse('http://127.0.0.1:8000/history');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _history = json.decode(utf8.decode(response.bodyBytes)); // 한글 깨짐 방지
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error fetching history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('분석 기록'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('분석 기록이 없습니다.'))
              : RefreshIndicator(
                  // 화면을 당겼을 때 실행될 함수 지정
                  onRefresh: _fetchHistory,
                  child: ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final report = item['report'] ?? {};
                      final riskLevel = report['risk_level'] ?? 'Info';

                      return ListTile(
                        leading: Icon(
                          riskLevel == 'High'
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: riskLevel == 'High'
                              ? Colors.redAccent
                              : Colors.green,
                        ),
                        title: Text(item['request_url'] ?? 'Unknown URL'),
                        subtitle: Text(item['analyzed_at'] != null
                            ? DateTime.parse(item['analyzed_at'])
                                .toLocal()
                                .toString()
                                .substring(0, 16)
                            : 'Unknown date'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AnalysisReportScreen(analysisResult: item),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}