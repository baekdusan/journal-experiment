import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/learner_profile.dart';
import '../models/instructional_design.dart';
import '../config/agent_prompts.dart';
import '../config/ai_models.dart';

/// 커리큘럼(Syllabus) 생성 Micro-Agent.
///
/// 확정 실험설계(260624): 자료 취득은 로컬 캐시(RAG/Wikidata/CBBF 박제)가 아닌
/// **Google Search grounding**으로 이뤄진다. 설계자가 검색으로 기존 커리큘럼·
/// 공인 시험 범위·튜토리얼 목차를 조사하고, 그 자료를 참조해 커리큘럼을 설계한다.
///
/// Gemini는 `Tool.googleSearch()`와 `responseSchema`(JSON 강제)를 한 호출에서
/// 병용할 수 없으므로 **2단계 호출**로 나눈다:
/// 1. 검색 조사 + 커리큘럼 초안 생성 (grounding ON, 자연어 출력)
/// 2. 초안 → JSON 구조화 (grounding OFF, responseSchema 강제)
class SyllabusDesignerService {
  /// 커리큘럼과 함께 1단계 조사에서 발동한 grounding 정보
  /// (검색어, 근거 소스)를 반환한다 — 검색 발동 검증·조절변수 로깅용.
  Future<
      ({
        List<Step> syllabus,
        List<String> searchQueries,
        List<String> sources,
      })> generate(
    LearnerProfile profile, {
    String? redesignRequest,
  }) async {
    // ========================================================================
    // 1단계: Google Search grounding으로 자료 조사 + 초안 작성 (자연어)
    // ========================================================================
    final researchModel =
        FirebaseAI.vertexAI(location: AiModels.designer.location).generativeModel(
      model: AiModels.designer.model,
      tools: [Tool.googleSearch()],
      generationConfig: GenerationConfig(temperature: 0.3),
    );

    // 프롬프트 원문: lib/config/agent_prompts.dart → AgentPrompts.syllabusResearch
    final researchPrompt = AgentPrompts.syllabusResearch(
      profile,
      redesignRequest: redesignRequest,
    );
    final researchResponse =
        await researchModel.generateContent([Content.text(researchPrompt)]);
    final draft = researchResponse.text;
    if (draft == null || draft.trim().isEmpty) {
      throw StateError('Empty syllabus research response');
    }

    // grounding 발동 정보 수집 (검색어 + 근거 소스)
    final metadata = researchResponse.candidates.isNotEmpty
        ? researchResponse.candidates.first.groundingMetadata
        : null;
    final searchQueries = metadata?.webSearchQueries ?? const <String>[];
    final sources = <String>[
      if (metadata != null)
        for (final grounding in metadata.groundingChunks)
          if (grounding.web != null)
            '${grounding.web!.title ?? '(제목 없음)'} (${grounding.web!.uri ?? '-'})',
    ];

    // ========================================================================
    // 2단계: 초안 텍스트 → JSON 구조화 (responseSchema 강제)
    // ========================================================================
    final stepSchema = Schema.object(
      properties: {
        'step': Schema.integer(description: '단계 번호'),
        'topic': Schema.string(description: '단계 소주제'),
        'objective': Schema.string(description: '단계 학습 목표'),
      },
    );
    final schema = Schema.object(
      properties: {
        'syllabus': Schema.array(
          items: stepSchema,
          description: '1~5개 단계 배열',
        ),
      },
    );

    final structureModel =
        FirebaseAI.vertexAI(location: AiModels.extractor.location).generativeModel(
      model: AiModels.extractor.model,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: 0.0,
      ),
    );

    // 프롬프트 원문: lib/config/agent_prompts.dart → AgentPrompts.syllabusStructure
    final structureResponse = await structureModel
        .generateContent([Content.text(AgentPrompts.syllabusStructure(draft))]);
    final raw = structureResponse.text;
    if (raw == null || raw.isEmpty) {
      throw StateError('Empty syllabus structure response');
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;
    final syllabusList = data['syllabus'];
    if (syllabusList is! List || syllabusList.isEmpty) {
      throw StateError('Invalid syllabus response');
    }
    final syllabus = syllabusList
        .map((item) => Step.fromJson(item as Map<String, dynamic>))
        .toList();

    return (
      syllabus: syllabus,
      searchQueries: searchQueries,
      sources: sources,
    );
  }
}
