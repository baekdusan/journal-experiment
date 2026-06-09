import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../config/ai_models.dart';
import '../models/learning_state.dart';
import '../models/learner_profile.dart';
import '../models/resource_cache.dart';

class AnalystResult {
  final String response;
  final String? subject;
  final String? goal;
  final LearnerLevel? level;
  final TonePreference? tonePreference;

  AnalystResult({
    required this.response,
    this.subject,
    this.goal,
    this.level,
    this.tonePreference,
  });
}

class FeedbackResult {
  final String response;
  final LearnerLevel? level;
  final TonePreference? tonePreference;
  final bool needsRedesign;
  final bool explicitChange;
  final String? redesignRequest;

  FeedbackResult({
    required this.response,
    required this.needsRedesign,
    required this.explicitChange,
    this.redesignRequest,
    this.level,
    this.tonePreference,
  });
}

class ConversationalAgentService {
  
  // 학습 내 발화 시 수업 진행을 위한 대화용 프롬프트; 스트리밍 서비스에 쓰임; 학습자를 위한 앞단 프롬프트
  String buildTutorStreamingPrompt(
    LearningState state,
    String userText,
    List<String> history,
  ) {
    final profile = state.learnerProfile;
    final design = state.instructionalDesign;
    final cache = state.resourceCache;
    final level = profile.level?.name ?? '미정';
    final toneDisplay = profile.tonePreference?.name ?? '미정';
    final toneForResponse = profile.tonePreference?.name ?? 'kind';
    final historyBlock = history.isEmpty ? '없음' : history.join('\n');

    // 진행 마킹: ✓ 완료 / ▶ 현재 / ○ 예정
    final curIdx = state.currentStepIndex;
    final syllabusBlock = design.syllabus.asMap().entries.map((e) {
      final idx = e.key;
      final step = e.value;
      final mark = idx < curIdx ? '✓' : (idx == curIdx ? '▶' : '○');
      return '$mark ${idx + 1}. ${step.topic} - ${step.objective}';
    }).join('\n');

    final currentStepLine =
        '${state.progressLabel} — ${state.currentStep?.topic ?? '-'}';

    final resourcesBlock = _buildTutorResourcesBlock(cache);

    return '''너는 학습자를 돕는 친절하고 전문적인 튜터다.
    학습 로드맵을 참고하여 학습자의 흐름에 맞게 자연스럽게 수업을 진행하라.

    [현재 학습 상태]
    - 주제(subject): ${profile.subject}
    - 목표(goal): ${profile.goal}
    - 수준(level): $level
    - 선호 말투(tone_preference): $toneDisplay
    - 현재 단계: $currentStepLine

    [학습 로드맵]
    $syllabusBlock

    [최근 대화 요약]
    $historyBlock

    $resourcesBlock

    [튜터링 원칙]
    1) 정답을 먼저 말하지 마라. (비계 설정/Scaffolding)
    2) 사용자가 어렵다고 하면 더 쉬운 설명과 더 작은 예시로 내려가라.
    3) 이해 확인 질문은 필요할 때만 0~1개로 제한하라.
    4) ▶ 표시된 현재 단계의 학습목표 달성에 집중하라. ✓ 표시된 단계는 사용자가 복습을 요청하지 않는 한 다시 설명하지 마라.
    5) 말투는 $toneForResponse에 맞춰라.
    6) tone_preference가 미정이면 기본적으로 kind 말투로 응답하라.
    7) 설명은 지나치게 짧지 않게 3~6문장 정도로 충분히 풀어라.
    8) 사용자가 "그냥 알려줘"라고 하면 질문 없이 설명만 하라.
    9) 로드맵의 모든 내용을 충분히 다뤘다고 판단되면, 학습 완료 여부를 자연스럽게 물어보라.
    10) 학습 자료의 내용에 근거하여 설명하고, 자료에 없는 사실을 지어내지 마라.
    11) 교수설계 이론을 적용하여 효과적으로 학습을 안내하라.

    [입력]
    $userText

    [출력 규칙]
    - 반드시 한국어 자연어로만 답하라.
    - JSON을 출력하지 마라.
    ''';
  }

