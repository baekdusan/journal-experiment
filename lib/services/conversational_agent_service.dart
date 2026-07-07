import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../config/agent_prompts.dart';
import '../config/ai_models.dart';
import '../models/learning_state.dart';
import '../models/learner_profile.dart';

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
  
  // 학습 내 발화 시 수업 진행용 시스템 프롬프트 (처치군 전용).
  // GeminiService.streamResponse의 systemInstruction으로 주입되며,
  // 상태(로드맵 진행 마킹 ✓▶○)가 바뀌므로 매 턴 새로 빌드한다.
  // 대화 이력은 chat history로, 사용자 발화는 user 메시지로 별도 전달된다.
  // 프롬프트 원문: lib/config/agent_prompts.dart → AgentPrompts.tutorSystem
  String buildTutorSystemInstruction(LearningState state) {
    return AgentPrompts.tutorSystem(state);
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
    // 프롬프트 원문: lib/config/agent_prompts.dart → AgentPrompts.analyst
    final prompt = AgentPrompts.analyst(state, userText);
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

    // 프롬프트 원문: lib/config/agent_prompts.dart → AgentPrompts.feedback
    final prompt = AgentPrompts.feedback(state, userText, history);
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

  String? _normalizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }
}
