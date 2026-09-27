import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/experiment_config.dart';
import '../models/chat_session.dart';
import '../models/telemetry.dart';

/// 진행 중인 세션의 자동 저장본.
///
/// 대화는 브라우저 메모리에만 있어 뒤로 가기·새로고침 한 번에 사라진다
/// (2026-09-27 현장에서 두 번 발생). 메시지·기록이 바뀔 때마다 여기에 저장하고,
/// 페이지가 다시 열리면 시작 화면이 "이어서 진행"을 제안한다.
class SessionSnapshot {
  final DateTime savedAt;
  final ExperimentCondition condition;
  final String? station;
  final int turnCounter;
  final bool exported;
  final ChatSession session;
  final SessionTelemetry telemetry;

  const SessionSnapshot({
    required this.savedAt,
    required this.condition,
    this.station,
    required this.turnCounter,
    required this.exported,
    required this.session,
    required this.telemetry,
  });

  ParticipantInfo? get participant => telemetry.participant;

  /// 복구를 제안할 만한가: 저장 버튼을 안 눌렀고, 메시지가 있고, 너무 오래되지 않았다.
  bool get isResumable =>
      !exported &&
      session.messages.isNotEmpty &&
      DateTime.now().difference(savedAt) < const Duration(hours: 6);

  Map<String, dynamic> toJson() => {
        'version': 1,
        'savedAt': savedAt.toIso8601String(),
        'condition': condition.name,
        'station': station,
        'turnCounter': turnCounter,
        'exported': exported,
        'session': session.toJson(),
        'telemetry': telemetry.toJson(),
      };

  factory SessionSnapshot.fromJson(Map<String, dynamic> j) => SessionSnapshot(
        savedAt: DateTime.parse(j['savedAt'] as String),
        condition: ExperimentCondition.values.byName(j['condition'] as String),
        station: j['station'] as String?,
        turnCounter: j['turnCounter'] as int? ?? 0,
        exported: j['exported'] as bool? ?? false,
        session: ChatSession.fromJson((j['session'] as Map).cast<String, dynamic>()),
        telemetry:
            SessionTelemetry.fromJson((j['telemetry'] as Map).cast<String, dynamic>()),
      );
}

class SessionPersistenceService {
  static const storageKey = 'session_snapshot_v1';

  Future<void> save(SessionSnapshot snapshot) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(snapshot.toJson()));
    } catch (_) {
      // 저장 실패는 실험을 막지 않는다 (용량 초과 등).
    }
  }

  Future<SessionSnapshot?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return null;
      return SessionSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } catch (_) {}
  }
}
