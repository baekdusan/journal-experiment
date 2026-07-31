# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ADDIE 모델 기반 적응형 학습 튜터 시스템. Flutter Web + Firebase AI (Vertex AI) + Riverpod 상태 관리를 사용합니다.

**피험자 간 2조건 실험 시스템**: URL 쿼리 `?condition=treatment|control`로 분기 (`experiment_config.dart`).
- 처치군(treatment): 아래의 구조화 오케스트레이션 전체
- 대조군(control): 시스템 프롬프트 없는 순수 모델 (`_runFreeformFlow`, 라우팅 전부 건너뜀)
- 자료 취득은 로컬 캐시 없이 **`Tool.googleSearch()` grounding**만 사용. 검색을 가진 에이전트는 Syllabus Designer 1단계와 학습자 대면 스트리밍(GeminiService) 둘뿐.
- 모든 에이전트 프롬프트는 `lib/config/agent_prompts.dart`에 중앙화.

### Core Architecture: Stateless Micro-Agent Pattern

이 프로젝트는 **"LLM이 판단"하는 Fat Agent 방식이 아닌, "앱이 판단하고 LLM은 생성만"하는 Thin Micro-Services 패턴**을 사용합니다.

```
App Orchestrator (ChatController)
    ↓ 상태 기반 라우팅
┌───────────┬──────────────┬─────────────┬────────────┐
│ Intent    │ Conversational│ Syllabus   │ Step      │
│ Classifier│ AgentService │ Designer   │ Progress  │
│ (분류만)  │ (Analyst/    │ (검색 조사→ │ (단계 판정)│
│           │  Feedback)   │  JSON 구조화)│           │
└───────────┴──────────────┴─────────────┴────────────┘
```

---

## Common Commands

```bash
# Run the app
flutter run -d chrome

# Build for web
flutter build web

# Run tests
flutter test

# Analyze code
flutter analyze

# Install dependencies
flutter pub get

# Code generation (required after adding @riverpod annotations)
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for code generation
flutter pub run build_runner watch
```

---

## Directory Structure

```
lib/
├── models/                          # 데이터 모델
│   ├── message.dart                 # 채팅 메시지
│   ├── chat_session.dart            # 채팅 세션
│   ├── learner_profile.dart         # 학습자 프로파일 (subject, goal, level, tone)
│   ├── instructional_design.dart    # 교수설계 (Step, Syllabus)
│   └── learning_state.dart          # 통합 학습 상태
│
├── providers/
│   ├── chat_provider.dart           # ⭐ 핵심 오케스트레이션 로직
│   ├── chat_provider.g.dart         # (generated - do not edit)
│   ├── learning_state_provider.dart # 학습 상태 관리 + 영속화
│   └── learning_state_provider.g.dart # (generated)
│
├── config/
│   ├── ai_models.dart               # ⭐ 모델·location 중앙 설정 (ModelSpec)
│   ├── agent_prompts.dart           # ⭐ 전체 에이전트 프롬프트 중앙화
│   └── experiment_config.dart       # 실험 조건 URL 분기 + 로드맵 가시성
│
├── services/                        # ⭐ Micro-Agent Services
│   ├── gemini_service.dart          # 학습자 대면 스트리밍 (grounding + systemInstruction, 양 조건 공용)
│   ├── intent_classifier_service.dart  # 의도 분류 (in/out class)
│   ├── conversational_agent_service.dart # Analyst/Feedback + Tutor systemInstruction
│   ├── syllabus_designer_service.dart   # 커리큘럼 생성 (2단계: 검색 조사 → JSON 구조화)
│   ├── step_progress_service.dart   # 단계 진행 판정
│   └── session_export_service.dart  # 세션 JSON 내보내기
│
├── screens/
│   └── chat_screen.dart             # 단일 세션 메인 화면
│
└── widgets/                         # Gemini 스타일 UI
    ├── chat_view.dart               # 채팅 뷰 (빈 화면 글로우 + 중앙 입력)
    ├── chat_input.dart              # 필 입력 위젯
    ├── message_bubble.dart          # 메시지 버블
    └── typing_indicator.dart        # 타이핑 인디케이터
```

---

## Core Data Flow

### 1. 메시지 처리 흐름 (ChatController.sendMessage)

```dart
// 0. 실험 조건 분기
if (ExperimentConfig.isControl) → _runFreeformFlow()  // 순수 모델 + 검색

// 1. 상태 체크 (treatment)
if (isDesigning) return;  // 설계 중이면 대기
if (isCourseCompleted) → _runAnalystFlow()  // 완료 후 새 학습

// 2. 프로파일/설계 미완성 시
if (!isLearnerProfileFilled || !isDesignFilled) → _runAnalystFlow()

// 3. 수업 가능 상태
intent = await intentClassifier.classify(text)
if (intent == inClass) → _runTutorFlow()   // 스트리밍 → StepProgress 판정
else → _runFeedbackFlow()                   // 피드백 처리
```

### 2. 서비스별 역할

