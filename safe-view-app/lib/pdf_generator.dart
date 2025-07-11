import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfGenerator {
  static Future<File> generate(Map<String, dynamic> analysisResult) async {
    final pdf = pw.Document();

    // 폰트 데이터 로드
    final fontData = await rootBundle.load("assets/fonts/NotoSansKR-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final boldFontData = await rootBundle.load("assets/fonts/NotoSansKR-Bold.ttf");
    final boldTtf = pw.Font.ttf(boldFontData);

    final pw.ThemeData theme = pw.ThemeData.withFont(base: ttf, bold: boldTtf);

    // 데이터 파싱
    final requestUrl = analysisResult['request_url'] ?? 'N/A';
    final analyzedAt = analysisResult['analyzed_at'] != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(analysisResult['analyzed_at']))
        : 'N/A';
    final report = Map<String, dynamic>.from(analysisResult['report'] ?? {});
    final geminiSummary = report['gemini_summary'] ?? 'AI 요약 정보 없음';
    final riskLevel = report['risk_level'] ?? 'N/A';
    final stats = Map<String, dynamic>.from(report['stats'] ?? {});
    final maliciousCount = stats['malicious'] ?? 0;
    final suspiciousCount = stats['suspicious'] ?? 0;
    final harmlessCount = stats['harmless'] ?? 0;
    final activityLog = List<Map<String, dynamic>>.from(analysisResult['activity_log'] ?? []);
    final vendorResults = List<Map<String, dynamic>>.from(report['vendor_results'] ?? []);
    final geoInfo = Map<String, dynamic>.from(report['geo_info'] ?? {});
    final country = geoInfo['country_name'] ?? 'N/A';
    final city = geoInfo['city'] ?? 'N/A';
    final ip = geoInfo['ip'] ?? 'N/A';

    // 스크린샷 이미지 로드
    pw.Image? screenshotImage;

    final screenshotUrl = analysisResult['screenshot_url'] != null
        ? '[http://127.0.0.1:8000](http://127.0.0.1:8000)${analysisResult['screenshot_url']}'
        : null;
    if (screenshotUrl != null) {
      try {
        final response = await http.get(Uri.parse(screenshotUrl));
        if (response.statusCode == 200) {
          screenshotImage = pw.Image(pw.MemoryImage(response.bodyBytes));
        }
      } catch (e) {
        print("PDF 스크린샷 로드 실패: $e");
      }
    }

    // PDF 페이지 구성
    pdf.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Safe View 분석 리포트', style: pw.TextStyle(font: boldTtf, fontSize: 20)),
                pw.Text(analyzedAt),
              ],
            ),
          ),
          pw.Divider(),

          // 기본 정보
          pw.SizedBox(height: 20),
          pw.Text('분석 대상 URL', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
          pw.Text(requestUrl),
          pw.SizedBox(height: 20),

          // AI 요약 보고서
          pw.Text('AI 요약 보고서', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Text(geminiSummary, style: const pw.TextStyle(lineSpacing: 5)),
          ),
          pw.SizedBox(height: 20),

          // 종합 결과
          pw.Text('종합 결과', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
          pw.Table.fromTextArray(
            context: context,
            data: <List<String>>[
              <String>['위험도', riskLevel],
              <String>['악성 판단 업체', '$maliciousCount 곳'],
              <String>['의심 판단 업체', '$suspiciousCount 곳'],
              <String>['안전 판단 업체', '$harmlessCount 곳'],
            ],
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(font: boldTtf),
          ),
          pw.SizedBox(height: 20),
          
          // Geo-Location
          pw.Text('서버 위치 정보 (Geo-Location)', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
          pw.Text('IP 주소: $ip\n국가: $country\n도시: $city'),
          pw.SizedBox(height: 20),

          // 스크린샷
          if (screenshotImage != null) ...[
            pw.Text('스크린샷', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.SizedBox(
                height: 400,
                child: screenshotImage,
              ),
            ),
            pw.SizedBox(height: 20),
          ],
          
          pw.NewPage(), // 다음 페이지로

          // 활동 로그
          pw.Text('활동 로그 (Activity Log)', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
          pw.Table.fromTextArray(
            context: context,
            headerStyle: pw.TextStyle(font: boldTtf),
            headers: ['시간', '이벤트'],
            data: activityLog.map((log) => [log['timestamp'] ?? '', log['event'] ?? '']).toList(),
          ),
          pw.SizedBox(height: 20),
          
          // 업체별 상세 결과
          pw.Text('업체별 상세 결과 (Vendor Results)', style: pw.TextStyle(font: boldTtf, fontSize: 16)),
          pw.Table.fromTextArray(
            context: context,
            headerStyle: pw.TextStyle(font: boldTtf),
            headers: ['업체명', '분류', '결과'],
            data: vendorResults.map((v) => [v['vendor_name'] ?? '', v['category'] ?? '', v['result'] ?? '']).toList(),
          ),
        ],
      ),
    );

    // 파일로 저장
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/analysis_report.pdf");
    await file.writeAsBytes(await pdf.save());
    return file;
  }
}