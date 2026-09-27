#!/usr/bin/env bash
# 배포: 시트 조회 URL을 넣어 빌드하고 Firebase Hosting(addie-tutor.web.app)에 올린다.
#
#   ./deploy.sh              # .env.deploy의 REGISTRY_URL로 빌드 + 배포
#   ./deploy.sh --build-only # 빌드만
#   ./deploy.sh --no-build   # 이미 만든 build/web을 그대로 올리기 (실험 당일 아침)
#   ./deploy.sh --down       # 사이트 내리기 (실험 끝나면)
#
# 실험할 때만 올리고 평소에는 내려 둔다. 내려 두면 주소도 키도 노출되지 않는다.
set -euo pipefail
cd "$(dirname "$0")"

if [[ "${1:-}" == "--down" ]]; then
  firebase hosting:disable --project addie-tutor --force
  echo "내렸습니다. 다시 올리려면 ./deploy.sh --no-build"
  exit 0
fi

if [[ -f .env.deploy ]]; then
  # shellcheck disable=SC1091
  set -a; source .env.deploy; set +a
fi
: "${REGISTRY_URL:?REGISTRY_URL이 없습니다. .env.deploy에 넣거나 환경변수로 주세요 (scripts/apps_script/Code.gs 참고)}"

grep -q "projectId: 'addie-tutor'" lib/firebase_options.dart || {
  echo "lib/firebase_options.dart가 addie-tutor를 가리키지 않습니다. flutterfire configure --project=addie-tutor --platforms=web"; exit 1; }

if [[ "${1:-}" != "--no-build" ]]; then
flutter build web \
  --dart-define=BUILD_COMMIT="$(git rev-parse --short HEAD)" \
  --dart-define=BUILD_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')" \
  --dart-define=REGISTRY_URL="$REGISTRY_URL" \
  ${RECAPTCHA_SITE_KEY:+--dart-define=RECAPTCHA_SITE_KEY="$RECAPTCHA_SITE_KEY"}
fi

if [[ "${1:-}" == "--build-only" ]]; then exit 0; fi
[[ -f build/web/index.html ]] || { echo "build/web이 없습니다. 먼저 ./deploy.sh 로 빌드하세요."; exit 1; }
firebase deploy --only hosting --project addie-tutor
echo
echo "참가자 링크: https://addie-tutor.web.app/   (번호 미리 채우기: ?pid=P001)"
