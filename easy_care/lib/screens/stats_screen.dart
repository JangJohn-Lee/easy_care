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
import '../models/health_stat.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isCalendarView = false;
  String _timeRange = '주간';
  String _chartType = '혈당'; // [규칙 3] 혈당/혈압 전환용
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<String> _allowedCodes = [];
  bool _isLoadingCodes = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyCodes();
  }

  Future<void> _loadFamilyCodes() async {
    final prefs = await SharedPreferences.getInstance();
    final myCode = prefs.getString('myFamilyCode');
    final familyJson = prefs.getString('familyMembers');

    List<String> codes = [];
    if (myCode != null && myCode.isNotEmpty) {
      codes.add(myCode);
    }
    if (familyJson != null) {
      final List<dynamic> familyList = json.decode(familyJson);
      for (var f in familyList) {
        if (f['code'] != null) {
          codes.add(f['code']);
        }
      }
    }
    
    // Firestore 'whereIn' supports up to 10 items.
    if (codes.length > 10) {
      codes = codes.sublist(0, 10);
    }

    setState(() {
      _allowedCodes = codes;
      _isLoadingCodes = false;
    });
  }

  Future<void> _exportReport() async {
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
      final allRecords = snapshot.docs
          .map((doc) => HealthRecord.fromFirestore(doc))
          .where((r) => _allowedCodes.isEmpty || r.creatorCode == null || _allowedCodes.contains(r.creatorCode))
          .toList();

      final targetRecords = allRecords.where((r) {
        return r.timestamp.isAfter(dateRange.start.subtract(const Duration(seconds: 1))) &&
               r.timestamp.isBefore(dateRange.end.add(const Duration(days: 1)));
      }).toList();

      if (targetRecords.isEmpty) {
        if (mounted) Navigator.pop(context);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('해당 기간에 데이터가 없습니다.')));
        return;
      }

      List<String> rows = [];
      rows.add("일시,구분,혈당(mg/dL),혈압(수축기/이완기),메모"); // 헤더

      for (var r in targetRecords) {
        String dateStr = DateFormat('yyyy-MM-dd HH:mm').format(r.timestamp);
        String bpStr = r.systolic != null && r.diastolic != null ? '${r.systolic}/${r.diastolic}' : '미측정';
        String memoSafe = '"${r.memo.replaceAll('"', '""')}"';
        rows.add("$dateStr,${r.type},${r.sugar},$bpStr,$memoSafe");
      }

      String csv = rows.join("\n");
      List<int> bytes = [0xEF, 0xBB, 0xBF] + utf8.encode(csv); // UTF-8 BOM

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/easycare_report.csv');
      await file.writeAsBytes(bytes);

      if (mounted) Navigator.pop(context);
      if (mounted) await Share.shareXFiles([XFile(file.path)], text: '건강 분석 리포트');
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

          final allRecords = snapshot.data!.docs
              .map((doc) => HealthRecord.fromFirestore(doc))
              .where((r) => _allowedCodes.isEmpty || r.creatorCode == null || _allowedCodes.contains(r.creatorCode))
              .toList();

          if (allRecords.isEmpty) return const Center(child: Text("기록된 데이터가 없습니다."));

          final filteredRecords = _filterRecordsByRange(allRecords);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (!_isCalendarView) ...[
                  _buildChartTypeToggle(),
                  const SizedBox(height: 16),
                  _buildTimeFilter(),
                ],
                const SizedBox(height: 20),

                _isCalendarView
                    ? _buildCalendarView(allRecords)
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

  // --- 차트 그리기 (최고/최저 가로선 및 툴팁 로직 강화) ---
  Widget _buildChartView(List<HealthRecord> records, bool isDark) {
    if (records.isEmpty) return const SizedBox(height: 300, child: Center(child: Text("해당 기간에 기록이 없습니다.")));

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

    // 3. ExtraLines (가로선) 리스트 구성 - 정상선 + 최고선 + 최저선
    List<HorizontalLine> horizontalLines = [
      HorizontalLine(
        y: baselineY,
        color: const Color(0xFF047857).withOpacity(0.5), 
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
      horizontalLines.add(HorizontalLine(
        y: maxSugarVal,
        color: Colors.redAccent.withOpacity(0.5), strokeWidth: 1.5, dashArray: [4, 4],
        label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold), labelResolver: (_) => '최고 ($maxSugarVal)'),
      ));
      if (maxSugarVal != minSugarVal) {
        horizontalLines.add(HorizontalLine(
          y: minSugarVal,
          color: Colors.blueAccent.withOpacity(0.5), strokeWidth: 1.5, dashArray: [4, 4],
          label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold), labelResolver: (_) => '최저 ($minSugarVal)'),
        ));
      }
    } else {
      horizontalLines.add(HorizontalLine(
        y: maxSysVal,
        color: Colors.redAccent.withOpacity(0.5), strokeWidth: 1.5, dashArray: [4, 4],
        label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold), labelResolver: (_) => '최고 수축기 ($maxSysVal)'),
      ));
      if (maxSysVal != minDiaVal) {
        horizontalLines.add(HorizontalLine(
          y: minDiaVal,
          color: Colors.blueAccent.withOpacity(0.5), strokeWidth: 1.5, dashArray: [4, 4],
          label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold), labelResolver: (_) => '최저 이완기 ($minDiaVal)'),
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
            // 터치 시 나타나는 수직선(인디케이터) 디자인 커스텀
            getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
              return spotIndexes.map((spotIndex) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: isDark ? Colors.white30 : Colors.grey.shade400, // 그래프 선과 차별화된 회색
                    strokeWidth: 2,
                    dashArray: [4, 4], // 점선으로 처리
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 5,
                        color: barData.color ?? Colors.blue,
                        strokeWidth: 2,
                        strokeColor: isDark ? Colors.black : Colors.white,
                      );
                    },
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => isDark ? Colors.grey.shade800 : Colors.black87.withOpacity(0.8),
              tooltipRoundedRadius: 8,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final record = reversed[touchedSpot.spotIndex];
                  final dateStr = "${record.timestamp.month}/${record.timestamp.day}";
                  
                  if (_chartType == '혈당') {
                    return LineTooltipItem(
                      '$dateStr\n',
                      const TextStyle(color: Colors.white70, fontSize: 12),
                      children: [
                        TextSpan(
                          text: '혈당: ${record.sugar}', // 혈당:숫자 명확히 표기
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    );
                  } else {
                    bool isSys = touchedSpot.barIndex == 0;
                    String prefix = isSys ? "수축기: " : "이완기: ";
                    int val = isSys ? (record.systolic ?? 0) : (record.diastolic ?? 0);
                    Color valColor = isSys ? Colors.orangeAccent : Colors.lightBlueAccent;

                    return LineTooltipItem(
                      '$dateStr\n',
                      const TextStyle(color: Colors.white70, fontSize: 12),
                      children: [
                        TextSpan(
                          text: '$prefix$val',
                          style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    );
                  }
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

  // 선 굵기 조절 (barWidth: 2) 및 항상 떠있는 툴팁 적용
  List<LineChartBarData> _getLineBarsData(
    List<HealthRecord> reversedRecords, int maxSugarIdx, int minSugarIdx, int maxSysIdx, int minDiaIdx
  ) {
    if (_chartType == '혈당') {
      return [
        LineChartBarData(
          spots: List.generate(reversedRecords.length, (i) => FlSpot(i.toDouble(), reversedRecords[i].sugar.toDouble())),
          isCurved: true,
          color: const Color(0xFF0052CC),
          barWidth: 2, // 선을 얇게 조정
          dotData: const FlDotData(show: true), 
          belowBarData: BarAreaData(show: true, color: const Color(0xFF0052CC).withOpacity(0.1)),
          showingIndicators: {maxSugarIdx, minSugarIdx}.toList(), 
        )
      ];
    } else {
      return [
        LineChartBarData(
          spots: List.generate(reversedRecords.length, (i) => FlSpot(i.toDouble(), (reversedRecords[i].systolic ?? 0).toDouble())),
          isCurved: true,
          color: Colors.orange,
          barWidth: 2, // 선을 얇게 조정
          dotData: const FlDotData(show: true),
          showingIndicators: {maxSysIdx}.toList(),
        ),
        LineChartBarData(
          spots: List.generate(reversedRecords.length, (i) => FlSpot(i.toDouble(), (reversedRecords[i].diastolic ?? 0).toDouble())),
          isCurved: true,
          color: Colors.blue,
          barWidth: 2, // 선을 얇게 조정
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
      if (avgSugar > 140) {
        themeColor = Colors.red.shade800;
        summaryText = "평균 혈당이 다소 높습니다.\n식단 관리에 조금 더 신경 써주세요! 🥗";
      } else {
        themeColor = const Color(0xFF0052CC);
        summaryText = "안정적으로 잘 관리하고 계십니다.\n지금처럼만 유지하세요! 👍";
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: themeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("나의 $_timeRange 요약 ($_chartType)", style: TextStyle(color: themeColor, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  return ListTile(
                    leading: Icon(Icons.circle, color: record.sugarStatus['color'], size: 12),
                    title: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
                        children: [
                          const TextSpan(text: "혈당: "),
                          TextSpan(text: "${record.sugar}", style: TextStyle(color: record.sugarStatus['color'], fontWeight: FontWeight.bold)),
                          const TextSpan(text: " / 혈압: "),
                          TextSpan(text: "${record.systolic ?? '--'}/${record.diastolic ?? '--'}", style: TextStyle(color: record.bloodPressureStatus['color'], fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    subtitle: Text("${record.type} | 메모: ${record.memo.isEmpty ? '없음' : record.memo}", style: const TextStyle(fontSize: 14)),
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