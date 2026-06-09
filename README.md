# Research ADDIE Chatbot

ADDIE 모델 기반 적응형 학습 튜터 시스템

## 실험 운영 모드

- 현재 앱은 **단일 세션 모드**로 동작합니다.
- 사이드바와 세션 전환 UI는 제거했고, 한 번에 하나의 학습 흐름만 진행하는 것을 전제로 합니다.
- 새로 시작하려면 상단 우측의 **초기화 버튼(↻)** 을 누르면 됩니다. 현재 대화와 학습 상태(SharedPreferences 영속분 포함)가 모두 비워집니다.
- 비스트리밍 응답(니즈 분석·피드백·로드맵 설계) 준비 중에는 채팅창에 **타이핑 인디케이터**가 표시됩니다.

## 프로젝트 개요

학습자의 니즈를 분석하고, 교수설계안(Syllabus)을 생성하며, 대화형으로 수업을 진행하는 AI 튜터 챗봇입니다.

### 연구 가설

> "어떠한 학습 주제든 ADDIE 프레임워크를 따르면 학습자 맞춤형 대화형 교육이 가능하다"

### 학습 흐름

```
[1단계: 니즈 분석]    →    [2단계: 교수설계]    →    [3단계: 대화형 수업]
      ↓                         ↓                         ↓
  Analyst 모드              Syllabus 생성             Tutor 모드
  학습자 프로파일 수집       1~5단계 로드맵 자동 생성     스트리밍 튜터링
                                                      ↓
                                                 [피드백 반영]
                                                      ↓
                                                 Feedback 모드
                                                 로드맵 재설계
```

---

## 핵심 아키텍처: Stateless Micro-Agent Pattern

### 설계 철학

기존의 "Fat Agent" (LLM이 상태를 보고 모든 것을 판단) 방식에서 **"Thin Micro-Services"** (앱이 상태를 보고 판단, LLM은 생성만) 방식으로 전환하여 레이턴시와 비용을 최적화했습니다.

| 항목 | 기존 방식 | 현재 방식 |
|------|----------|----------|
| 결정 주체 | LLM이 상태를 보고 판단 | **앱 코드**가 상태를 보고 판단 |
| LLM 역할 | 사고 + 판단 + 생성 | **생성만** |
| 상태 관리 | LLM 컨텍스트 내 | **외부 (Riverpod)** |
| 프롬프트 | 하나의 거대한 프롬프트 | **역할별 작은 프롬프트** |
| 레이턴시 | ~30초/턴 | **2~5초/턴** |

### 서비스 구성

```
┌─────────────────────────────────────────────────────────────┐
│                    App Orchestrator                         │
│                  (ChatController + Riverpod)                │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ↓                   ↓                   ↓
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ IntentClassifier│ │ Conversational  │ │ SyllabusDesigner│
│    Service      │ │  AgentService   │ │    Service      │
├─────────────────┤ ├─────────────────┤ ├─────────────────┤
│ - 의도 분류     │ │ - Analyst 모드  │ │ - Syllabus 생성 │
│ - in/out class │ │ - Tutor 모드    │ │ - 1~5단계 구성  │
│                 │ │ - Feedback 모드 │ │                 │
└─────────────────┘ └─────────────────┘ └─────────────────┘
        ↓                   ↓                   ↓
   gemini-2.5-flash   gemini-2.5-flash   gemini-3.5-flash
   (분류/추출용)       (튜터 스트리밍)    (교수설계, global)
```

> 모델명과 location은 `lib/config/ai_models.dart`(`AiModels`)에 (모델, location) 쌍으로 중앙화되어 있다. 교체 시 이 파일만 수정한다.

---

## 기술 스택

| 구분 | 기술 |
|------|------|
| 프론트엔드 | Flutter Web |
| 상태 관리 | Riverpod (코드 생성) |
| AI 백엔드 | Firebase AI (Vertex AI), GCP 프로젝트 `addie-tutor` |
| 모델 | Gemini 2.5 Flash (분류/튜터), Gemini 3.5 Flash (설계) |
| 로컬 저장소 | SharedPreferences |

