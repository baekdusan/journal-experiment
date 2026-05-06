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
        title: Text(
          'ADDIE Tutor',
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          _ExportButton(enabled: canExport),
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
