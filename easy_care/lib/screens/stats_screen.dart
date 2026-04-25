import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('건강 분석 리포트', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // 모델 리스트로 변환
          final allRecords = snapshot.data!.docs
              .map((doc) => HealthRecord.fromFirestore(doc))
              .toList();

          if (allRecords.isEmpty) return const Center(child: Text("기록된 데이터가 없습니다."));

          final filteredRecords = _filterRecordsByRange(allRecords);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // [규칙 3] 차트 모드일 때 혈당/혈압 전환 토글 및 기간 필터
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

  // --- [규칙 3] 혈당/혈압 전환 토글 ---
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

  Widget _buildChartView(List<HealthRecord> records, bool isDark) {
    if (records.isEmpty) return const SizedBox(height: 300, child: Center(child: Text("기록이 없습니다.")));

    return Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 40, 25, 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: LineChart(
        LineChartData(
          // [규칙 3] 의학적 기준선(ExtraLines) 추가
          extraLinesData: ExtraLinesData(
            horizontalLines: _chartType == '혈당' 
              ? [HorizontalLine(y: 140, color: Colors.redAccent.withOpacity(0.5), strokeWidth: 2, dashArray: [5, 5], label: HorizontalLineLabel(show: true, alignment: Alignment.topRight, labelResolver: (line) => '식후기준'))]
              : [HorizontalLine(y: 140, color: Colors.redAccent.withOpacity(0.5), strokeWidth: 2, dashArray: [5, 5], label: HorizontalLineLabel(show: true, labelResolver: (line) => '고혈압'))],
          ),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: _getLineBarsData(records),
        ),
      ),
    );
  }

  List<LineChartBarData> _getLineBarsData(List<HealthRecord> records) {
    final reversed = records.reversed.toList();
    if (_chartType == '혈당') {
      return [
        LineChartBarData(
          spots: List.generate(reversed.length, (i) => FlSpot(i.toDouble(), reversed[i].sugar.toDouble())),
          isCurved: true,
          color: const Color(0xFF0052CC),
          barWidth: 5,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: const Color(0xFF0052CC).withOpacity(0.1)),
        )
      ];
    } else {
      // 혈압은 수축기/이완기 두 줄 표시
      return [
        LineChartBarData(
          spots: List.generate(reversed.length, (i) => FlSpot(i.toDouble(), (reversed[i].systolic ?? 0).toDouble())),
          color: Colors.orange,
          barWidth: 4,
          dotData: const FlDotData(show: true),
        ),
        LineChartBarData(
          spots: List.generate(reversed.length, (i) => FlSpot(i.toDouble(), (reversed[i].diastolic ?? 0).toDouble())),
          color: Colors.blue,
          barWidth: 4,
          dotData: const FlDotData(show: true),
        ),
      ];
    }
  }

  Widget _buildSummaryFeedback(List<HealthRecord> records) {
    if (records.isEmpty) return const SizedBox();
    
    // 평균 수치 계산
    double avgSugar = records.map((r) => r.sugar).reduce((a, b) => a + b) / records.length;
    
    // [v1.5 규칙] 18px 이상 폰트 및 상태별 컬러 피드백
    Color themeColor = avgSugar > 140 ? Colors.red.shade800 : const Color(0xFF0052CC);

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
          Text("나의 $_timeRange 요약", style: TextStyle(color: themeColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            avgSugar > 140 
              ? "평균 혈당이 다소 높습니다. 식단 관리에 조금 더 신경 써주세요! 🥗"
              : "안정적으로 잘 관리하고 계십니다. 지금처럼만 유지하세요! 👍",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ],
      ),
    );
  }

  // --- 데이터 필터 로직 ---
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
                itemBuilder: (context, i) => ListTile(
                  leading: Icon(Icons.circle, color: dayRecords[i].sugarStatus['color'], size: 12),
                  title: Text("혈당: ${dayRecords[i].sugar} / 혈압: ${dayRecords[i].systolic ?? '--'}/${dayRecords[i].diastolic ?? '--'}"),
                  subtitle: Text("${dayRecords[i].type} 기록 - ${dayRecords[i].memo}"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}