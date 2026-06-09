import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/learner_profile.dart';
import '../models/instructional_design.dart';
import '../models/resource_cache.dart';
import '../config/ai_models.dart';

class SyllabusDesignerService {

  // syllabus와 적용된 교수설계 이론을 함께 생성하는 에이전트
  Future<({List<Step> syllabus, List<InstructionalTheory> theories})> generate(
    LearnerProfile profile, {
    ResourceCache? resourceCache,
    String? redesignRequest,
  }) async {
    final stepSchema = Schema.object(
      properties: {
        'step': Schema.integer(description: '단계 번호'),
        'topic': Schema.string(description: '단계 소주제'),
        'objective': Schema.string(description: '단계 학습 목표'),
      },
    );

    final theorySchema = Schema.object(
      properties: {
        'theoryName': Schema.string(
          description: '교수설계 이론의 정확한 명칭 (예: Scaffolding, Zone of Proximal Development)',
        ),
        'description': Schema.string(
          description: '이론의 핵심 개념을 2-3문장으로 요약',
        ),
        'applicability': Schema.string(
          description: '이 커리큘럼에서 해당 이론을 어떻게 적용했는지 구체적으로 설명',
        ),
      },
    );

    final schema = Schema.object(
      properties: {
        'syllabus': Schema.array(
          items: stepSchema,
          description: '1~5개 단계 배열',
        ),
        'theories': Schema.array(
          items: theorySchema,
          description: '커리큘럼 설계에 적용된 교수설계 이론 (최대 3개)',
        ),
      },
    );

    final model =
        FirebaseAI.vertexAI(location: AiModels.designer.location).generativeModel(
      model: AiModels.designer.model,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: 0.3,
      ),
    );

    final prompt = _buildPrompt(
      profile,
      resourceCache: resourceCache,
      redesignRequest: redesignRequest,
    );
    final response = await model.generateContent([Content.text(prompt)]);
    final raw = response.text;
    if (raw == null || raw.isEmpty) {
      throw StateError('Empty syllabus response');
    }

    final data = jsonDecode(raw) as Map<String, dynamic>;

    // syllabus 파싱
    final syllabusList = data['syllabus'];
    if (syllabusList is! List || syllabusList.isEmpty) {
      throw StateError('Invalid syllabus response');
    }
    final syllabus = syllabusList
        .map((item) => Step.fromJson(item as Map<String, dynamic>))
        .toList();

    // theories 파싱
    final theoriesList = data['theories'] as List?;
    final inputTheories = resourceCache?.instructionalTheories ?? [];

    // 모든 input theories의 raw chunks를 합침
    final allRawChunks = <SourceChunk>[];
    for (final theory in inputTheories) {
      if (theory.rawChunks != null) {
        allRawChunks.addAll(theory.rawChunks!);
      }
    }

    final theories = (theoriesList ?? []).map((item) {
      final m = item as Map<String, dynamic>;
      final theoryName = m['theoryName'] as String? ?? 'Unknown Theory';

      return InstructionalTheory(
        theoryName: theoryName,
        description: m['description'] as String? ?? '',
        applicability: m['applicability'] as String? ?? '',
        rawChunks: allRawChunks.isNotEmpty ? allRawChunks : null,
      );
    }).toList();

    return (syllabus: syllabus, theories: theories);
  }

  // 초기 정보 or 재설계 요청이 들어왔을 때 syllabus를 생성하기 위한 프롬프트
  String _buildPrompt(
    LearnerProfile profile, {
    ResourceCache? resourceCache,
    String? redesignRequest,
  }) {
    final level = profile.level?.name ?? '미정';
    final tone = profile.tonePreference?.name ?? '미정';
    final redesignNote = redesignRequest == null
        ? ''
        : '\n[재설계 요청]\n- $redesignRequest\n- 위 요청을 반드시 반영하라.';

    // ResourceCache에서 참고 자료 구성
    final resourceBlock = _buildResourceBlock(resourceCache);

    return '''너는 전문 교수설계자(Instructional Designer)다.
학습자의 프로필을 바탕으로 '주제(subject)'를 마스터하여 '목표(goal)'에 도달할 수 있는 커리큘럼을 설계하라.

[입력 정보]
- subject: ${profile.subject}
- goal: ${profile.goal}
- level: $level
- tone_preference: $tone
$redesignNote
$resourceBlock

[커리큘럼 설계 원칙]
1) 단계는 1~5개로 구성하라.
2) 주제가 매우 쉬우면 단계를 줄여도 된다.
3) 불필요하게 길게 늘어뜨리지 말고 목표 달성에 필요한 최소 단계만 제시하라.
4) 각 단계는 명확한 소주제(topic)와 구체적인 학습목표(objective)를 포함해야 한다.
5) level에 맞게 난이도를 조절하라.
6) 최종 단계는 goal과 직접 연결되어야 한다.
7) 각 단계는 이전 단계의 지식을 기반으로 해야 한다.
8) 참고 자료의 교수설계 이론을 적극 활용하여 효과적인 커리큘럼을 설계하라.

[교수설계 이론 추출]
참고 자료에 제공된 교수설계 이론 중에서:
1) 이 커리큘럼 설계에 실제로 적용한 이론을 최대 3개 선택하라.
2) 각 이론에 대해:
   - theoryName: 정확한 이론 명칭
   - description: 이론의 핵심 개념 (2-3문장)
   - applicability: 이 커리큘럼에서 어떻게 적용했는지 구체적으로 설명
3) 참고 자료에 없는 이론을 만들어내지 마라.
4) 참고 자료가 없다면 theories는 빈 배열로 반환하라.

[출력 규칙]
- 반드시 JSON만 출력하라.
- syllabus와 theories 필드를 모두 포함하라.''';
  }

  // ResourceCache에서 참고 자료 블록 생성
  String _buildResourceBlock(ResourceCache? cache) {
    if (cache == null || !cache.isResourceReady) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n[참고 자료]');

    // 학습 주제 개념 (Wikidata)
    if (cache.learningResources.isNotEmpty) {
      buffer.writeln('## 주제 개념');
      for (final resource in cache.learningResources) {
        buffer.writeln('- ${resource.title}: ${resource.summary}');
      }
    }

    // 교수설계 이론 (RAG)
    if (cache.instructionalTheories.isNotEmpty) {
      buffer.writeln('## 교수설계 이론');
      for (final theory in cache.instructionalTheories) {
        buffer.writeln('- ${theory.theoryName}: ${theory.description}');
      }
    }

    return buffer.toString();
  }
}
