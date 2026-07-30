/// LLM 출력을 화면에 그리기 직전에 보정하는 순수 함수 모음.
///
/// 처치군·대조군이 **동일하게** 거치는 표시 계층이다. 프롬프트로 출력 형식을
/// 제약하면 시스템 프롬프트가 없는 대조군만 깨져 화면 품질이 조건 간 교란
/// 변인이 되므로, 형식 보정은 반드시 여기(렌더러 공용)에서 한다.
///
/// 보정 대상:
/// 1. CJK 경계에서 닫히지 않는 마크다운 강조 (`**강조**을` → `**`가 그대로 노출)
/// 2. 렌더러가 지원하지 않는 인라인 LaTeX (`$\alpha$` → `α`)
library;

/// 폭 없는 공백(U+200B). CommonMark의 whitespace/punctuation 어느 쪽에도
/// 속하지 않아(general category Cf) 강조 마커의 flanking 판정을 항상 통과시킨다.
const _zwsp = '\u200B';

/// 코드 블록·코드 스팬. 이 안쪽은 원문 그대로 보존한다(`**kwargs` 등).
final _codeSegment = RegExp(r'```[\s\S]*?```|~~~[\s\S]*?~~~|`[^`\n]*`');

/// 표시용으로 마크다운을 정규화한다. 원문(`Message.content`)은 건드리지 않는다.
String normalizeForDisplay(String content) {
  return _outsideCode(content, (text) {
    return _fixCjkEmphasis(_convertLatex(text));
  });
}

/// 코드 영역을 건너뛰고 나머지 구간에만 [transform]을 적용한다.
String _outsideCode(String text, String Function(String) transform) {
  final out = StringBuffer();
  var last = 0;
  for (final m in _codeSegment.allMatches(text)) {
    out.write(transform(text.substring(last, m.start)));
    out.write(m[0]);
    last = m.end;
  }
  out.write(transform(text.substring(last)));
  return out.toString();
}

// ---------------------------------------------------------------------------
// 1. CJK 강조 보정
// ---------------------------------------------------------------------------

final _bold = RegExp(r'\*\*(?=\S)((?:(?!\*\*)[\s\S])+?)(?<=\S)\*\*');
final _italic = RegExp(r'(?<!\*)\*(?=[^\s*])((?:(?!\*)[\s\S])+?)(?<=[^\s*])\*(?!\*)');

/// 강조 마커 **안쪽** 양 끝에 [_zwsp]를 넣어 강조가 항상 닫히게 만든다.
///
/// CommonMark는 닫는 `**`가 구두점 뒤에 오면서 뒤에 공백/구두점이 없으면
/// right-flanking으로 보지 않는다. 한국어는 `**...(Power Analysis)**을`처럼
/// 괄호·따옴표 뒤에 조사가 바로 붙는 형태가 흔해 이 조건에 계속 걸린다.
/// 마커 바로 안쪽에 폭 없는 공백을 두면 앞뒤 문자가 구두점도 공백도 아니게 되어
/// 여는 쪽·닫는 쪽 판정이 모두 통과한다. 화면에는 아무것도 보이지 않는다.
String _fixCjkEmphasis(String text) {
  return text
      .replaceAllMapped(_bold, (m) => '**$_zwsp${m[1]}$_zwsp**')
      .replaceAllMapped(_italic, (m) => '*$_zwsp${m[1]}$_zwsp*');
}

// ---------------------------------------------------------------------------
// 2. LaTeX → 유니코드
// ---------------------------------------------------------------------------

final _displayMath = RegExp(r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]');
final _inlineMath = RegExp(r'\$(?=\S)([^\$\n]+?)(?<=\S)\$|\\\(([\s\S]+?)\\\)');

/// LaTeX처럼 보이는 신호. 통화 표기(`$5`)를 수식으로 오인하지 않기 위한 게이트.
final _mathSignal = RegExp(r'[\\^_]');
final _shortMathLike = RegExp(r'^[A-Za-z0-9][A-Za-z0-9\s+\-*/=().,<>]{0,18}$');

