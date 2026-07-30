import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import '../providers/streaming_message_provider.dart';
import '../utils/markdown_normalizer.dart';
import 'typing_indicator.dart';

/// 단일 채팅 메시지를 Gemini 웹 앱 스타일로 표시하는 위젯.
///
/// - **사용자 메시지**: 오른쪽 정렬, 회청색(#F0F4F9) 라운드 필 버블
/// - **AI 메시지**: 왼쪽 정렬, 아바타 없이 배경 없는 텍스트(마크다운)
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

    // 이 메시지가 스트리밍 대상일 때만 청크를 구독한다. 전체 상태를 그대로
    // 감시하면 청크마다 모든 버블이 리빌드되고, flutter_markdown이 내부적으로
    // UniqueKey를 새로 발급해(builder.dart:1046) 진행 중인 텍스트 선택이 끊긴다.
    final streamingContent = ref.watch(
      streamingMessageProvider.select(
        (s) => s?.messageId == message.id ? s!.content : null,
      ),
    );
    final displayContent = streamingContent ?? message.content;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints:
                  BoxConstraints(maxWidth: isUser ? 560 : 720),
              padding: isUser
                  ? const EdgeInsets.symmetric(horizontal: 20, vertical: 13)
                  : const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: isUser
                    ? theme.colorScheme.surfaceContainerHigh
                    : Colors.transparent,
                borderRadius:
                    isUser ? BorderRadius.circular(24) : BorderRadius.zero,
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
    // AI 메시지인데 표시할 내용이 비어 있으면(스트리밍 첫 토큰 대기) 타이핑 점을 보여준다.
    if (!isUser && message.role != MessageRole.system && content.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: TypingDots(),
      );
    }

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
        // CJK 강조 깨짐 + 미지원 LaTeX 보정. 양 실험 조건이 공유하는 표시 계층
        // 이므로 형식 보정은 프롬프트가 아니라 여기서 한다.
        data: normalizeForDisplay(effectiveContent),
        styleSheet: _buildMarkdownStyleSheet(theme),
        // selectable: true는 블록마다 독립적인 SelectableText를 만들어
        // (builder.dart:1049) 문단 하나를 넘어가는 드래그가 불가능해진다.
        // 대신 chat_view.dart의 SelectionArea가 리스트 전체를 하나의 선택
        // 영역으로 묶는다 — Text.rich는 상위 SelectionRegistrar에 참여한다.
        selectable: false,
      );
    }
  }

  /// Gemini 톤(가벼운 헤딩, 블루 링크)에 맞춘 마크다운 스타일.
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
        fontWeight: FontWeight.w500,
      ),
      h2: theme.textTheme.titleLarge?.copyWith(
        color: cs.onSurface,
        fontWeight: FontWeight.w500,
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
        backgroundColor: cs.surfaceContainer,
        color: cs.onSurface,
      ),
      codeblockDecoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      codeblockPadding: const EdgeInsets.all(14),
      listBullet: baseTextStyle,
      a: baseTextStyle?.copyWith(
        color: cs.primary,
        decoration: TextDecoration.underline,
        decorationColor: cs.primary,
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
}
