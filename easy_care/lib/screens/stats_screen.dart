import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart'; // kIsWeb 사용
import '../models/health_stat.dart';
import 'input_screen.dart'; // [추가] 수정 기능을 위한 임포트

class StatsScreen extends StatefulWidget {
  final String? initialCreator; // 특정 인물의 통계를 바로 열람하기 위한 매개변수
  final DateTime? initialDate; // [추가] 특정 날짜로 바로 이동
  final bool jumpToCalendar; // [추가] 달력 보기로 바로 시작할지 여부
  const StatsScreen({super.key, this.initialCreator, this.initialDate, this.jumpToCalendar = false});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late bool _isCalendarView;
  String _timeRange = '주간';
  String _chartType = '혈당'; // [규칙 3] 혈당/혈압 전환용
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  List<String> _allowedCodes = [];
  Map<String, String> _codeToName = {}; // {코드: 이름} 매핑
  late String _selectedCreator; // 필터링용 선택된 작성자
  bool _isLoadingCodes = true;
  bool _hasShownInitialDetail = false; // [추가] 초기 상세창 노출 여부

  @override
  void initState() {
    super.initState();
    _selectedCreator = widget.initialCreator ?? '전체';
    _isCalendarView = widget.jumpToCalendar;
    _focusedDay = widget.initialDate ?? DateTime.now();
    _selectedDay = widget.initialDate;
    _loadFamilyCodes();
  }

  Future<void> _loadFamilyCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final myCode = prefs.getString('myFamilyCode');
    final familyJson = prefs.getString('familyMembers');

    List<String> codes = [];
    Map<String, String> nameMap = {};
    
    if (myCode != null && myCode.isNotEmpty) {
      codes.add(myCode);
      nameMap[myCode] = '나';
    }
    
    if (familyJson != null) {
      final List<dynamic> familyList = json.decode(familyJson);
      for (var f in familyList) {
        if (f['code'] != null) {
          codes.add(f['code']);
          nameMap[f['code']] = f['name'] ?? '가족';
        }
      }
    }
    
    // Firestore 'whereIn' supports up to 10 items.
    if (codes.length > 10) {
      codes = codes.sublist(0, 10);
    }

