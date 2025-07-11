import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart'; // PDF 공유
import 'package:shimmer/shimmer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'pdf_generator.dart'; // PDF 생성
import 'widgets/ai_summary_card.dart';
import 'widgets/risk_summary_card.dart';
import 'widgets/vendor_result_list.dart';

class AnalysisReportScreen extends StatefulWidget {
  final Map<String, dynamic> analysisResult;
  const AnalysisReportScreen({super.key, required this.analysisResult});

  @override
  State<AnalysisReportScreen> createState() => _AnalysisReportScreenState();
}

class _AnalysisReportScreenState extends State<AnalysisReportScreen> {
  late final MapController _mapController;
  bool _isCreatingPdf = false; // PDF 생성 중인지 확인하는 상태 변수

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // PDF 생성 및 공유 로직
  Future<void> _shareAsPdf() async {
    setState(() {
      _isCreatingPdf = true;
    });
    
    // 로딩 스낵바 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF 보고서를 생성 중입니다...')),
    );

    try {
      final pdfFile = await PdfGenerator.generate(widget.analysisResult);
      
      // PDF 공유
      await Printing.sharePdf(
        bytes: await pdfFile.readAsBytes(),
        filename: 'Safe-View-Report.pdf',
      );

    } catch (e) {
      print('PDF 생성 또는 공유 실패: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: PDF 보고서를 생성할 수 없습니다.')),
        );
      }
    } finally {
      if(mounted) {
        setState(() {
          _isCreatingPdf = false;
        });
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const String serverBaseUrl = 'http://127.0.0.1:8000';

    final analysisResult = widget.analysisResult;
    final relativeScreenshotPath = analysisResult['screenshot_url'] as String? ?? '';
    final fullScreenshotUrl = relativeScreenshotPath.isNotEmpty ? '$serverBaseUrl$relativeScreenshotPath' : '';
    final activityLog = List<Map<String, dynamic>>.from(analysisResult['activity_log'] ?? []);
    final report = Map<String, dynamic>.from(analysisResult['report'] ?? {});
    final geoInfo = Map<String, dynamic>.from(report['geo_info'] ?? {});
    
    final lat = geoInfo.containsKey('latitude') && geoInfo['latitude'] != null ? geoInfo['latitude'] as double : null;
    final lon = geoInfo.containsKey('longitude') && geoInfo['longitude'] != null ? geoInfo['longitude'] as double : null;

    final stats = Map<String, dynamic>.from(report['stats'] ?? {});
    final vendorResults = List<Map<String, dynamic>>.from(report['vendor_results'] ?? []);
    final geminiSummary = report['gemini_summary'] as String? ?? "AI 요약 정보를 불러오는 데 실패했습니다.";
    
    final totalVendors = (stats['harmless'] ?? 0) + (stats['malicious'] ?? 0) + (stats['suspicious'] ?? 0) + (stats['undetected'] ?? 0);
    final summary = "Total $totalVendors vendors: Malicious ${stats['malicious'] ?? 0}, Suspicious ${stats['suspicious'] ?? 0}";

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('분석 리포트'),
          // PDF 공유 버튼 로직
          actions: [
            _isCreatingPdf
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)),
                )
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'PDF로 공유하기',
                  onPressed: _shareAsPdf,
                ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Screenshots'),
              Tab(text: 'Activity Log'),
              Tab(text: 'Report'),
              Tab(text: 'Geo-Location'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // 스크린샷 탭
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: InteractiveViewer(
                child: fullScreenshotUrl.isNotEmpty
                  ? Image.network(
                      fullScreenshotUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Shimmer.fromColors(
                          baseColor: Colors.grey[850]!,
                          highlightColor: Colors.grey[800]!,
                          child: Container(color: Colors.white),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text('스크린샷을 불러올 수 없습니다.'));
                      },
                    )
                  : const Center(child: Text('스크린샷이 없습니다.')),
              ),
            ),

            // 활동 로그 탭
            ListView.builder(
              itemCount: activityLog.length,
              itemBuilder: (context, index) {
                final log = activityLog[index];
                return ListTile(
                  leading: Text(log['timestamp'] ?? ''),
                  title: Text(log['event'] ?? ''),
                );
              },
            ),

            // 종합 리포트 탭
            ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                AiSummaryCard(summary: geminiSummary),
                const SizedBox(height: 10),
                RiskSummaryCard(
                  riskLevel: report['risk_level'] ?? 'N/A',
                  summary: summary,
                ),
                const SizedBox(height: 10),
                VendorResultList(vendorResults: vendorResults),
              ],
            ),
            
            // 지도 위치 탭
            (lat != null && lon != null)
                ? Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: LatLng(lat, lon),
                          initialZoom: 13.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.safe_view',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                width: 80.0,
                                height: 80.0,
                                point: LatLng(lat, lon),
                                child: const Icon(Icons.location_pin, color: Colors.red, size: 40.0),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: Column(
                          children: [
                            FloatingActionButton(
                              heroTag: 'zoom_in_button',
                              mini: true,
                              onPressed: () {
                                _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                              },
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton(
                              heroTag: 'zoom_out_button',
                              mini: true,
                              onPressed: () {
                                _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                              },
                              child: const Icon(Icons.remove),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text('지리적 위치 정보가 없습니다.'),
                  ),
          ],
        ),
      ),
    );
  }
}