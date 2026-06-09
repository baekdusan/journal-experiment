import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/instructional_design.dart';
import '../config/ai_models.dart';

/// 단계 진행 평가 결과.
class StepProgressResult {
  /// 현재 단계의 학습목표가 충분히 다뤄졌는지 여부.
  final bool stepCompleted;

  /// 판정 확신도 (0.0~1.0).
  final double confidence;

  StepProgressResult({
    required this.stepCompleted,
    required this.confidence,
  });
}

/// in-class 튜터 턴 종료 후, 현재 단계의 학습목표 달성 여부를 판정하는 Micro-Agent.
///
/// 이 서비스는 "다음 단계로 넘어갈지"를 직접 결정하지 않는다.
/// 불리언 신호(`step_completed`)만 생성하고, 실제 단계 전진은 [ChatController]가
/// 단조 전진 규칙으로 수행한다 ("앱이 판단, LLM은 생성만").
class StepProgressService {
  Future<StepProgressResult> evaluate({
    required Step currentStep,
    required List<String> recentHistory,
  }) async {
    final schema = Schema.object(
      properties: {
        'step_completed': Schema.boolean(
          description: '현재 단계 학습목표가 충분히 다뤄져 다음 단계로 넘어가도 되는가',
        ),
        'confidence': Schema.number(
          description: '판정 확신도 (0.0~1.0)',
        ),
      },
    );

    final model =
        FirebaseAI.vertexAI(location: AiModels.extractor.location).generativeModel(
      model: AiModels.extractor.model,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: schema,
        temperature: 0.0,
      ),
    );

    final historyBlock =
        recentHistory.isEmpty ? '없음' : recentHistory.join('\n');

    final prompt = '''너는 학습 진행을 판정하는 평가자다.
아래 "현재 단계"의 학습목표가 최근 대화에서 충분히 다뤄져
다음 단계로 넘어가도 되는지 판단하라.

[현재 단계]
- 주제: ${currentStep.topic}
- 학습목표: ${currentStep.objective}

[최근 대화]
$historyBlock

[판정 규칙]
1) 학습자가 목표 개념을 이해했다는 근거(질문 해소, 올바른 재진술, 적용 등)가 보이면 step_completed=true.
2) 아직 설명 중이거나 혼란/추가 질문이 남아 있으면 step_completed=false.
3) 애매하면 보수적으로 false로 두고 confidence를 낮게 매겨라.

[출력 규칙]
- 반드시 JSON만 출력하라.''';

    final response = await model.generateContent([Content.text(prompt)]);
    final raw = response.text;
    if (raw == null || raw.isEmpty) {
      return StepProgressResult(stepCompleted: false, confidence: 0.0);
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final completed = data['step_completed'] as bool? ?? false;
      final confidenceRaw = data['confidence'];
      final confidence = confidenceRaw is num ? confidenceRaw.toDouble() : 0.0;
      return StepProgressResult(
        stepCompleted: completed,
        confidence: confidence.clamp(0.0, 1.0),
      );
    } catch (_) {
      return StepProgressResult(stepCompleted: false, confidence: 0.0);
    }
  }
}
