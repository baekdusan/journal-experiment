// 웹 전용 API(dart:html)를 조건부 import로 감싼 진입점.
//
// 테스트(VM)에서는 스텁이 붙어 `dart:html`이 없어도 컴파일된다.
export 'web_env_stub.dart' if (dart.library.html) 'web_env_web.dart';