| Service | 역할 | 모델 | 검색 | 출력 형식 |
|---------|------|------|------|----------|
| `IntentClassifierService` | 수업 내/외 분류 | `AiModels.extractor` | X | `{intent}` |
| `ConversationalAgentService.runAnalyst` | 정보 수집 | `AiModels.extractor` | X | `{extracted_info, explicit_fields, response}` |
| `ConversationalAgentService.runFeedback` | 피드백 처리 | `AiModels.extractor` | X | `{profile_update, response, needs_redesign, ...}` |
| `ConversationalAgentService.buildTutorSystemInstruction` | 튜터 시스템 프롬프트 생성 (매 턴 재빌드) | - | - | String |
| `SyllabusDesignerService` | 커리큘럼 생성 (1단계 검색 조사 → 2단계 JSON 구조화) | `AiModels.designer` → `extractor` | 1단계만 O | `{syllabus, searchQueries, sources}` |
| `StepProgressService` | 단계 진행 판정 | `AiModels.extractor` | X | `{step_completed, confidence}` |
| `GeminiService` | 학습자 대면 스트리밍 (양 조건 공용, 대조군은 systemInstruction 없음) | `AiModels.tutor` | O | Stream<String> + onGrounding 콜백 |

> `googleSearch` 도구와 `responseSchema`(JSON 강제)는 한 호출에서 병용 불가 →
> 검색이 필요한 JSON 에이전트는 SyllabusDesigner처럼 2단계로 분리한다.

---

## Key Patterns

### Riverpod Providers

```dart
// Singleton services
@Riverpod(keepAlive: true)
GeminiService geminiService(ref) => GeminiService();

// State notifiers
@riverpod
class LearningStateNotifier extends _$LearningStateNotifier { ... }

// Computed state
@riverpod
ChatSession? activeSession(ref) { ... }
```

### Model Conventions

- Immutable with `copyWith()` methods
- `toJson()`/`fromJson()` factories for serialization
- `isLearnerProfileFilled`, `isDesignFilled`, `isLastStep` 등 computed getters

### State Management

- `LearningState`: 통합 학습 상태 (profile + design + flags)
- `SharedPreferences`: 로컬 영속화
- 상태 변경 시 항상 `_saveToPrefs()` 호출

---

## Important Implementation Details

### 1. Tutor 스트리밍

Tutor 모드는 `GeminiService.streamResponse()`를 사용하여 실시간 스트리밍합니다.
프롬프트를 한 덩어리로 넘기지 않고 **세 경로로 나눠** 전달합니다:

```dart
// chat_provider.dart - _runTutorFlow()
// 상태·수업 계획·튜터링 원칙 → systemInstruction (매 턴 재빌드)
final systemInstruction = agent.buildTutorSystemInstruction(learning);

final stream = gemini.streamResponse(
  _recentMessages(sessionId,                  // 대화 이력 → chat history
      excludeMessageId: assistantId, currentUserText: userText),
  userText,                                   // 이번 발화 → user 메시지
  systemInstruction: systemInstruction,
  onGrounding: (queries, sources) =>
      _logGrounding(sessionId, 'tutor', queries, sources),
);
await for (final chunk in stream) {
  // streamingMessageProvider에 누적 (세션은 완료 시 1회만 갱신)
}
```

`systemInstruction`은 서버에 고정되는 값이 아니라 요청마다 함께 전송되므로,
매 턴 현재 단계 마킹(✓▶○)을 갱신해 새로 빌드합니다.

### 2. Syllabus 생성 (백그라운드)

설계는 비동기로 실행되며, 완료 시 자동으로 수업을 시작합니다:

```dart
// chat_provider.dart - _startSyllabusDesign()
// await하지 않는다 — 플래그 저장(prefs)을 기다리느라 UI를 막지 않기 위해서다.
unawaited(ref.read(learningStateProvider.notifier).setDesigning(true));

Future(() async {
  final result = await designer.generate(...);       // 1단계 검색 → 2단계 JSON
  await ref.read(learningStateProvider.notifier).setSyllabus(result.syllabus);
  await _runTutorFlow(sessionId, '수업을 시작해줘');   // 합성 큐로 첫 수업 턴
});
```

