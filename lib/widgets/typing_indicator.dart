import 'package:flutter/material.dart';

/// 점 3개가 순차적으로 깜빡이는 타이핑 애니메이션(점만).
///
/// - 비스트리밍 응답 대기: [TypingIndicator](아바타 포함)에서 사용
/// - 스트리밍 첫 토큰 대기: 빈 메시지 버블 안에서 직접 사용
class TypingDots extends StatefulWidget {
  const TypingDots({super.key});

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // 각 점을 시차를 두고 깜빡이게 한다.
            final t = (_controller.value - i * 0.2) % 1.0;
            final opacity =
                0.3 + 0.7 * (1 - (t * 2 - 1).abs()).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// 아바타 + 타이핑 점. 비스트리밍 응답(니즈 분석·피드백·설계)을 준비하는 동안
/// 채팅 목록 끝에 독립 버블로 표시한다.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.onSurface,
              child: Icon(Icons.auto_awesome, size: 14, color: cs.surface),
            ),
            const SizedBox(width: 12),
            const TypingDots(),
          ],
        ),
      ),
    );
  }
}
