import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../models/instructional_design.dart';
import '../config/agent_prompts.dart';
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

    // 프롬프트 원문: lib/config/agent_prompts.dart → AgentPrompts.stepProgress
    final prompt = AgentPrompts.stepProgress(
      currentStep: currentStep,
      recentHistory: recentHistory,
    );

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
