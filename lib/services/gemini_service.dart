import 'package:firebase_ai/firebase_ai.dart';
import '../models/message.dart';
import '../config/ai_models.dart';

/// Firebase AI(Vertex AI in Firebase)를 통해 Gemini 모델과 통신하는 서비스 클래스.
///
/// 스트리밍 응답을 지원하여 AI가 생성하는 텍스트를 토큰 단위로 실시간 수신할 수 있다.
/// 이를 통해 사용자는 전체 응답을 기다리지 않고 타이핑되는 듯한 자연스러운 UX를 경험한다.
///
/// Riverpod의 [geminiServiceProvider]를 통해 싱글톤으로 관리된다.
class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    // Using Vertex AI backend via Firebase AI
    _model = FirebaseAI.vertexAI(location: AiModels.tutor.location).generativeModel(
      model: AiModels.tutor.model,
    );
  }

  /// 사용자 프롬프트와 이전 대화 기록을 받아 스트리밍 응답 [Stream]을 반환한다.
  ///
  /// 내부적으로 앱의 [Message] 모델을 Firebase AI SDK가 요구하는 [Content] 형식으로 변환하며,
  /// 멀티턴 대화의 맥락을 유지하기 위해 전체 히스토리를 함께 전송한다.
  /// 각 청크가 도착할 때마다 문자열로 yield하여 UI에서 실시간 업데이트가 가능하다.
  Stream<String> streamResponse(List<Message> history, String prompt) async* {
    final chat = _model.startChat(
      history: history.map((m) {
        return Content(m.role == MessageRole.user ? 'user' : 'model', [
          TextPart(m.content),
        ]);
      }).toList(),
    );

    final content = Content.text(prompt);
    final response = chat.sendMessageStream(content);

    await for (final chunk in response) {
      if (chunk.text != null) {
        yield chunk.text!;
      }
    }
  }
}
