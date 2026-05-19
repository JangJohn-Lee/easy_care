import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_stat.dart'; 
import '../widgets/menu_card.dart';
import 'input_screen.dart';
import 'stats_screen.dart';
import 'my_page_screen.dart';
import 'family_screen.dart';

class ModernDashboard extends StatefulWidget {
  final VoidCallback onThemeToggle;
  const ModernDashboard({super.key, required this.onThemeToggle});

  @override
  State<ModernDashboard> createState() => _ModernDashboardState();
}

class _ModernDashboardState extends State<ModernDashboard> {
  String _userName = '사용자';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? '사용자';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          HealthRecord? lastRecord;
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            lastRecord = HealthRecord.fromFirestore(snapshot.data!.docs.first);
          }

          // [v1.5 규칙] 통합 진단 로직 활용
          final sugarInfo = lastRecord?.sugarStatus ?? {
            "label": "기록 없음", 
            "color": const Color(0xFF0052CC), 
            "msg": "첫 기록을 시작해보세요!"
          };
          
          // bpInfo 활용: 혈압 상태 진단 데이터 가져오기
          final bpInfo = lastRecord?.bloodPressureStatus;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    color: sugarInfo['color'],
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: (sugarInfo['color'] as Color).withOpacity(0.4),
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
                            "최근 혈당 (${lastRecord?.type ?? '미정'})",
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
                        ],
                      ),
                      
                      const Divider(color: Colors.white24, height: 32),
                      
                      // --- [규칙 3] bpInfo를 활용한 혈압 진단 표시 ---
                      Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Colors.white70, size: 38),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              lastRecord?.systolic != null 
                                  ? "혈압: ${lastRecord!.systolic}/${lastRecord.diastolic} (${bpInfo!['label']})"
                                  : "혈압: 기록 없음",
                              style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // 통합 상태 메시지 배지 (혈당 기준)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          sugarInfo['msg'],
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