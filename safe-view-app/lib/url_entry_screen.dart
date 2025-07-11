import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'analysis_loading_screen.dart';
import 'history_screen.dart';

class UrlEntryScreen extends StatefulWidget {
  const UrlEntryScreen({super.key});

  @override
  State<UrlEntryScreen> createState() => _UrlEntryScreenState();
}

class _UrlEntryScreenState extends State<UrlEntryScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isRequesting = false; // 중복 요청 방지를 위한 플래그

  Future<void> _startAnalysis() async {
    final urlPattern = r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/[a-zA-Z0-9]+\.[^\s]{2,}|[a-zA-Z0-9]+\.[^\s]{2,})';
    final regExp = RegExp(urlPattern);

    if (!regExp.hasMatch(_urlController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 URL 형식이 아닙니다.')),
      );
      setState(() { _isRequesting = false; }); // 요청 상태 초기화
      return; // 분석 중단
    }

    setState(() {
      _isRequesting = true;
    });

    try {
      final analyzeUrl = Uri.parse('http://127.0.0.1:8000/analyze');
      final response = await http.post(
        analyzeUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'url_to_analyze': _urlController.text}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final String jobId = json.decode(response.body)['job_id'];
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnalysisLoadingScreen(jobId: jobId),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('분석 요청 실패: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류 발생: 서버에 연결할 수 없습니다.')),
        );
      }
      print('오류 발생: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SAFE VIEW'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text('URL Entry', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: '분석할 웹사이트 주소를 입력하세요.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isRequesting
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  ),
                  onPressed: _startAnalysis,
                  child: const Text(
                    '분석하기',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      )
                    ),
                ),
          ],
        ),
      ),
    );
  }
}