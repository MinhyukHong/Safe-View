import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'analysis_report_screen.dart';

class AnalysisLoadingScreen extends StatefulWidget {
  final String jobId;
  const AnalysisLoadingScreen({super.key, required this.jobId});

  @override
  State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen> {
  Timer? _timer;
  double _progress = 0.0;
  String _statusMessage = '요청 접수 중...';

  bool _isNavigationInProgress = false;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollServer());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _pollServer());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _pollServer() async {
    if (_isNavigationInProgress || !mounted || _isPolling) {
      return;
    }
    
    _isPolling = true;

    try {
      final resultsUrl = Uri.parse('http://127.0.0.1:8000/results/${widget.jobId}');
      // 타임아웃 시간: 15s
      final response = await http.get(resultsUrl).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode != 200) {
        _isPolling = false;
        return;
      }
      
      final data = json.decode(utf8.decode(response.bodyBytes));

      if (!mounted) return;

      setState(() {
        _progress = (data['progress'] as num? ?? 0.0).toDouble();
        _statusMessage = data['step'] ?? '상태 확인 중...';
      });

      if (data['status'] == 'complete') {
        _isNavigationInProgress = true;
        _timer?.cancel();

        if (data['results'] != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => AnalysisReportScreen(analysisResult: data['results']),
              ),
            );
        } else {
            _showErrorAndPop('분석 완료되었으나 결과 데이터가 없습니다.');
        }

      } else if (data['status'] == 'error') {
        _timer?.cancel();
        final errorMessage = data['message'] ?? '알 수 없는 오류가 발생했습니다.';
        _showErrorAndPop('분석 실패: $errorMessage');
      }
    } catch (e) {
      print("Polling error: $e");
      _timer?.cancel();
      _showErrorAndPop('결과를 가져오는 데 실패했습니다: ${e.runtimeType}');
    } finally {
      _isPolling = false;
    }
  }

  void _showErrorAndPop(String message) {
    if (!mounted || _isNavigationInProgress) return;
    
    _isNavigationInProgress = true;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('분석 진행 중', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 40),
              LinearProgressIndicator(
                value: _progress,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 20),
              Text(_statusMessage),
            ],
          ),
        ),
      ),
    );
  }
}