/// 비웹 플랫폼(테스트 VM 등)용 스텁. 웹 구현은 [web_env_web.dart].
Map<String, dynamic> environmentSnapshot() => const {'platform': 'non-web'};

Map<String, dynamic> viewportSnapshot() => const {};

void downloadTextFile(String filename, String content, String mimeType) {}

/// 창 단위 브라우저 이벤트를 구독한다. 반환값은 해제 함수.
void Function() listenWindowEvents(
  void Function(String type, Map<String, dynamic> data) onEvent, {
  bool warnBeforeUnload = false,
}) =>
    () {};
