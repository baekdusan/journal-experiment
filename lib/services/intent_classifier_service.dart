import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import '../config/agent_prompts.dart';
import '../config/ai_models.dart';

enum IntentResult {
  inClass,
  outOfClass;

  static IntentResult fromJson(String value) {
    return value == 'out_of_class' ? IntentResult.outOfClass : IntentResult.inClass;
  }
}

class IntentClassifierService {
  Future<IntentResult> classify(
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
    final response = await model.generateContent([Content.text(prompt)]);
    final raw = response.text;
    if (raw == null || raw.isEmpty) {
      return IntentResult.inClass;
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final intent = data['intent'] as String?;
      if (intent == null) return IntentResult.inClass;
      return IntentResult.fromJson(intent);
    } catch (_) {
      return IntentResult.inClass;
    }
  }

}