/// `$...$` / `$$...$$` / `\(...\)` / `\[...\]` 안의 LaTeX을 유니코드로 바꾼다.
///
/// 렌더러에 수식 엔진이 없어 원문이 그대로 노출되므로, 최소한 기호는 읽히게
/// 만든다. 통계 대화에서 실제로 쓰이는 그리스 문자·비교 연산자·첨자를 덮는다.
String _convertLatex(String text) {
  String replace(Match m) {
    final body = m[1] ?? m[2] ?? '';
    if (!_mathSignal.hasMatch(body) && !_shortMathLike.hasMatch(body.trim())) {
      return m[0]!; // 통화 등 수식이 아닌 `$` → 원문 유지
    }
    return _latexToUnicode(body);
  }

  return text
      .replaceAllMapped(_displayMath, replace)
      .replaceAllMapped(_inlineMath, replace);
}

const _symbols = <String, String>{
  // 그리스 문자
  r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ', r'\delta': 'δ',
  r'\epsilon': 'ε', r'\varepsilon': 'ε', r'\zeta': 'ζ', r'\eta': 'η',
  r'\theta': 'θ', r'\vartheta': 'θ', r'\iota': 'ι', r'\kappa': 'κ',
  r'\lambda': 'λ', r'\mu': 'μ', r'\nu': 'ν', r'\xi': 'ξ', r'\pi': 'π',
  r'\rho': 'ρ', r'\sigma': 'σ', r'\tau': 'τ', r'\upsilon': 'υ',
  r'\phi': 'φ', r'\varphi': 'φ', r'\chi': 'χ', r'\psi': 'ψ', r'\omega': 'ω',
  r'\Gamma': 'Γ', r'\Delta': 'Δ', r'\Theta': 'Θ', r'\Lambda': 'Λ',
  r'\Xi': 'Ξ', r'\Pi': 'Π', r'\Sigma': 'Σ', r'\Phi': 'Φ', r'\Psi': 'Ψ',
  r'\Omega': 'Ω',
  // 연산자·관계
  r'\times': '×', r'\cdot': '·', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥',
  r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\sim': '∼', r'\propto': '∝', r'\infty': '∞', r'\ll': '≪', r'\gg': '≫',
  r'\sum': '∑', r'\prod': '∏', r'\int': '∫', r'\sqrt': '√',
  r'\partial': '∂', r'\nabla': '∇',
  r'\in': '∈', r'\notin': '∉', r'\subset': '⊂', r'\supset': '⊃',
  r'\cup': '∪', r'\cap': '∩', r'\emptyset': '∅',
  r'\forall': '∀', r'\exists': '∃', r'\neg': '¬',
  r'\Rightarrow': '⇒', r'\Leftarrow': '⇐', r'\Leftrightarrow': '⇔',
  r'\rightarrow': '→', r'\leftarrow': '←', r'\leftrightarrow': '↔',
  r'\to': '→', r'\mapsto': '↦',
  r'\ldots': '…', r'\dots': '…', r'\cdots': '⋯', r'\degree': '°',
  r'\%': '%', r'\&': '&', r'\#': '#', r'\$': r'$',
};

/// 제거만 하면 되는 서식 명령(간격·구분자·크기 조절).
/// 긴 이름을 먼저 두어 `\quad`가 `\qquad`를 잘라먹지 않게 한다.
final _dropCommands = RegExp(
  r'\\(?:displaystyle|limits|qquad|quad|left|right|Bigg|bigg|Big|big)'
  r'(?![A-Za-z])|\\[,;:!]',
);

const _superscript = <String, String>{
  '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶',
  '7': '⁷', '8': '⁸', '9': '⁹', '+': '⁺', '-': '⁻', '=': '⁼', '(': '⁽',
  ')': '⁾', 'n': 'ⁿ', 'i': 'ⁱ', 'a': 'ᵃ', 'b': 'ᵇ', 'c': 'ᶜ', 'd': 'ᵈ',
  'e': 'ᵉ', 'k': 'ᵏ', 'm': 'ᵐ', 'p': 'ᵖ', 't': 'ᵗ', 'x': 'ˣ', 'y': 'ʸ',
  'T': 'ᵀ',
};

