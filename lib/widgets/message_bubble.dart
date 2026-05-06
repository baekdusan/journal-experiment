import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import '../providers/streaming_message_provider.dart';

/// 단일 채팅 메시지를 ChatGPT 5.x 스타일로 표시하는 위젯.
///
/// - **사용자 메시지**: 오른쪽 정렬, 옅은 회색 라운드 버블
/// - **AI 메시지**: 왼쪽 정렬, 배경 없는 텍스트(마크다운), 모노크롬 아바타
///
/// **스트리밍 처리:**
/// - [StreamingMessageProvider]를 감시하여 스트리밍 중인 메시지의 실시간 내용을 표시
/// - 스트리밍이 완료되면 [Message.content]를 표시
class MessageBubble extends ConsumerWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == MessageRole.user;
    final theme = Theme.of(context);

    final streamingState = ref.watch(streamingMessageProvider);
    final isCurrentlyStreaming = streamingState?.messageId == message.id;

    final displayContent = isCurrentlyStreaming
        ? streamingState!.content
        : message.content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[_buildAvatar(theme), const SizedBox(width: 14)],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
                  : const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius:
                    isUser ? BorderRadius.circular(22) : BorderRadius.zero,
              ),
              child: _buildContent(theme, isUser, displayContent),
            ),
          ),
        ],
      ),
    );
  }

  /// 메시지 내용을 렌더링한다.
  ///
  /// - **사용자/시스템 메시지**: 일반 텍스트로 표시
  /// - **AI 메시지**: 마크다운으로 렌더링 (코드 블록, 헤딩, 강조 등 지원)
  Widget _buildContent(ThemeData theme, bool isUser, String content) {
    final effectiveContent = content.isEmpty ? '...' : content;

    if (isUser || message.role == MessageRole.system) {
      return Text(
        effectiveContent,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.5,
          fontSize: 16,
        ),
      );
    } else {
      return MarkdownBody(
        data: effectiveContent,
        styleSheet: _buildMarkdownStyleSheet(theme),
        selectable: true,
      );
    }
  }

  /// 최신 ChatGPT 톤(monochrome, 가독성 우선)에 맞춘 마크다운 스타일.
  MarkdownStyleSheet _buildMarkdownStyleSheet(ThemeData theme) {
    final cs = theme.colorScheme;
    final baseTextStyle = theme.textTheme.bodyLarge?.copyWith(
      color: cs.onSurface,
      height: 1.65,
      fontSize: 16,
    );

    return MarkdownStyleSheet(
      p: baseTextStyle,
      h1: theme.textTheme.headlineSmall?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w700,
      ),
      h3: theme.textTheme.titleMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      h4: theme.textTheme.titleSmall?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      h5: theme.textTheme.bodyLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      h6: theme.textTheme.bodyMedium?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w600,
      ),
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: cs.surfaceContainerHigh,
        color: cs.onSurface,
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      codeblockPadding: const EdgeInsets.all(14),
      listBullet: baseTextStyle,
      a: baseTextStyle?.copyWith(
        color: cs.onSurface,
        decoration: TextDecoration.underline,
      ),
      em: baseTextStyle?.copyWith(fontStyle: FontStyle.italic),
      strong: baseTextStyle?.copyWith(fontWeight: FontWeight.w700),
      blockquote: baseTextStyle?.copyWith(
        color: cs.onSurfaceVariant,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: cs.outline,
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16),
      blockSpacing: 14.0,
      listIndent: 24.0,
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white : Colors.black,
      ),
      child: Icon(
        Icons.auto_awesome,
        size: 15,
        color: isDark ? Colors.black : Colors.white,
      ),
    );
  }
}
