import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:research_chatbot/services/llm_call_recorder.dart';

/// 파일럿에서 실제로 난 Vertex AI 429를 재시도 대상으로 잡고,
/// 안전 차단·권한 오류처럼 다시 해도 소용없는 것은 즉시 실패시킨다.
void main() {
  test('429 Resource exhausted / 503 / overloaded는 재시도한다', () {
    expect(
      LlmRetryPolicy.isRetryable(Exception(
          'Resource exhausted. Please try again later. Please refer to '
          'https://cloud.google.com/vertex-ai/generative-ai/docs/error-code-429')),
      isTrue,
    );
    expect(LlmRetryPolicy.isRetryable(Exception('503 Service Unavailable')), isTrue);
    expect(LlmRetryPolicy.isRetryable(Exception('The model is overloaded')), isTrue);
  });

  test('안전 차단·400·403은 재시도하지 않는다', () {
    expect(LlmRetryPolicy.isRetryable(Exception('Response was blocked due to safety')), isFalse);
    expect(LlmRetryPolicy.isRetryable(Exception('400 Bad Request: invalid argument')), isFalse);
    expect(LlmRetryPolicy.isRetryable(Exception('403 permission denied')), isFalse);
  });

  test('백오프는 1s·2s·4s에 지터 0~300ms', () {
    final r = Random(1);
    final d1 = LlmRetryPolicy.delayFor(1, random: r).inMilliseconds;
    final d2 = LlmRetryPolicy.delayFor(2, random: r).inMilliseconds;
    final d3 = LlmRetryPolicy.delayFor(3, random: r).inMilliseconds;
    expect(d1, inInclusiveRange(1000, 1300));
    expect(d2, inInclusiveRange(2000, 2300));
    expect(d3, inInclusiveRange(4000, 4300));
    expect(LlmRetryPolicy.maxAttempts, 4);
  });

  test('searchEntryPoint HTML의 칩에서 검색어를 복원한다', () {
    const html = '<div class="container"><div class="carousel">'
        '<a class="chip" href="https://www.google.com/search?q=a">블록체인 합의 알고리즘</a>'
        '<a class="chip" href="https://www.google.com/search?q=b">PoW &amp; PoS 비교</a>'
        '<a class="chip" href="https://www.google.com/search?q=a">블록체인 합의 알고리즘</a>'
        '</div></div>';
    expect(
      extractQueriesFromEntryPoint(html),
      ['블록체인 합의 알고리즘', 'PoW & PoS 비교'],
    );
    expect(extractQueriesFromEntryPoint(null), isEmpty);
    expect(extractQueriesFromEntryPoint(''), isEmpty);
  });
}
