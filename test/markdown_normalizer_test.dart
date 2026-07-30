import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:research_chatbot/utils/markdown_normalizer.dart';

/// 보정된 문자열을 실제 마크다운 파서에 통과시켜 확인한다.
/// flutter_markdown이 내부적으로 쓰는 것과 같은 `markdown` 패키지다.
String render(String source) =>
    md.markdownToHtml(normalizeForDisplay(source), inlineOnly: false);

void main() {
  group('CJK 강조 보정', () {
    test('조사가 붙은 닫는 마커도 강조로 인식된다', () {
      // 닫는 `**`가 ")" 뒤 + "을" 앞 → CommonMark right-flanking 실패 케이스.
      const raw = '우리는 **검정력 분석(Power Analysis)**을 진행한다.';
      expect(md.markdownToHtml(raw), contains('**')); // 보정 전에는 깨진다
      final html = render(raw);
      expect(html, isNot(contains('**')));
      expect(html, contains('<strong>'));
      expect(html, contains('검정력 분석(Power Analysis)'));
    });

    test('따옴표를 감싼 강조도 인식된다', () {
      final html = render("**'효과 크기'**는 중요하다");
      expect(html, isNot(contains('**')));
      expect(html, contains('<strong>'));
    });

    test('여러 강조가 섞여 있어도 각각 닫힌다', () {
      final html = render('**1종 오류**와 **2종 오류**의 관계');
      expect(html, isNot(contains('**')));
      expect('<strong>'.allMatches(html).length, 2);
    });

    test('이탤릭도 같은 방식으로 닫힌다', () {
      final html = render('*표본 크기(N)*를 정한다');
      expect(html, contains('<em>'));
      expect(html, isNot(contains(RegExp(r'(?<!<)\*'))));
    });

    test('코드 스팬·코드 블록은 건드리지 않는다', () {
      const raw = '파이썬의 `**kwargs`는 그대로 둔다';
      expect(normalizeForDisplay(raw), raw);
      const block = '```python\ndef f(**kwargs): pass\n```';
      expect(normalizeForDisplay(block), block);
    });
  });

  group('LaTeX → 유니코드', () {
    test('그리스 문자 인라인 수식', () {
      expect(normalizeForDisplay(r'1종 오류($\alpha$)와 2종 오류($\beta$)'),
          '1종 오류(α)와 2종 오류(β)');
    });

    test('연산이 섞인 인라인 수식', () {
      expect(normalizeForDisplay(r'검정력($1-\beta$)'), '검정력(1-β)');
    });

    test('첨자는 유니코드 첨자로', () {
      expect(normalizeForDisplay(r'$\sigma^2$의 추정'), 'σ²의 추정');
      expect(normalizeForDisplay(r'$x_1$과 $x_2$'), 'x₁과 x₂');
    });

    test('첨자로 못 바꾸는 인자는 괄호 폴백', () {
      expect(normalizeForDisplay(r'$z_{1-\alpha/2}$'), 'z_(1-α/2)');
    });

    test('분수·텍스트 명령', () {
      expect(normalizeForDisplay(r'$\frac{\sigma}{\sqrt{n}}$'), 'σ/√n');
      expect(normalizeForDisplay(r'$\text{SESOI} \le d$'), 'SESOI ≤ d');
    });

    test('display 수식도 처리한다', () {
      expect(normalizeForDisplay(r'$$n = \frac{2\sigma^2}{\delta^2}$$'),
          'n = (2σ²)/(δ²)');
    });

    test('통화 표기는 수식으로 오인하지 않는다', () {
      const raw = '비용은 \$5에서 \$10 사이다';
      expect(normalizeForDisplay(raw), raw);
    });

    test('강조 안의 수식도 함께 처리된다', () {
      final html = render(r'**1종 오류($\alpha$)와 검정력($1-\beta$)**의 관계');
      expect(html, isNot(contains('**')));
      expect(html, isNot(contains(r'\alpha')));
      expect(html, contains('<strong>'));
      expect(html, contains('1종 오류(α)와 검정력(1-β)'));
    });
  });
}
