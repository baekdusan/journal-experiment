import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../config/agent_prompts.dart';
import '../config/ai_models.dart';
import '../models/telemetry.dart';
import 'llm_call_recorder.dart';

enum IntentResult {
  inClass,
  outOfClass;

  static IntentResult fromJson(String value) {
    return value == 'out_of_class' ? IntentResult.outOfClass : IntentResult.inClass;
  }
}

/// 분류 결과 + 호출 기록. 파싱 실패로 기본값이 쓰였는지도 남긴다.
class IntentClassification {
  final IntentResult intent;
  final LlmCallRecord call;
  final bool fallback;
  IntentClassification({
    required this.intent,
    required this.call,
    this.fallback = false,
  });
}

class IntentClassifierService {
  Future<IntentClassification> classify(
    String userText, {
    String? previousTutorMessage,
  }) async {
    final schema = Schema.object(
      properties: {
        'intent': Schema.enumString(
          enumValues: ['out_of_class', 'in_class'],
          description: '사용자 발화 의도 분류',
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

    // 프롬프트 원문: lib/config/agent_prompts.dart → AgentPrompts.intentClassifier
    final prompt = AgentPrompts.intentClassifier(userText, previousTutorMessage);
    final (:response, :call) = await recordedGenerate(
      model: model,
      spec: AiModels.extractor,
      agent: 'intent',
      prompt: prompt,
    );
    final raw = response.text;
    if (raw == null || raw.isEmpty) {
      return IntentClassification(
          intent: IntentResult.inClass, call: call, fallback: true);
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final intent = data['intent'] as String?;
      if (intent == null) {
        return IntentClassification(
            intent: IntentResult.inClass, call: call, fallback: true);
      }
      return IntentClassification(
          intent: IntentResult.fromJson(intent), call: call);
    } catch (_) {
      return IntentClassification(
          intent: IntentResult.inClass, call: call, fallback: true);
    }
  }

}