  /// Tutor 프롬프트에 포함할 학습 자료 블록 생성.
  /// 실험: 고정 학습 자료(CBBF)를 요약/절삭 없이 전문 통짜로 제공한다.
  String _buildTutorResourcesBlock(ResourceCache cache) {
    if (!cache.isResourceReady) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n[학습 자료]');
    buffer.writeln('아래 자료에 근거하여 학습을 진행하라. (영문 자료이나 설명은 한국어로 하라)');

    for (final resource in cache.learningResources) {
      buffer.writeln('## ${resource.title}');
      buffer.writeln(resource.summary);
      if (resource.url.isNotEmpty) {
        buffer.writeln('(출처: ${resource.url})');
      }
    }

    return buffer.toString();
  }

  /// Analyst 모드: 사용자의 학습 정보를 수집하는 Micro-Agent
  
  // 학습 외 발화 시 현재 상태를 통해 피드백을 반영하여 상태 업데이트
  // _buildAnalystPrompt 이용하여 추가 정보를 채우기 위한 대화 진행
  Future<AnalystResult> runAnalyst(
    LearningState state,
    String userText,
  ) async {
    // ============================================================
    // 1. JSON Schema 정의: LLM이 반환할 구조를 미리 규정
    // ============================================================
    // Gemini의 Controlled Generation 기능을 사용하여
    // 자유로운 자연어 대신 정확한 JSON 구조를 받습니다.
    final schema = Schema.object(
      properties: {
        // 1-1. extracted_info: 사용자 발화에서 추출한 학습자 정보
        'extracted_info': Schema.object(
          properties: {
            'subject': Schema.string(description: '학습 주제'),
            'goal': Schema.string(description: '학습 목표'),
            'level': Schema.enumString(
              enumValues: ['beginner', 'intermediate', 'expert'],
              description: '학습자 수준',
            ),
            'tone_preference': Schema.enumString(
              enumValues: ['kind', 'formal', 'casual'],
              description: '선호 말투',
            ),
          },
          // 모든 필드가 optional이므로 추출되지 않은 것은 null로 반환됨
          optionalProperties: [
            'subject',
            'goal',
            'level',
            'tone_preference',
          ],
        ),

        // 1-2. explicit_fields: 각 필드가 "명시적으로 언급되었는지" 여부
        // 이를 통해 LLM의 추측을 막고, 실제로 언급된 정보만 업데이트합니다.
        'explicit_fields': Schema.object(
          properties: {
            'subject': Schema.boolean(description: 'subject가 명시적으로 언급됨'),
            'goal': Schema.boolean(description: 'goal이 명시적으로 언급됨'),
            'level': Schema.boolean(description: 'level이 명시적으로 언급됨'),
            'tone_preference':
                Schema.boolean(description: 'tone_preference가 명시적으로 언급됨'),
          },
          optionalProperties: [
            'subject',
            'goal',
            'level',
            'tone_preference',
          ],
        ),

        // 1-3. response: 사용자에게 보여줄 자연스러운 한국어 응답
        'response': Schema.string(description: '사용자에게 보여줄 응답'),
      },
    );

    // ============================================================
    // 2. Firebase AI (Gemini) 모델 설정
    // ============================================================
    final model =
        FirebaseAI.vertexAI(location: AiModels.extractor.location).generativeModel(
      model: AiModels.extractor.model, // 빠르고 정확한 분류/추출용 모델
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // JSON 응답 강제
        responseSchema: schema, // 위에서 정의한 스키마 적용
        temperature: 0.0, // 창의성 최소화 (정확한 추출이 목표)
      ),
    );

    // ============================================================
    // 3. 프롬프트 생성 및 API 호출
    // ============================================================
    final prompt = _buildAnalystPrompt(state, userText);
    final response = await model.generateContent([Content.text(prompt)]);
    final raw = response.text;