---

## 프로젝트 구조

```
lib/
├── main.dart                      # 앱 진입점
├── firebase_options.dart          # Firebase 설정 (addie-tutor)
│
├── config/
│   ├── ai_models.dart             # ⭐ 모델명·location 중앙 설정 (AiModels)
│   └── experiment_config.dart     # 실험 조건 토글 (로드맵 가시성 등)
│
├── models/
│   ├── message.dart               # 채팅 메시지 모델
│   ├── chat_session.dart          # 채팅 세션 모델
│   ├── learner_profile.dart       # 학습자 프로파일 (subject·goal·level 필수, tone 선택)
│   ├── instructional_design.dart  # 교수설계 모델 (Step, Syllabus)
│   └── learning_state.dart        # 통합 학습 상태
│
├── providers/
│   ├── chat_provider.dart         # 단일 세션 채팅 + 오케스트레이션 로직
│   └── learning_state_provider.dart # 학습 상태 관리 + 영속화
│
├── services/
│   ├── gemini_service.dart        # 스트리밍 응답 (Tutor용)
│   ├── intent_classifier_service.dart  # 의도 분류
│   ├── conversational_agent_service.dart # Analyst/Tutor/Feedback
│   ├── syllabus_designer_service.dart   # 커리큘럼 생성
│   ├── step_progress_service.dart  # 단계 진행(이해도) 평가
│   ├── wikidata_client.dart       # 주제 개념 검색
│   ├── rag_service.dart           # 교수설계 RAG 검색
│   └── session_export_service.dart # 세션 JSON 내보내기
│
├── screens/
│   └── chat_screen.dart           # 단일 세션 메인 화면
│
└── widgets/
    ├── chat_view.dart             # 채팅 뷰
    ├── chat_input.dart            # 입력 위젯
    └── message_bubble.dart        # 메시지 버블
```

---

## 빠른 재실행

아래 순서대로 실행하면 됩니다.

### 1. Flutter 웹 앱 실행

```bash
cd /Users/dusanbaek/research-addie-chatbot
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
flutter run -d chrome
```

### 2. Firebase 설정 파일이 없을 때

현재 앱은 `lib/firebase_options.dart`가 있어야 실행됩니다.
이 파일이 없다면 아래를 먼저 1회 실행해야 합니다.

```bash
cd /Users/dusanbaek/research-addie-chatbot
flutterfire configure --project=addie-tutor --platforms=web
```

### 3. RAG 백엔드 실행

```bash
cd /Users/dusanbaek/research-addie-chatbot
python3 -m venv .venv
source .venv/bin/activate
pip install -r scripts/rag/server_requirements.txt
python3 scripts/rag/rag_server.py
```

백엔드는 `http://0.0.0.0:5001`에서 뜹니다.

RAG 서버는 Vertex AI 임베딩(`text-embedding-004`)을 호출하며, 기본 프로젝트는 `addie-tutor`입니다
(`scripts/rag/rag_server.py`의 `VERTEX_PROJECT`). 다른 프로젝트를 쓰려면 환경변수로 덮어쓸 수 있습니다.

```bash
VERTEX_PROJECT=다른-프로젝트-id python3 scripts/rag/rag_server.py
```

### 4. Vertex AI 인증이 안 되어 있을 때

RAG 서버나 PDF 인제스트가 Vertex AI 임베딩을 호출하므로,
로컬 머신에서 아직 인증하지 않았다면 1회 실행합니다.

```bash
gcloud auth application-default login
```

### 5. PDF RAG 인덱스를 다시 만들 때만

```bash
cd /Users/dusanbaek/research-addie-chatbot
source .venv/bin/activate
pip install -r scripts/rag/requirements.txt
python3 scripts/rag/ingest_pdf.py \
  --input "instructionalDesignSource.pdf" \
  --sqlite "data/rag/resource_cache.sqlite" \
  --faiss "data/rag/resource_index.faiss"
```

