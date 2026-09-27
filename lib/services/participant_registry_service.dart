import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/experiment_config.dart';

/// 실험운영 시트(Apps Script 웹 앱)에 참가자를 조회하고 세션을 기록한다.
///
/// 엔드포인트는 빌드 시 `--dart-define=REGISTRY_URL=…`로 주입한다
/// (`scripts/apps_script/Code.gs` 참고). 비어 있으면 [isEnabled]가 false이고
/// 시작 화면은 그룹 A/B 직접 선택으로 동작한다 (로컬 개발·테스트용).
class ParticipantRegistryService {
  final http.Client _client;
  final String baseUrl;

  ParticipantRegistryService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        baseUrl = baseUrl ?? ExperimentConfig.registryUrl;

  bool get isEnabled => baseUrl.isNotEmpty;

  static const _timeout = Duration(seconds: 12);

  /// 번호+이름이 배정표와 일치하면 조건을 돌려준다.
  Future<RegistryLookup> lookup({
    required String pid,
    required String name,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'action': 'lookup',
      'pid': pid,
      'name': name,
    });
    try {
      final res = await _client.get(uri).timeout(_timeout);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['ok'] == true) {
        final c = ExperimentConfig.conditionFromLabel(data['condition'] as String?);
        if (c == null) return const RegistryLookup.failure('no_condition');
        return RegistryLookup.success(c, pid: data['pid'] as String? ?? pid);
      }
      return RegistryLookup.failure(data['reason'] as String? ?? 'unknown');
    } catch (e) {
      return RegistryLookup.failure('network', detail: e.toString());
    }
  }

  /// 세션 시작을 세션기록 탭에 남긴다. 실패해도 실험은 진행한다.
  Future<bool> logStart({
    required String pid,
    required String name,
    required String condition,
    required DateTime startedAt,
  }) async {
    final uri = Uri.parse(baseUrl).replace(queryParameters: {
      'action': 'start',
      'pid': pid,
      'name': name,
      'condition': condition,
      'startedAt': startedAt.toIso8601String(),
    });
    try {
      final res = await _client.get(uri).timeout(_timeout);
      return (jsonDecode(res.body) as Map)['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  /// 내보내기 JSON 전문을 시트 쪽(Drive 폴더)에 백업한다.
  ///
  /// Content-Type을 text/plain으로 보내야 브라우저가 CORS preflight를 생략해
  /// Apps Script 웹 앱이 받을 수 있다.
  Future<String?> backupExport(String jsonBody) async {
    try {
      final res = await _client
          .post(Uri.parse(baseUrl),
              headers: {'Content-Type': 'text/plain;charset=utf-8'},
              body: jsonBody)
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['ok'] == true ? data['fileUrl'] as String? : null;
    } catch (_) {
      return null;
    }
  }
}

class RegistryLookup {
  final bool ok;
  final ExperimentCondition? condition;
  final String? pid;
  final String? reason;
  final String? detail;

  const RegistryLookup.success(this.condition, {this.pid})
      : ok = true,
        reason = null,
        detail = null;

  const RegistryLookup.failure(this.reason, {this.detail})
      : ok = false,
        condition = null,
        pid = null;

  /// 참가자에게 보여 줄 문구. 조건이나 시트 구조는 드러내지 않는다.
  String get message {
    switch (reason) {
      case 'not_found':
      case 'name_mismatch':
      case 'missing':
        return '참가자 번호나 이름이 맞지 않습니다. 진행자에게 확인해 주세요.';
      case 'unavailable':
        return '이 번호는 사용할 수 없는 상태입니다. 진행자에게 확인해 주세요.';
      case 'network':
        return '확인 서버에 연결할 수 없습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.';
      default:
        return '참가자 확인에 실패했습니다. 진행자에게 알려 주세요.';
    }
  }
}