    // 3-1. 응답 검증: 비어있으면 재시도 유도
    if (raw == null || raw.isEmpty) {
      return AnalystResult(response: '조금 더 자세히 말씀해 주실 수 있을까요?');
    }

    // ============================================================
    // 4. JSON 파싱: LLM 응답을 구조화된 데이터로 변환
    // ============================================================
    final data = jsonDecode(raw) as Map<String, dynamic>;

    // 4-1. extracted_info 파싱 (기본값: 빈 맵)
    final extracted =
        (data['extracted_info'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

    // 4-2. explicit_fields 파싱 (기본값: 빈 맵)
    final explicit =
        (data['explicit_fields'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};

    // ============================================================
    // 5. explicit_fields 기반 검증
    // ============================================================
    // LLM이 "이 정보는 명시적으로 언급되었다"고 표시한 것만 추출합니다.
    // 이를 통해 LLM의 "추측"을 차단하고, 실제 사용자 발화에서 나온 정보만 사용합니다.
    final subjectExplicit = explicit['subject'] as bool? ?? false;
    final goalExplicit = explicit['goal'] as bool? ?? false;
    final levelExplicit = explicit['level'] as bool? ?? false;
    final toneExplicit = explicit['tone_preference'] as bool? ?? false;

    // ============================================================
    // 6. 최종 데이터 구성: explicit_fields가 true인 것만 추출
    // ============================================================
    // 6-1. subject: 명시적으로 언급되었을 때만 정규화 후 반환
    final subject = subjectExplicit
        ? _normalizeText(extracted['subject'] as String?)
        : null;

    // 6-2. goal: 명시적으로 언급되었을 때만 정규화 후 반환
    final goal =
        goalExplicit ? _normalizeText(extracted['goal'] as String?) : null;

    // ============================================================
    // 7. AnalystResult 반환
    // ============================================================
    return AnalystResult(
      // 사용자에게 보여줄 자연스러운 응답 (fallback 포함)
      response: data['response'] as String? ?? '조금 더 자세히 말씀해 주실 수 있을까요? ',

      // 명시적으로 언급된 경우에만 값 반환
      subject: subject,
      goal: goal,

      // level: explicit이고 값이 존재할 때만 enum으로 변환
      level: levelExplicit && extracted['level'] != null
          ? LearnerLevel.values.byName(extracted['level'] as String)
          : null,

      // tonePreference: explicit이고 값이 존재할 때만 enum으로 변환
      tonePreference: toneExplicit && extracted['tone_preference'] != null
          ? TonePreference.values.byName(
              extracted['tone_preference'] as String,
            )
          : null,
    );
  }

  // 학습 외 발화 시 현재 상태를 통해 피드백을 반영하여 상태 업데이트
  // _buildFeedbackPrompt 이용하여
  // 1. 단순한 피드백: State 변경
  // 2. 재설계 요구시: needs_redesign=true만 설정 후 syllabus_designer에게 위임
  Future<FeedbackResult> runFeedback(
    LearningState state,
    String userText,
    List<String> history,
  ) async {
    final schema = Schema.object(
      properties: {
        'profile_update': Schema.object(
          properties: {
            'level': Schema.enumString(
              enumValues: ['beginner', 'intermediate', 'expert'],
              description: '수준 변경 요청',
            ),
            'tone_preference': Schema.enumString(
              enumValues: ['kind', 'formal', 'casual'],
              description: '말투 변경 요청',
            ),
          },
          optionalProperties: [
            'level',
            'tone_preference'
          ],
        ),
        'response': Schema.string(description: '피드백 수용 응답'),
        'needs_redesign': Schema.boolean(description: '재설계 필요 여부'),
        'explicit_change':
            Schema.boolean(description: '변경 요청이 명시적으로 존재'),
        'redesign_request':
            Schema.string(description: '재설계에 반영할 구체적 요청'),
      },
      optionalProperties: ['redesign_request'],
    );

    final model =
        FirebaseAI.vertexAI(location: AiModels.extractor.location).generativeModel(
      model: AiModels.extractor.model,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: 0.3,
      ),
    );

    final prompt = _buildFeedbackPrompt(state, userText, history);
    final response = await model.generateContent([Content.text(prompt)]);
    final raw = response.text;
    if (raw == null || raw.isEmpty) {
      return FeedbackResult(
        response: '알겠어요. 필요한 부분을 조정해볼게요.',
        needsRedesign: false,
        explicitChange: false,
      );
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final update =
        (data['profile_update'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    return FeedbackResult(
      response: data['response'] as String? ??
          '알겠어요. 필요한 부분을 조정해볼게요.',
      needsRedesign: data['needs_redesign'] as bool? ?? false,
      explicitChange: data['explicit_change'] as bool? ?? false,
      redesignRequest: _normalizeText(data['redesign_request'] as String?),
      level: update['level'] != null
          ? LearnerLevel.values.byName(update['level'] as String)
          : null,
      tonePreference: update['tone_preference'] != null
          ? TonePreference.values.byName(update['tone_preference'] as String)
          : null,
    );
  }

  // 추출된 정보를 바탕으로 빈 정보에 대해 추가 요청을 하기 대화용 프롬프트; 스트리밍 X; 학습자를 위한 앞단 프롬프트
  String _buildAnalystPrompt(LearningState state, String userText) {
    final profile = state.learnerProfile;
    final level = profile.level?.name ?? '미정';
    final tone = profile.tonePreference?.name ?? '미정';
    return '''너는 학습자의 정보를 수집하는 튜터다.
    자연스러운 대화를 통해 학습자의 학습 주제(subject), 목표(goal), 수준(level)을 파악하라.

    [수집할 정보 - 이 세 가지만 적극적으로 파악한다]
    - subject: 무엇을 배우고 싶은가?
    - goal: 이 학습으로 무엇을 하고 싶은가?
    - level: beginner/intermediate/expert 중 하나

    [말투(tone_preference)에 대한 규칙]
    - 말투는 먼저 묻지 마라. 기본적으로 친근한 말투로 진행된다.
    - 사용자가 "편하게 말해줘", "존댓말로 해줘"처럼 말투를 직접 요청한 경우에만
      tone_preference를 채우고 explicit_fields.tone_preference=true로 둔다.
    - 그 외에는 항상 tone_preference=null, explicit_fields.tone_preference=false로 둔다.

    [대화 원칙]
    1) 이미 파악된 정보는 다시 묻지 마라.
    2) 사용자가 이미 답한 정보는 extracted_info에 반드시 반영하라.
    3) 필수 정보(subject, goal, level)가 모두 파악되어도
      "이제 로드맵을 만들겠다"는 식의 확정 문구는 직접 말하지 마라.
      최종 생성 시작 안내는 시스템이 별도로 처리한다.
      추가 질문은 하지 마라.
    4) 현재 정보(subject, goal, level)가 '미정'이면 그 정보를 얻기 위한 질문을 우선하라.
    5) 사용자가 명시적으로 언급하지 않은 값은 절대 추측하지 말고 null로 두어라.
    6) explicit_fields에 true로 표시된 항목만 extracted_info에 값을 채우고, 나머지는 null로 두어라.
    7) response에는 사용자가 이번 발화에서 명시적으로 언급한 정보만 언급하라.
    8) 사용자가 말하지 않은 정보를 마치 알고 있는 것처럼 응답하지 마라.

    [explicit_fields 판단 기준 - 매우 중요]
    explicit_fields는 "사용자가 그 정보를 말로 직접 진술했는가"만 본다.
    발화의 어조/말투/문체나 일반 상식으로 추론한 것은 명시가 아니므로 반드시 false다.
    - level: 사용자가 자신의 수준을 직접 말한 경우에만 true.
      (예: "완전 초보야", "기초는 알아", "전문가 수준이야")
      주제가 어렵거나 흔하다는 이유로 수준을 추정하지 마라.
    - tone_preference: 사용자가 말투를 직접 요청한 경우에만 true.
      (예: "편하게 말해줘", "존댓말로 해줘")
      사용자가 반말/존댓말로 입력했다는 사실만으로 tone_preference를 명시했다고 보지 마라.

    [현재까지 파악된 정보]
    - subject: ${profile.subject}
    - goal: ${profile.goal}
    - level: $level
    - tone_preference: $tone

    [입력]
    $userText

    [판단 예시 - 주제는 어떤 것이든 동일하게 적용]
    상황: 사용자가 학습 주제만 말하고, 목표·수준·말투는 언급하지 않은 경우
    → extracted_info: subject=<사용자가 말한 주제>, goal=null, level=null, tone_preference=null
    → explicit_fields: subject=true, goal=false, level=false, tone_preference=false
    → response: 그 주제를 배우고 싶다는 점에 공감하고, 다음으로 필요한 정보(예: 목표)를 자연스럽게 되묻는다.
       (수준이나 말투는 언급하거나 단정하지 않는다)

    [출력 규칙]
    - 반드시 JSON만 출력하라.
    - extracted_info의 각 필드는 새로 파악되었으면 값을 넣고, 파악되지 않았으면 null로 두어라.
    - explicit_fields는 각 항목이 명시적으로 언급되었는지 true/false로 표시하라.
    - response는 사용자에게 보여줄 자연스러운 한국어 한 문단이다.''';
  }

  // 학습 외 발화 시 피드백을 처리하기 위한 상태 변경용 프롬프트
  String _buildFeedbackPrompt(LearningState state, String userText, List<String> history) {
    final profile = state.learnerProfile;
    final design = state.instructionalDesign;
    final level = profile.level?.name ?? '미정';
    final tone = profile.tonePreference?.name ?? '미정';
    final historyBlock = history.isEmpty ? '없음' : history.join('\n');

    final syllabusBlock = design.syllabus.asMap().entries.map((e) {
      final idx = e.key + 1;
      final step = e.value;
      return '$idx. ${step.topic}';
    }).join('\n');

    return '''너는 학습자의 피드백을 수용하는 유연한 튜터다.
      학습자의 요청을 반영하여 프로필을 업데이트하고, 필요하면 학습 로드맵 재설계를 요청하라.

      [현재 학습 상태]
      - 주제(subject): ${profile.subject}
      - 목표(goal): ${profile.goal}
      - 수준(level): $level
      - 선호 말투(tone_preference): $tone

      [학습 로드맵]
      $syllabusBlock

      [최근 대화 요약]
      $historyBlock

      [피드백 처리 원칙]
      1) 피드백을 긍정적으로 수용하라.
      2) 난이도/말투 변경 요청은 profile_update에 반영하라.
      3) 학습 경로 자체의 변경(목표 변경, 주제 변경, 순서 변경)이 필요하면 needs_redesign=true로 설정하라.
      4) 단순 난이도/스타일 조정은 needs_redesign 없이 처리하라.
      5) response는 피드백 수용 + 수업 계속 안내를 포함하라.
      6) 사용자가 명시적으로 목표/주제/순서 변경을 요청한 경우에만 explicit_change=true로 설정하라.
      7) unrelated한 잡담/감정 표현이면 explicit_change=false로 두고 needs_redesign도 false로 두어라.
      8) explicit_change=true인 경우, 사용자의 요청을 요약해 redesign_request에 한국어 한 문장으로 담아라. 그렇지 않으면 null로 두어라.

      [입력]
      $userText

      [출력 규칙]
      - 반드시 JSON만 출력하라.
      - profile_update의 각 필드는 변경이 필요하면 값을 넣고, 없으면 null로 두어라.''';
  }

  String? _normalizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }
}
