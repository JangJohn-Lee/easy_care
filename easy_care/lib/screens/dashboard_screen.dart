import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_stat.dart';
import 'input_screen.dart';
import 'stats_screen.dart';
import 'family_screen.dart';
import 'my_page_screen.dart';
import '../widgets/menu_card.dart';

class ModernDashboard extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const ModernDashboard({super.key, required this.onThemeToggle});

  @override
  State<ModernDashboard> createState() => _ModernDashboardState();
}

class _ModernDashboardState extends State<ModernDashboard> {
  String _userName = '사용자';
  String? _myCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? '사용자';
      _myCode = prefs.getString('myFamilyCode');
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('혈당도우미', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: widget.onThemeToggle,
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
              .collection('health_records')
              .orderBy('timestamp', descending: true)
              .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("오류: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          HealthRecord? lastRecord;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            final docs = snapshot.data!.docs;
            final myDocs = docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final code = data['creatorCode'];
              return _myCode == null || _myCode!.isEmpty || code == null || code == _myCode;
            }).toList();

            if (myDocs.isNotEmpty) {
              lastRecord = HealthRecord.fromFirestore(myDocs.first);
            }
          }

          // [v1.5 규칙] 통합 진단 로직 활용
          final sugarInfo = lastRecord?.sugarStatus ?? {
            "label": "기록 없음",
            "color": const Color(0xFF0052CC),
            "msg": "첫 기록을 시작해보세요!"
          };

          // bpInfo 활용: 혈압 상태 진단 데이터 가져오기
          final bpInfo = lastRecord?.bloodPressureStatus;
          final hba1cInfo = lastRecord?.hba1cStatus;
          final isDanger = lastRecord?.isDanger ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDanger) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade800,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "위험 수치가 감지되었습니다!\n상태 확인 및 관리가 필요합니다.",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text(
                  "안녕하세요,\n$_userName님! 👋",
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, height: 1.2),
                ),
                const SizedBox(height: 24),

                // --- [규칙 3] 하이브리드 대시보드 카드 ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDanger ? Colors.red.shade900 : sugarInfo['color'],
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: (isDanger ? Colors.red.shade900 : sugarInfo['color'] as Color).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "최근 혈당 (BST) (${lastRecord?.type ?? '미정'})",
                            style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          if (lastRecord != null)
                            const Icon(Icons.verified_user_rounded, color: Colors.white70, size: 20),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            lastRecord?.sugar.toString() ?? "--",
                            style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Text("mg/dL", style: TextStyle(color: Colors.white60, fontSize: 20)),
                          const Spacer(),
                          if (lastRecord != null)
                            Text(
                              "(${sugarInfo['label']})",
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      
                      const Divider(color: Colors.white24, height: 32),
                      
                      // --- [규칙 3] bpInfo를 활용한 혈압 진단 표시 ---
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Colors.white70, size: 38),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.visible,
                              text: TextSpan(
                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600),
                                children: [
                                  TextSpan(
                                    text: lastRecord?.systolic != null 
                                        ? "혈압 (BP): ${lastRecord!.systolic}/${lastRecord.diastolic} "
                                        : "혈압 (BP): 기록 없음 ",
                                  ),
                                  if (lastRecord?.systolic != null)
                                    TextSpan(
                                      text: "(${bpInfo!['label']})",
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (lastRecord?.hba1c != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.analytics_rounded, color: Colors.white70, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              "당화혈색소 (HbA1c): ${lastRecord!.hba1c}%",
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "(${hba1cInfo!['label']})",
                              style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      
                      // 통합 상태 메시지 배지
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          isDanger ? "⚠️ 즉시 안정을 취하고 혈당/혈압을 재측정하세요." : sugarInfo['msg'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                const Text("신속한 관리", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    MenuCard(
                      title: "기록하기",
                      icon: Icons.add_a_photo_rounded,
                      color: const Color(0xFF4338CA),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const InputScreen()),
                      ),
                    ),
                    MenuCard(
                      title: "통계분석",
                      icon: Icons.analytics_rounded,
                      color: const Color(0xFFB45309),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const StatsScreen()),
                      ),
                    ),
                    MenuCard(
                      title: "가족연결", 
                      icon: Icons.family_restroom_rounded, 
                      color: const Color(0xFF047857), 
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FamilyScreen()),
                      ),
                    ),
                    MenuCard(
                      title: "마이페이지", 
                      icon: Icons.person_rounded, 
                      color: const Color(0xFF374151), 
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MyPageScreen(onThemeToggle: widget.onThemeToggle)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}