`setSyllabus`는 syllabus만 쓰는 게 아니라 `isDesigning=false`,
`showDesignReady=true`, `isCourseCompleted=false`, `currentStepIndex=0`을 함께 세팅합니다
([learning_state_provider.dart:79](lib/providers/learning_state_provider.dart#L79)).

### 3. 상태 전이 조건

```
isLearnerProfileFilled = _isFilled(subject) && _isFilled(goal) && level != null
isDesignFilled         = syllabus.isNotEmpty
isReady                = isLearnerProfileFilled && isDesignFilled
```

- **`level`도 필수다.** subject·goal만으로는 설계가 시작되지 않는다
  ([learner_profile.dart:34](lib/models/learner_profile.dart#L34)).
  반면 `tonePreference`는 필수가 아니다 — 미정이면 튜터가 기본 말투(kind)로 진행한다.
- `_isFilled()`는 `!= null`보다 엄격하다. null·공백뿐 아니라 **문자열 `"null"`도 거부**한다
  (LLM이 미정을 `"null"` 문자열로 뱉는 경우를 막는다).
- `isReady`는 getter가 아니라 [chat_provider.dart:344](lib/providers/chat_provider.dart#L344)의
  **지역 변수**다. 위 둘과 성격이 다르다.

> 이 이름들은 흐름도(`flowchart.md`)의 회색 판단 박스 라벨과 일치시킨다.
> 앱이 `LearningState`를 읽어 분기하는 지점이 곧 이 조건들이다.

---

## Firebase AI Configuration

**GCP/Firebase 프로젝트**: `addie-tutor` (개인 결제 계정, `lib/firebase_options.dart`).

모델명과 location(엔드포인트)은 `lib/config/ai_models.dart`에 `ModelSpec(모델, location)` 쌍으로 **중앙화**되어 있다. 모델·리전을 갈아끼울 때는 이 파일만 수정한다.

```dart
// lib/config/ai_models.dart
class AiModels {
  static const ModelSpec extractor = ModelSpec('gemini-2.5-flash', 'us-central1'); // 분류/추출
  static const ModelSpec tutor     = ModelSpec('gemini-3.5-flash', 'global');      // 학습자 대면 (양 조건 공용!)
  static const ModelSpec designer  = ModelSpec('gemini-3.5-flash', 'global');      // 교수설계 1단계
}
```

각 서비스는 이 상수를 참조한다:

```dart
final model = FirebaseAI.vertexAI(location: AiModels.extractor.location).generativeModel(
  model: AiModels.extractor.model,
  generationConfig: GenerationConfig(
    responseMimeType: 'application/json',
    responseSchema: schema,
    temperature: 0.0,  // 분류용은 0.0, 생성용은 0.3
  ),
);
```

> location 제약 (addie-tutor 프로젝트):
> - `gemini-2.5-flash` → `us-central1` (global은 라우팅 불안정/404)
> - `gemini-3.5-flash` → `global` 전용 (us-central1에서 404)
> - `gemini-2.0-flash`(retired), `gemini-3-flash-preview` → 사용 불가 (404)
>
> `tutor`는 처치군·대조군이 공유하는 통제 변인이므로 이 값 하나로 양 조건이 함께 바뀐다.
> Firebase AI Logic이 Vertex AI를 호출하려면 서비스 에이전트
> `service-<PROJECT_NUMBER>@gcp-sa-firebasevertexai.iam.gserviceaccount.com`에
> `roles/aiplatform.user` 권한이 필요하다 (없으면 앱에서 403).

---

## Common Tasks

### 새 서비스 추가

1. `lib/services/`에 서비스 클래스 생성
2. JSON Schema 정의 + 프롬프트 작성
3. `chat_provider.dart`에 provider 추가
4. `ChatController`에서 적절한 시점에 호출

### 상태 필드 추가

1. `learning_state.dart`에 필드 추가 + `copyWith()` 수정
2. `learning_state_provider.dart`에 업데이트 메서드 추가
3. `toJson()`/`fromJson()` 업데이트

### 프롬프트 수정

**서비스 파일이 아니라 [`lib/config/agent_prompts.dart`](lib/config/agent_prompts.dart)에서 수정합니다.**
모든 프롬프트가 이 파일에 중앙화되어 있고, 각 서비스는 여기서 문자열을 받아 호출만 합니다.

| 진입점 | 사용처 |
|--------|--------|
| `AgentPrompts.intentClassifier()` | `intent_classifier_service.dart` · `classify()` |
| `AgentPrompts.analyst()` | `conversational_agent_service.dart` · `runAnalyst()` |
| `AgentPrompts.feedback()` | `conversational_agent_service.dart` · `runFeedback()` |
| `AgentPrompts.tutorSystem()` | `conversational_agent_service.dart` · `buildTutorSystemInstruction()` |
| `AgentPrompts.courseClosingCue` | `chat_provider.dart` · 수업 완료 직후 마무리 발화 트리거 (합성 user 메시지) |
| `AgentPrompts.syllabusResearch()` / `syllabusStructure()` | `syllabus_designer_service.dart` · `generate()` 1·2단계 |
| `AgentPrompts.stepProgress()` | `step_progress_service.dart` · `evaluate()` |

프롬프트에는 필요한 상태 정보만 주입합니다. 수정 후에는
[AGENTS_AND_PROMPTS.md](AGENTS_AND_PROMPTS.md)의 사본도 함께 갱신하세요.

> 대조군(control)에는 시스템 프롬프트가 없습니다. 여기 있는 프롬프트는 전부 처치군 전용이므로,
> 프롬프트로 출력 형식을 제약하면 대조군만 그 제약을 받지 않아 조건 간 교란이 됩니다.
> 형식 보정은 양 조건이 공유하는 표시 계층([markdown_normalizer.dart](lib/utils/markdown_normalizer.dart))에서 합니다.