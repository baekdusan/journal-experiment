import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_view.dart';

/// 채팅 앱의 메인 화면.
///
/// 실험 집중도를 높이기 위해 단일 세션 모드로 동작하며,
/// 사이드바 없이 [ChatView]만 표시한다.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeSession = ref.watch(activeSessionProvider);
    final canExport = activeSession != null && activeSession.messages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        // 참가자에게 조건 정보(ADDIE)가 새지 않도록 중립 명칭을 쓴다.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome,
              size: 20,
              color: Color(0xFF4E86FF),
            ),
            const SizedBox(width: 8),
            Text(
              'AI Tutor',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          _ExportButton(enabled: canExport),
          _NewSessionButton(hasMessages: canExport),
          const SizedBox(width: 4),
        ],
      ),
      body: const ChatView(),
    );
  }
}

/// 현재 세션의 대화 기록을 JSON 파일로 다운로드하는 액션 버튼.
///
/// 실험 데이터 수집 용도. 메시지가 없으면 비활성화된다.
class _ExportButton extends ConsumerWidget {
  final bool enabled;

  const _ExportButton({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: enabled ? '대화 기록 저장' : '저장할 메시지가 없습니다',
      onPressed: enabled ? () => _onPressed(context, ref) : null,
      icon: Icon(
        Icons.file_download_outlined,
        size: 22,
        color: enabled ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final session = ref.read(activeSessionProvider);
    if (session == null) return;

    try {
      await ref
          .read(chatControllerProvider.notifier)
          .downloadSession(session.id);
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('대화 기록을 저장했습니다.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// 현재 대화와 학습 상태를 모두 초기화하고 새 대화를 시작하는 버튼.
///
/// 실험 케이스를 깨끗하게 다시 시작할 때 사용한다.
/// 학습 상태는 SharedPreferences에 영속화되므로 새로고침/재시작만으로는
/// 지워지지 않는다. 이 버튼이 prefs까지 초기화한다.
class _NewSessionButton extends ConsumerWidget {
  final bool hasMessages;

  const _NewSessionButton({required this.hasMessages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: '새 대화 시작 (초기화)',
      onPressed: () => _onPressed(context, ref),
      icon: Icon(Icons.restart_alt, size: 22, color: cs.onSurface),
    );
  }

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    if (hasMessages) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('새 대화를 시작할까요?'),
          content: const Text('현재 대화와 학습 상태가 모두 초기화됩니다. 저장이 필요하면 먼저 대화 기록을 내보내세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('초기화'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    ref.read(chatControllerProvider.notifier).createNewSession();
  }
}
