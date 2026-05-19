import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// [v1.6 규칙 준수] 모든 화면에서 동일하게 사용하는 의학적 진단 엔진
class HealthRecord {
  final String id;
  final String type; // 공복, 식전, 식후
  final int sugar;
  final int? systolic;
  final int? diastolic;
  final String memo;
  final DateTime timestamp;
  final String? creatorCode; // 가족 연동을 위한 식별 코드

  HealthRecord({
    required this.id,
    required this.type,
    required this.sugar,
    this.systolic,
    this.diastolic,
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
}
