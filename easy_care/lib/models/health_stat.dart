import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// [v1.6 규칙 준수] 모든 화면에서 동일하게 사용하는 의학적 진단 엔진
class HealthRecord {
  final String id;
  final String type; // 공복, 식전, 식후
  final int sugar;
  final int? systolic;
  final int? diastolic;
  final double? hba1c; // 당화혈색소
  final String memo;
  final DateTime timestamp;
  final String? creatorCode; // 가족 연동을 위한 식별 코드

  HealthRecord({
    required this.id,
    required this.type,
    required this.sugar,
    this.systolic,
    this.diastolic,
    this.hba1c,
    required this.memo,
    required this.timestamp,
    this.creatorCode,
  });

  // 1. Firestore 데이터를 객체로 변환 (불러오기용)
  factory HealthRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return HealthRecord(
      id: doc.id,
      type: data['type'] ?? '공복',
      sugar: (data['sugar'] as num?)?.toInt() ?? 0,
      systolic: (data['systolic'] as num?)?.toInt(),
      diastolic: (data['diastolic'] as num?)?.toInt(),
      hba1c: (data['hba1c'] as num?)?.toDouble(),
      memo: data['memo'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creatorCode: data['creatorCode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'sugar': sugar,
      'systolic': systolic,
      'diastolic': diastolic,
      'hba1c': hba1c,
      'memo': memo,
      'timestamp': FieldValue.serverTimestamp(),
      'creatorCode': creatorCode,
    };
  }

  // --- 의학적 상태 진단 로직 (v1.7 핵심) ---

  /// 혈당 상태 진단
  Map<String, dynamic> get sugarStatus {
    if (sugar <= 0) {
      return {"label": "기록 없음", "color": Colors.grey, "msg": "수치를 입력해주세요."};
    }

    // 저혈당 기준 (70 미만)
    if (sugar < 70) {
      return {
        "label": "저혈당",
        "color": Colors.orange.shade800,
        "msg": "당분 섭취가 시급합니다! 🍊",
      };
    }

    if (type == '공복') {
      if (sugar >= 126) {
        return {
          "label": "고혈당(당뇨)",
          "color": Colors.red.shade800,
          "msg": "정밀 검진이 필요합니다. ⚠️",
        };
      }
      if (sugar >= 100) {
        return {
          "label": "공복혈당장애",
          "color": Colors.orange,
          "msg": "주의가 필요한 단계입니다.",
        };
      }
      return {
        "label": "정상",
        "color": const Color(0xFF0052CC),
        "msg": "안정적인 수치입니다. ✅",
      };
    } else {
      // 식전/식후 기준 (140, 200)
      if (sugar >= 200) {
        return {
          "label": "고혈당",
          "color": Colors.red.shade800,
          "msg": "즉시 활동을 줄이고 휴식하세요.",
        };
      }
      if (sugar >= 140) {
        return {
          "label": "식후혈당 높음",
          "color": Colors.orange,
          "msg": "식단 관리에 유의하세요.",
        };
      }
      return {
        "label": "정상",
        "color": const Color(0xFF0052CC),
        "msg": "좋은 상태를 유지 중입니다. ✅",
      };
    }
  }

  /// 혈압 상태 진단
  Map<String, dynamic> get bloodPressureStatus {
    if (systolic == null || diastolic == null) {
      return {"label": "미측정", "color": Colors.grey, "msg": "혈압을 함께 기록해보세요."};
    }

    // 고혈압 기준 (140/90)
    if (systolic! >= 140 || diastolic! >= 90) {
      return {
        "label": "고혈압",
        "color": Colors.red.shade800,
        "msg": "혈압이 높습니다. 안정이 필요해요.",
      };
    }

    // 저혈압 기준 (90/60)
    if (systolic! < 90 || diastolic! < 60) {
      return {
        "label": "저혈압",
        "color": Colors.blue.shade700,
        "msg": "어지러움에 주의하세요.",
      };
    }

    return {
      "label": "혈압 정상",
      "color": const Color(0xFF047857),
      "msg": "혈압이 매우 안정적입니다.",
    };
  }

  /// 당화혈색소 상태 진단
  Map<String, dynamic> get hba1cStatus {
    if (hba1c == null) {
      return {"label": "미측정", "color": Colors.grey, "msg": "정기적인 검사가 필요합니다."};
    }
    if (hba1c! >= 6.5) {
      return {
        "label": "당뇨 수준",
        "color": Colors.red.shade800,
        "msg": "의사와 상담이 필요한 수치입니다. ⚠️",
      };
    }
    if (hba1c! >= 5.7) {
      return {
        "label": "당뇨 전단계",
        "color": Colors.orange,
        "msg": "생활 습관 관리가 시작되어야 합니다.",
      };
    }
    return {
      "label": "정상",
      "color": Colors.purple,
      "msg": "아주 건강한 수치입니다. ✅",
    };
  }

  /// 전체 데이터 중 하나라도 위험(Danger) 상태인지 확인
  bool get isDanger {
    final s = sugarStatus['label'];
    final b = bloodPressureStatus['label'];
    final h = hba1cStatus['label'];
    
    return s.contains("고혈당") || s.contains("저혈당") || 
           b.contains("고혈압") || b.contains("저혈압") || 
           h.contains("당뇨 수준");
  }
}
