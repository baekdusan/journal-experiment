import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/experiment_config.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

/// 실험 시작 화면: 참가자 이름 + 시작 버튼.
///
/// 시작 버튼이 실험의 t=0이다. 누르는 순간 대화·학습 상태·텔레메트리를 초기화하고
/// 참가자 이름과 시작 시각을 기록한 뒤 채팅 화면으로 넘어간다.
/// 조건(처치/대조)은 화면에 드러내지 않는다 — 양 조건이 같은 화면을 본다.
class StartScreen extends ConsumerStatefulWidget {
  const StartScreen({super.key});

  @override
  ConsumerState<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends ConsumerState<StartScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ExperimentConfig.participantIdFromUrl ?? '',
    );
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _name => _controller.text.trim();

  void _start() {
    final name = _name;
    if (name.isEmpty) return;
    ref.read(chatControllerProvider.notifier).startExperiment(name);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final glowColor = isDark
        ? const Color(0xFF0842A0).withValues(alpha: 0.25)
        : const Color(0xFFD3E3FD).withValues(alpha: 0.9);
    final canStart = _name.isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, 0.05),
            radius: 0.85,
            colors: [glowColor, glowColor.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        size: 28,
                        color: Color(0xFF4E86FF),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AI Tutor',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '이름을 입력하고 시작 버튼을 눌러 주세요.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    key: const ValueKey('participant-name'),
                    controller: _controller,
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _start(),
                    style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                    decoration: InputDecoration(
                      labelText: '참가자 이름',
                      filled: true,
                      fillColor: isDark ? cs.surfaceContainer : cs.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('start-button'),
                    onPressed: canStart ? _start : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '시작하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
