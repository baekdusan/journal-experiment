import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import '../providers/streaming_message_provider.dart';

/// 단일 채팅 메시지를 말풍선 형태로 표시하는 위젯.
///
/// [Message.role]에 따라 스타일이 달라진다:
/// - **사용자 메시지**: 오른쪽 정렬, primary 색상 배경, 일반 텍스트
/// - **AI 메시지**: 왼쪽 정렬, surfaceVariant 색상 배경, 마크다운 렌더링, 로봇 아이콘
///
/// **스트리밍 처리:**
/// - [StreamingMessageProvider]를 감시하여 스트리밍 중인 메시지의 실시간 내용을 표시
/// - 스트리밍이 완료되면 [Message.content]를 표시
///
/// 말풍선 모서리는 발신자 방향의 하단만 각지게 처리하여 대화 흐름을 시각적으로 표현한다.
class MessageBubble extends ConsumerWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == MessageRole.user;
    final theme = Theme.of(context);

    // 스트리밍 상태 감시
    final streamingState = ref.watch(streamingMessageProvider);
    final isCurrentlyStreaming = streamingState?.messageId == message.id;

    // 표시할 내용 결정: 스트리밍 중이면 실시간 내용, 아니면 메시지 내용
    final displayContent = isCurrentlyStreaming
        ? streamingState!.content
        : message.content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[_buildAvatar(context), const SizedBox(width: 14)],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: EdgeInsets.symmetric(
                horizontal: isUser ? 16 : 0,
                vertical: isUser ? 12 : 2,
              ),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF343541) : Colors.transparent,
                borderRadius:
                    isUser ? BorderRadius.circular(20) : BorderRadius.zero,
              ),
              child: _buildContent(context, theme, isUser, displayContent),
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
  Widget _buildContent(
      BuildContext context, ThemeData theme, bool isUser, String content) {
    // 빈 내용 처리
    final effectiveContent = content.isEmpty ? '...' : content;

    if (isUser || message.role == MessageRole.system) {
      // 사용자 및 시스템 메시지: 일반 텍스트
      return Text(
        effectiveContent,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isUser ? Colors.white : theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      );
    } else {
      // AI 메시지: 마크다운 렌더링
      return MarkdownBody(
        data: effectiveContent,
        styleSheet: _buildMarkdownStyleSheet(theme),
        selectable: true,
      );
    }
  }

  /// Material 3 테마와 일치하는 마크다운 스타일시트를 생성한다.
  MarkdownStyleSheet _buildMarkdownStyleSheet(ThemeData theme) {
    final baseTextStyle = theme.textTheme.bodyLarge?.copyWith(
      color: const Color(0xFF1F1F1F),
      height: 1.6,
    );

    return MarkdownStyleSheet(
      // 기본 텍스트
      p: baseTextStyle,

      // 헤딩
      h1: theme.textTheme.headlineLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
      h2: theme.textTheme.headlineMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
      h3: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
      h4: theme.textTheme.titleLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
      h5: theme.textTheme.titleMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),
      h6: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
      ),

      // 코드
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'monospace',
        backgroundColor: const Color(0xFFECECF1),
        color: const Color(0xFF1F1F1F),
      ),
      codeblockDecoration: BoxDecoration(
        color: const Color(0xFFECECF1),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),

      // 리스트
      listBullet: baseTextStyle,

      // 링크
      a: baseTextStyle?.copyWith(
        color: const Color(0xFF0B57D0),
        decoration: TextDecoration.underline,
      ),

      // 강조
      em: baseTextStyle?.copyWith(fontStyle: FontStyle.italic),
      strong: baseTextStyle?.copyWith(fontWeight: FontWeight.bold),

      // 인용구
      blockquote: baseTextStyle?.copyWith(
        color: const Color(0xFF4D4F5A),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFF10A37F),
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16),

      // 블록 요소 간격
      blockSpacing: 12.0,
      listIndent: 24.0,
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: const Color(0xFF10A37F),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}
