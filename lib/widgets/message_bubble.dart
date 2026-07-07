import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/message.dart';
import '../providers/streaming_message_provider.dart';
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

    final streamingState = ref.watch(streamingMessageProvider);
    final isCurrentlyStreaming = streamingState?.messageId == message.id;

    final displayContent = isCurrentlyStreaming
        ? streamingState!.content
        : message.content;

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
        data: _normalizeMarkdown(effectiveContent),
        styleSheet: _buildMarkdownStyleSheet(theme),
        selectable: true,
      );
    }
  }

  /// 한국어(CJK) 텍스트에서 마크다운 강조가 깨지는 경우를 보정한다.
  ///
  /// LLM이 `**'개념'**`처럼 강조 마커 안쪽에 따옴표를 넣으면, 닫는 `**`가
  /// "따옴표(구두점) + 한글" 경계에 놓여 CommonMark 강조 규칙상 인식되지 않는다.
  /// 따옴표를 강조 마커 바깥으로 옮겨(`'**개념**'`) 정상 렌더되게 한다.
  String _normalizeMarkdown(String content) {
    // 강조 마커 안쪽 양 끝에 붙은 따옴표류(' " ‘ ’ “ ”)를 바깥으로 이동.
    const q = "['\"‘’“”]";
    final boldFix = RegExp('\\*\\*($q)(.+?)($q)\\*\\*');
    final italicFix = RegExp('(?<!\\*)\\*($q)(.+?)($q)\\*(?!\\*)');
    return content
        .replaceAllMapped(boldFix, (m) => '${m[1]}**${m[2]}**${m[3]}')
        .replaceAllMapped(italicFix, (m) => '${m[1]}*${m[2]}*${m[3]}');
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