### 6. 백엔드 주소 확인

앱은 현재 아래 파일에서 RAG/Wikidata 프록시 주소를 직접 사용합니다.

- `lib/services/rag_service.dart`
- `lib/services/wikidata_client.dart`

기본값은 `http://localhost:5001`입니다.
웹 앱과 백엔드를 같은 PC에서 실행하면 그대로 쓰면 되고,
다른 장비에서 웹 앱을 열어야 하면 현재 PC의 IP로 바꿔야 합니다.

## Firebase 설정

1. Firebase 프로젝트 생성
2. Vertex AI in Firebase API 활성화
3. Web App 등록

```bash
# Firebase CLI 설치
npm install -g firebase-tools
firebase login

# FlutterFire CLI 설치
dart pub global activate flutterfire_cli
export PATH="$PATH":"$HOME/.pub-cache/bin"

# 설정 생성
flutterfire configure --project=addie-tutor --platforms=web
```

### 보안 주의사항

- `lib/firebase_options.dart`에는 API 키가 포함됩니다
- 이 파일은 `.gitignore`에 포함되어야 합니다
- 이 저장소에는 `lib/firebase_options.dart`가 기본 포함되어 있지 않을 수 있으므로 `flutterfire configure`로 다시 생성해야 합니다

---

## 상태 흐름 (State Flow)

```
사용자 발화
    ↓
[ChatController.sendMessage()]
    ↓
상태 체크 (LearningState)
    ↓
┌─────────────────────────────────────────────────────────────┐
│ 분기 조건 (앱 로직이 결정)                                   │
├─────────────────────────────────────────────────────────────┤
│ 1. 설계 중 (isDesigning=true)     → 대기                    │
│ 2. 수업 완료 (isCourseCompleted)  → Analyst (새 학습 시작)  │
│ 3. 프로파일 미완성                → Analyst (정보 수집)      │
│ 4. 교수설계 미완성                → Syllabus 생성 트리거    │
│ 5. 수업 가능 상태                 → Intent 분류             │
│    ├─ in_class  → Tutor 모드 (스트리밍)                     │
│    └─ out_class → Feedback 모드                             │
└─────────────────────────────────────────────────────────────┘
    ↓
[각 서비스 호출 → JSON 응답 → State 업데이트]
    ↓
사용자에게 응답 출력
```

---

## 핵심 설계 원칙

### 1. LLM as a Function
LLM을 순수 함수처럼 취급합니다. 입력(프롬프트)을 받아 출력(JSON)을 반환하고, 상태 변경은 앱 코드에서 수행합니다.

### 2. External State Management
상태를 LLM 컨텍스트가 아닌 Riverpod에서 관리합니다. 각 LLM 호출에 필요한 정보만 프롬프트에 주입합니다.

### 3. Structured Output
모든 서비스는 JSON Schema를 사용하여 구조화된 출력을 반환합니다. 이를 통해 안정적인 파싱과 상태 업데이트가 가능합니다.

### 4. Application-Driven Orchestration
어떤 서비스를 호출할지는 앱 코드가 상태를 보고 결정합니다. LLM에게 판단을 위임하지 않습니다.

---

## 학술적 배경

### 관련 개념

- **Compound AI Systems**: 여러 AI 컴포넌트를 조합한 시스템 (Berkeley)
- **Multi-Agent Architecture**: 역할별로 분리된 에이전트 구조
- **Prompt Factoring**: 거대 프롬프트를 작은 단위로 분리

### 논문 프레이밍

> "본 연구의 시스템은 고정된 선형적 ADDIE 모델이 아니라, **State Hub를 중심으로 각 단계가 유기적으로 연결된 실시간 적응형 교수설계 엔진**을 지향한다."

---

## 라이선스

MIT License