const _subscript = <String, String>{
  '0': '₀', '1': '₁', '2': '₂', '3': '₃', '4': '₄', '5': '₅', '6': '₆',
  '7': '₇', '8': '₈', '9': '₉', '+': '₊', '-': '₋', '=': '₌', '(': '₍',
  ')': '₎', 'a': 'ₐ', 'e': 'ₑ', 'h': 'ₕ', 'i': 'ᵢ', 'j': 'ⱼ', 'k': 'ₖ',
  'l': 'ₗ', 'm': 'ₘ', 'n': 'ₙ', 'o': 'ₒ', 'p': 'ₚ', 'r': 'ᵣ', 's': 'ₛ',
  't': 'ₜ', 'u': 'ᵤ', 'v': 'ᵥ', 'x': 'ₓ',
};

/// 첨자 지시자(`^`, `_`)와 그 인자. 인자는 `{...}` 또는 한 글자.
final _script = RegExp(r'([\^_])(?:\{([^{}]*)\}|(\\?[A-Za-z0-9+\-]))');

/// 인자를 취하는 명령. 한 단계 중첩(`\frac{σ}{\sqrt{n}}`)까지 허용한다.
const _arg = r'\{((?:[^{}]|\{[^{}]*\})*)\}';
final _frac = RegExp(r'\\(?:d|t)?frac\s*' '$_arg' r'\s*' '$_arg');
final _sqrt = RegExp(r'\\sqrt\s*' '$_arg');
final _unwrap = RegExp(
  r'\\(?:text|textrm|textbf|textit|mathrm|mathbf|mathit|mathsf|operatorname)\s*'
  '$_arg',
);
final _accent = RegExp(r'\\(bar|hat|overline|vec|tilde|dot)\s*\{?([A-Za-z])\}?');

const _accentMark = <String, String>{
  'bar': '\u0304', 'overline': '\u0304', 'hat': '\u0302',
  'vec': '\u20D7', 'tilde': '\u0303', 'dot': '\u0307',
};

String _latexToUnicode(String source) {
  var s = source;

  // 인자를 취하는 명령부터 처리한다(안쪽 기호 변환보다 먼저).
  // 중첩된 인자는 한 번에 다 풀리지 않으므로 변화가 멈출 때까지 반복한다.
  s = s.replaceAllMapped(_unwrap, (m) => m[1]!);
  for (var i = 0; i < 4; i++) {
    final before = s;
    s = s.replaceAllMapped(
      _sqrt,
      (m) => '√${_wrapIfCompound(m[1]!.trim())}',
    );
    s = s.replaceAllMapped(_frac, (m) {
      final numerator = _wrapIfCompound(m[1]!.trim());
      final denominator = _wrapIfCompound(m[2]!.trim());
      return '$numerator/$denominator';
    });
    if (s == before) break;
  }
  s = s.replaceAllMapped(
    _accent,
    (m) => '${m[2]}${_accentMark[m[1]] ?? ''}',
  );

  // 기호 치환. 긴 이름이 짧은 이름의 접두사인 경우(\le ⊂ \leq)를 피하려고
  // 이름 길이 내림차순으로 적용한다.
  final names = _symbols.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final name in names) {
    s = s.replaceAll(name, _symbols[name]!);
  }

  s = s.replaceAll(_dropCommands, '');
  s = s.replaceAllMapped(_script, (m) {
    final isSuper = m[1] == '^';
    final arg = (m[2] ?? m[3] ?? '').trim();
    return _toScript(arg, isSuper) ?? '${m[1]}${_wrapIfCompound(arg)}';
  });

  // 남은 정렬·개행 지시자와 처리되지 않은 명령의 중괄호를 정리한다.
  s = s.replaceAll(RegExp(r'\\\\'), ' ').replaceAll('&', ' ');
  s = s.replaceAll(RegExp(r'[{}]'), '');
  return s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

/// 두 글자 이상이면서 연산자를 포함하면 괄호로 묶어 우선순위를 보존한다.
String _wrapIfCompound(String s) {
  if (s.length <= 1 || RegExp(r'^\(.*\)$').hasMatch(s)) return s;
  return RegExp(r'[+\-×÷/·^_ ]').hasMatch(s) ? '($s)' : s;
}

/// 모든 글자가 유니코드 첨자로 바뀔 때만 변환하고, 아니면 null(폴백).
String? _toScript(String arg, bool isSuper) {
  if (arg.isEmpty) return null;
  final table = isSuper ? _superscript : _subscript;
  final out = StringBuffer();
  for (final ch in arg.split('')) {
    final mapped = table[ch];
    if (mapped == null) return null;
    out.write(mapped);
  }
  return out.toString();
}
