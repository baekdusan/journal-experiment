// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

/// 브라우저·기기 환경 스냅샷. 내보내기 파일의 `environment`에 실린다.
Map<String, dynamic> environmentSnapshot() {
  final nav = html.window.navigator;
  final screen = html.window.screen;
  final now = DateTime.now();
  return {
    'platform': 'web',
    'href': html.window.location.href,
    'userAgent': nav.userAgent,
    'language': nav.language,
    'languages': nav.languages,
    'navigatorPlatform': nav.platform,
    'hardwareConcurrency': nav.hardwareConcurrency,
    'cookieEnabled': nav.cookieEnabled,
    'online': nav.onLine,
    'screen': {
      'width': screen?.width,
      'height': screen?.height,
      'availWidth': screen?.available.width,
      'availHeight': screen?.available.height,
      'colorDepth': screen?.colorDepth,
    },
    'devicePixelRatio': html.window.devicePixelRatio,
    'timezoneName': now.timeZoneName,
    'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
    ...viewportSnapshot(),
  };
}

Map<String, dynamic> viewportSnapshot() => {
      'viewport': {
        'width': html.window.innerWidth,
        'height': html.window.innerHeight,
        'outerWidth': html.window.outerWidth,
        'outerHeight': html.window.outerHeight,
      },
    };

void downloadTextFile(String filename, String content, String mimeType) {
  final blob = html.Blob([content], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

/// 탭 이탈·창 포커스·크기 변경·네트워크 상태를 구독한다.
///
/// [warnBeforeUnload]가 true면 새로고침·닫기 시 브라우저 확인창을 띄운다.
/// 대화 기록이 메모리에만 있어 새로고침 한 번으로 데이터가 사라지기 때문이다.
void Function() listenWindowEvents(
  void Function(String type, Map<String, dynamic> data) onEvent, {
  bool warnBeforeUnload = false,
}) {
  final subs = <StreamSubscription>[];

  subs.add(html.document.onVisibilityChange.listen((_) {
    onEvent('visibility', {'state': html.document.visibilityState});
  }));
  subs.add(html.window.onFocus.listen((_) => onEvent('window.focus', {})));
  subs.add(html.window.onBlur.listen((_) => onEvent('window.blur', {})));
  subs.add(html.window.onResize.listen((_) {
    onEvent('window.resize', viewportSnapshot());
  }));
  subs.add(html.window.onOnline.listen((_) => onEvent('network', {'online': true})));
  subs.add(html.window.onOffline.listen((_) => onEvent('network', {'online': false})));
  subs.add(html.window.onPageHide.listen((_) => onEvent('pagehide', {})));

  if (warnBeforeUnload) {
    subs.add(html.window.onBeforeUnload.listen((event) {
      onEvent('beforeunload', {});
      (event as html.BeforeUnloadEvent).returnValue = '';
    }));
  }

  return () {
    for (final s in subs) {
      s.cancel();
    }
  };
}
