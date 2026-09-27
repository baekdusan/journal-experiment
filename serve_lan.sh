#!/usr/bin/env bash
# 현장용: 이 노트북에서 build/web을 같은 네트워크에 서빙한다.
#
#   ./serve_lan.sh            # 빌드 후 서빙 (기본 포트 8080)
#   ./serve_lan.sh --no-build # 빌드 생략
#   PORT=9000 ./serve_lan.sh
#
# 배포하지 않으므로 App Check·사이트 키가 필요 없다. 실험이 끝나면 Ctrl-C.
# 각 PC의 브라우저는 여기서 페이지만 받고, Gemini 호출은 PC에서 구글로 직접 나간다
# (PC들도 인터넷이 되어야 한다).
set -euo pipefail
cd "$(dirname "$0")"
PORT="${PORT:-8080}"

if [[ "${1:-}" != "--no-build" ]]; then
  flutter build web \
    --dart-define=BUILD_COMMIT="$(git rev-parse --short HEAD)" \
    --dart-define=BUILD_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
fi

IP="$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')"
echo
echo "================ 참가자 PC에서 열 주소 ================"
echo "  기본 주소:      http://${IP}:${PORT}/        (REGISTRY_URL 없는 로컬 빌드: 번호 + 그룹 A/B 선택)"
echo "  미리 선택 링크: http://${IP}:${PORT}/?condition=a   (A = 처치군)"
echo "                  http://${IP}:${PORT}/?condition=b   (B = 대조군)"
echo "  이 노트북 확인용: http://localhost:${PORT}/"
echo "======================================================="
echo "노트북이 잠들지 않게 caffeinate로 감싸 실행합니다. 종료는 Ctrl-C."
echo

cd build/web
exec caffeinate -i python3 -u -m http.server "$PORT" --bind 0.0.0.0