    setState(() {
      _allowedCodes = codes;
      _codeToName = nameMap;
      _isLoadingCodes = false;
    });
  }

  Future<void> _exportReport() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('웹 환경에서는 리포트 추출 기능을 준비 중입니다.'))
      );
      return;
    }

    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0052CC),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (dateRange == null) return;

    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final snapshot = await FirebaseFirestore.instance.collection('health_records').orderBy('timestamp', descending: true).get();
      
      // 1. 권한 있는 전체 레코드
      final allAuthorized = snapshot.docs
          .map((doc) => HealthRecord.fromFirestore(doc))
          .where((r) => _allowedCodes.isEmpty || r.creatorCode == null || _allowedCodes.contains(r.creatorCode))
          .toList();

      // 2. 선택된 작성자 및 기간 필터링
      final targetRecords = allAuthorized.where((r) {
        bool creatorMatch = _selectedCreator == '전체' || 
                           (_selectedCreator == '나' && r.creatorCode == _allowedCodes[0]) ||
                           (_codeToName[r.creatorCode] == _selectedCreator);
        
        bool dateMatch = r.timestamp.isAfter(dateRange.start.subtract(const Duration(seconds: 1))) &&
                        r.timestamp.isBefore(dateRange.end.add(const Duration(days: 1)));
        
        return creatorMatch && dateMatch;
      }).toList();

      if (targetRecords.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('해당 조건에 데이터가 없습니다.')));
        return;
      }

      List<String> rows = [];
      String reportTitle = _selectedCreator == '전체' ? "가족통합" : "$_selectedCreator님";
      rows.add("[$reportTitle 건강 분석 리포트]"); // 리포트 제목 추가
      rows.add("일시,구분,혈당(BST, mg/dL),혈압(BP, 수축기/이완기),당화혈색소(HbA1c, %),메모,작성자"); // 헤더 수정

      for (var r in targetRecords) {
        String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(r.timestamp);
        String bpStr = r.systolic != null && r.diastolic != null ? '${r.systolic}/${r.diastolic}' : '미측정';
        String hba1cStr = r.hba1c != null ? '${r.hba1c}%' : '미측정';
        String memoSafe = '"${r.memo.replaceAll('"', '""')}"';
        String creatorName = _codeToName[r.creatorCode] ?? '알 수 없음';
        rows.add("$dateStr,${r.type},${r.sugar},$bpStr,$hba1cStr,$memoSafe,$creatorName");
      }

      String csv = rows.join("\n");
      List<int> bytes = [0xEF, 0xBB, 0xBF] + utf8.encode(csv); // UTF-8 BOM

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/easycare_report.csv');
      await file.writeAsBytes(bytes);

      if (mounted) Navigator.pop(context);
      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: '건강 분석 리포트',
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('리포트 추출 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoadingCodes) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('건강 분석 리포트', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: _exportReport,
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            onPressed: () => setState(() => _isCalendarView = !_isCalendarView),
            icon: Icon(_isCalendarView ? Icons.show_chart_rounded : Icons.calendar_month_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('health_records')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("오류가 발생했습니다.\n${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // 1. 전체 권한 있는 레코드 필터링
          final allAuthorizedRecords = snapshot.data!.docs
              .map((doc) => HealthRecord.fromFirestore(doc))
              .where((r) => _allowedCodes.isEmpty || r.creatorCode == null || _allowedCodes.contains(r.creatorCode))
              .toList();

          if (allAuthorizedRecords.isEmpty) return const Center(child: Text("기록된 데이터가 없습니다."));

          // 2. 선택된 작성자별 필터링
          final displayRecords = allAuthorizedRecords.where((r) {
            if (_selectedCreator == '전체') return true;
            
            // 내 코드 찾기 (목록의 첫 번째가 보통 '나')
            final myCode = _allowedCodes.isNotEmpty ? _allowedCodes[0] : null;
            
            if (_selectedCreator == '나') {
              // 코드가 내 것과 일치하거나, 코드 자체가 없는 경우(레거시) '나'의 기록으로 간주
              return r.creatorCode == myCode || r.creatorCode == null || r.creatorCode!.isEmpty;
            }
            
            // 가족 필터링
            return _codeToName[r.creatorCode] == _selectedCreator;
          }).toList();

          final filteredRecords = _filterRecordsByRange(displayRecords);

          // [추가] 초기 진입 시 상세 내역 자동 노출 (대시보드 클릭 대응)
          if (!_hasShownInitialDetail && widget.initialDate != null && allAuthorizedRecords.isNotEmpty) {
            _hasShownInitialDetail = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showDayDetail(widget.initialDate!, allAuthorizedRecords);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCreatorFilter(), // 작성자 필터 추가
                const SizedBox(height: 16),
                if (!_isCalendarView) ...[
                  _buildChartTypeToggle(),
                  const SizedBox(height: 16),
                  _buildTimeFilter(),
                ],
                const SizedBox(height: 20),

                _isCalendarView
                    ? _buildCalendarView(displayRecords) // [수정] 전체가 아닌 선택된 작성자의 데이터만 전달
                    : _buildChartView(filteredRecords, isDark),

                const SizedBox(height: 24),
                _buildSummaryFeedback(filteredRecords),
              ],
            ),
          );
        },
      ),
    );
  }

  // 작성자 필터 UI (전체 + 나 + 가족 리스트)
  Widget _buildCreatorFilter() {
    List<String> names = ['전체'];
    names.addAll(_codeToName.values.toList());

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: names.map((name) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              avatar: Icon(name == '전체' ? Icons.people : (name == '나' ? Icons.person : Icons.face_4_rounded), size: 16),
              label: Text(name),
              selected: _selectedCreator == name,
              onSelected: (val) => setState(() => _selectedCreator = name),
              selectedColor: const Color(0xFF0052CC).withValues(alpha: 0.2),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartTypeToggle() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: '혈당', label: Text('혈당 추이'), icon: Icon(Icons.water_drop)),
        ButtonSegment(value: '혈압', label: Text('혈압 추이'), icon: Icon(Icons.favorite)),
      ],
      selected: {_chartType},
      onSelectionChanged: (val) => setState(() => _chartType = val.first),
    );
  }

  Widget _buildTimeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['일간', '주간', '월간', '연간'].map((range) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(range, style: const TextStyle(fontSize: 16)),
              selected: _timeRange == range,
              onSelected: (val) => setState(() => _timeRange = range),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 차트 그리기 ---
  Widget _buildChartView(List<HealthRecord> records, bool isDark) {
    if (records.isEmpty) return const SizedBox(height: 300, child: Center(child: Text("해당 조건에 기록이 없습니다.")));

    final reversed = records.reversed.toList();
    
    // 1. 최고/최저값 인덱스 및 실제 수치 계산
    int maxSugarIdx = 0, minSugarIdx = 0;
    int maxSysIdx = -1, minDiaIdx = -1;

    for (int i = 0; i < reversed.length; i++) {
      if (reversed[i].sugar > reversed[maxSugarIdx].sugar) maxSugarIdx = i;
      if (reversed[i].sugar < reversed[minSugarIdx].sugar) minSugarIdx = i;
      
      if (reversed[i].systolic != null) {
        if (maxSysIdx == -1 || reversed[i].systolic! > reversed[maxSysIdx].systolic!) maxSysIdx = i;
      }
      if (reversed[i].diastolic != null) {
        if (minDiaIdx == -1 || reversed[i].diastolic! < reversed[minDiaIdx].diastolic!) minDiaIdx = i;
      }
    }
    if (maxSysIdx == -1) maxSysIdx = 0;
    if (minDiaIdx == -1) minDiaIdx = 0;

    double maxSugarVal = reversed[maxSugarIdx].sugar.toDouble();
    double minSugarVal = reversed[minSugarIdx].sugar.toDouble();
    double maxSysVal = (reversed[maxSysIdx].systolic ?? 0).toDouble();
    double minDiaVal = (reversed[minDiaIdx].diastolic ?? 0).toDouble();

    // 2. 기준선 및 대칭 여백 계산
    final double baselineY = _chartType == '혈당' ? 100.0 : 120.0; 
    final String baselineLabel = _chartType == '혈당' ? '정상기준 (100)' : '정상수축기 (120)';

    double maxDistance = 0.0;
    for (var r in reversed) {
      if (_chartType == '혈당') {
        final distance = (r.sugar - baselineY).abs();
        if (distance > maxDistance) maxDistance = distance;
      } else {
        if (r.systolic != null) {
          final sysDistance = (r.systolic! - baselineY).abs();
          if (sysDistance > maxDistance) maxDistance = sysDistance;
        }
        if (r.diastolic != null) {
          final diaDistance = (r.diastolic! - baselineY).abs();
          if (diaDistance > maxDistance) maxDistance = diaDistance;
        }
      }
    }

    if (maxDistance == 0) maxDistance = 20.0;

    final double padding = (maxDistance * 0.2) + 40.0; 
    final double finalMaxY = baselineY + maxDistance + padding;
    final double finalMinY = (baselineY - maxDistance - padding).clamp(0.0, double.infinity);

    // 3. ExtraLines 구성
    List<HorizontalLine> horizontalLines = [
      HorizontalLine(
        y: baselineY,
        color: const Color(0xFF047857).withValues(alpha: 0.5), 
        strokeWidth: 2,
        dashArray: [5, 5],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          padding: const EdgeInsets.only(right: 5, bottom: 5),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
          labelResolver: (line) => baselineLabel,
        ),
      )
    ];

    if (_chartType == '혈당') {
      final maxDate = DateFormat('yy/MM/dd').format(reversed[maxSugarIdx].timestamp);
      final minDate = DateFormat('yy/MM/dd').format(reversed[minSugarIdx].timestamp);

      horizontalLines.add(HorizontalLine(
        y: maxSugarVal,
        color: Colors.redAccent.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: [4, 4],
        label: HorizontalLineLabel(
          show: true, 
          alignment: Alignment.topRight, 
          style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold), 
          labelResolver: (_) => '최고 ($maxSugarVal) - $maxDate'
        ),
      ));
      if (maxSugarVal != minSugarVal) {
        horizontalLines.add(HorizontalLine(
          y: minSugarVal,
          color: Colors.blueAccent.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true, 
            alignment: Alignment.topRight, 
            style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold), 
            labelResolver: (_) => '최저 ($minSugarVal) - $minDate'
          ),
        ));
      }
    } else {
      final maxDate = DateFormat('yy/MM/dd').format(reversed[maxSysIdx].timestamp);
      final minDate = DateFormat('yy/MM/dd').format(reversed[minDiaIdx].timestamp);

      horizontalLines.add(HorizontalLine(
        y: maxSysVal,
        color: Colors.redAccent.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: [4, 4],
        label: HorizontalLineLabel(
          show: true, 
          alignment: Alignment.topRight, 
          style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold), 
          labelResolver: (_) => '최고 수축기 ($maxSysVal) - $maxDate'
        ),
      ));
      if (maxSysVal != minDiaVal) {
        horizontalLines.add(HorizontalLine(
          y: minDiaVal,
          color: Colors.blueAccent.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: [4, 4],
          label: HorizontalLineLabel(
            show: true, 
            alignment: Alignment.topRight, 
            style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold), 
            labelResolver: (_) => '최저 이완기 ($minDiaVal) - $minDate'
          ),
        ));
      }
    }

    return Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 20, 25, 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: LineChart(
        LineChartData(
          minY: finalMinY,
          maxY: finalMaxY,
          lineTouchData: LineTouchData(
            enabled: true,
            getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((spotIndex) {
                return TouchedSpotIndicatorData(
                  FlLine(color: isDark ? Colors.white30 : Colors.grey.shade400, strokeWidth: 2, dashArray: [4, 4]),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 5, color: barData.color ?? Colors.blue, strokeWidth: 2,
                        strokeColor: isDark ? Colors.black : Colors.white,
                      );
                    },
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => isDark ? Colors.grey.shade800 : Colors.black87.withValues(alpha: 0.8),
              tooltipRoundedRadius: 8,
              maxContentWidth: 300, // 너비 더 확장
              tooltipPadding: const EdgeInsets.all(12), // 패딩 추가로 공간 확보
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final record = reversed[touchedSpot.spotIndex];
                  final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(record.timestamp);
                  
                  // 작성자 정보를 제거하고 측정 정보에만 집중
                  String tooltipText = '$dateStr\n(${record.type})\n';
                  if (_chartType == '혈당') {
                    tooltipText += '혈당: ${record.sugar} mg/dL';
                  } else {
                    bool isSys = touchedSpot.barIndex == 0;
                    String prefix = isSys ? "수축기: " : "이완기: ";
                    int val = isSys ? (record.systolic ?? 0) : (record.diastolic ?? 0);
                    tooltipText += '$prefix$val mmHg';
                  }
                  
                  if (record.memo.isNotEmpty) {
                    tooltipText += '\n메모: ${record.memo}';
                  }

                  return LineTooltipItem(
                    tooltipText,
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.4, // 줄 간격 확보
                    ),
                  );
                }).toList();
              },
            ),
          ),
          extraLinesData: ExtraLinesData(horizontalLines: horizontalLines),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: _getLineBarsData(reversed, maxSugarIdx, minSugarIdx, maxSysIdx, minDiaIdx),
        ),
      ),
    );
  }

  List<LineChartBarData> _getLineBarsData(
    List<HealthRecord> reversedRecords, int maxSugarIdx, int minSugarIdx, int maxSysIdx, int minDiaIdx
  ) {
    if (_chartType == '혈당') {
      return [
        LineChartBarData(
          spots: List.generate(reversedRecords.length, (i) => FlSpot(i.toDouble(), reversedRecords[i].sugar.toDouble())),
          isCurved: true,
          color: const Color(0xFF0052CC),
          barWidth: 2,
          dotData: const FlDotData(show: true), 
          belowBarData: BarAreaData(show: true, color: const Color(0xFF0052CC).withValues(alpha: 0.1)),
          showingIndicators: {maxSugarIdx, minSugarIdx}.toList(), 
        )
      ];
    } else {
      return [
        LineChartBarData(
          spots: List.generate(reversedRecords.length, (i) => FlSpot(i.toDouble(), (reversedRecords[i].systolic ?? 0).toDouble())),
          isCurved: true,
          color: Colors.orange,
          barWidth: 2,
          dotData: const FlDotData(show: true),
          showingIndicators: {maxSysIdx}.toList(),
        ),
        LineChartBarData(
          spots: List.generate(reversedRecords.length, (i) => FlSpot(i.toDouble(), (reversedRecords[i].diastolic ?? 0).toDouble())),
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          dotData: const FlDotData(show: true),
          showingIndicators: {minDiaIdx}.toList(),
        ),
      ];
    }
  }

  Widget _buildSummaryFeedback(List<HealthRecord> records) {
    if (records.isEmpty) return const SizedBox();
    
    Color themeColor;
    String summaryText;

    if (_chartType == '혈당') {
      double avgSugar = records.map((r) => r.sugar).reduce((a, b) => a + b) / records.length;
      final hba1cRecords = records.where((r) => r.hba1c != null).map((r) => r.hba1c!).toList();
      String hba1cSummary = "";
      if (hba1cRecords.isNotEmpty) {
        double avgHbA1c = hba1cRecords.reduce((a, b) => a + b) / hba1cRecords.length;
        hba1cSummary = "\n평균 당화혈색소(HbA1c): ${avgHbA1c.toStringAsFixed(1)}%";
      }

      if (avgSugar > 140) {
        themeColor = Colors.red.shade800;
        summaryText = "평균 혈당이 다소 높습니다.\n식단 관리에 조금 더 신경 써주세요! 🥗$hba1cSummary";
      } else {
        themeColor = const Color(0xFF0052CC);
        summaryText = "안정적으로 잘 관리하고 계십니다.\n지금처럼만 유지하세요! 👍$hba1cSummary";
      }
    } else {
      final bpRecords = records.where((r) => r.systolic != null && r.diastolic != null).toList();
      if (bpRecords.isEmpty) return const SizedBox(); 

      double avgSys = bpRecords.map((r) => r.systolic!).reduce((a, b) => a + b) / bpRecords.length;
      double avgDia = bpRecords.map((r) => r.diastolic!).reduce((a, b) => a + b) / bpRecords.length;

      if (avgSys >= 140 || avgDia >= 90) {
        themeColor = Colors.red.shade800;
        summaryText = "평균 혈압이 다소 높습니다.\n안정을 취하고 무리하지 마세요! 🧘‍♂️";
      } else {
        themeColor = const Color(0xFF047857); 
        summaryText = "혈압이 정상 범위에 있습니다.\n아주 잘 관리하고 계시네요! 👏";
      }
    }

    String creatorTitle = _selectedCreator == '전체' ? "가족 통합" : "$_selectedCreator님의";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$creatorTitle $_timeRange 요약 ($_chartType)", style: TextStyle(color: themeColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            summaryText,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    );
  }

  List<HealthRecord> _filterRecordsByRange(List<HealthRecord> records) {
    final now = DateTime.now();
    return records.where((r) {
      if (_timeRange == '일간') return isSameDay(r.timestamp, now);
      if (_timeRange == '주간') return r.timestamp.isAfter(now.subtract(const Duration(days: 7)));
      if (_timeRange == '월간') return r.timestamp.isAfter(now.subtract(const Duration(days: 30)));
      return true;
    }).toList();
  }

  Widget _buildCalendarView(List<HealthRecord> records) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black12)),
      child: TableCalendar(
        firstDay: DateTime.utc(2025, 1, 1),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
          _showDayDetail(selectedDay, records);
        },
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      ),
    );
  }

  void _showDayDetail(DateTime day, List<HealthRecord> records) {
    final dayRecords = records.where((r) => isSameDay(r.timestamp, day)).toList();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${day.month}월 ${day.day}일 건강 기록", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            if (dayRecords.isEmpty) const Text("기록된 내용이 없습니다.")
            else Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: dayRecords.length,
                itemBuilder: (context, i) {
                  final record = dayRecords[i];
                  final creatorName = _codeToName[record.creatorCode] ?? '기타';

                  return ListTile(
                    leading: Icon(Icons.circle, color: record.sugarStatus['color'], size: 12),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
                            children: [
                              TextSpan(text: "[$creatorName] ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                              const TextSpan(text: "혈당(BST): "),
                              TextSpan(text: "${record.sugar}", style: TextStyle(color: record.sugarStatus['color'], fontWeight: FontWeight.bold)),
                              const TextSpan(text: " / 혈압(BP): "),
                              TextSpan(text: "${record.systolic ?? '--'}/${record.diastolic ?? '--'}", style: TextStyle(color: record.bloodPressureStatus['color'], fontWeight: FontWeight.bold)),
                            ],
                          ),
                          softWrap: true,
                        ),
                        if (record.hba1c != null)
                          Text("당화혈색소(HbA1c): ${record.hba1c}%", 
                            style: const TextStyle(fontSize: 15, color: Colors.purple, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    subtitle: Text("${record.type} | 메모: ${record.memo.isEmpty ? '없음' : record.memo}", style: const TextStyle(fontSize: 14)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: Color(0xFF0052CC), size: 28),
                      onPressed: () {
                        Navigator.pop(context); // 바텀시트 닫기
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => InputScreen(recordToEdit: record)),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
