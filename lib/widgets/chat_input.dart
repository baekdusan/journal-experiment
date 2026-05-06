import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/learning_state_provider.dart';

/// 사용자가 메시지를 입력하고 전송할 수 있는 입력 영역 위젯.
///
/// 최신 ChatGPT 5.x 톤 — 큰 라운드 카드, 미묘한 섀도우, 검정 원형 전송 버튼.
class ChatInput extends StatefulWidget {
  const ChatInput({super.key});

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 입력된 텍스트를 검증하고 메시지를 전송한다.
  ///
  /// 공백만 있는 경우 무시하고, 유효한 텍스트가 있으면
  /// [ChatController.sendMessage]를 호출한 뒤 입력 필드를 초기화한다.
  void _submit(WidgetRef ref) {
    if (!mounted) return;
    if (_controller.value.composing.isValid) return;
    final isDesigning = ref.read(learningStateProvider).isDesigning;
    final isProcessing = ref.read(isProcessingProvider);
    if (isDesigning || isProcessing) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatControllerProvider.notifier).sendMessage(text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.clear();
      if (_focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      color: cs.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Consumer(
              builder: (context, ref, child) {
                final isDesigning = ref
                    .watch(learningStateProvider)
                    .isDesigning;
                final isProcessing = ref.watch(isProcessingProvider);
                final blocked = isDesigning || isProcessing;
                final hasText = _controller.text.trim().isNotEmpty;
                final canSend = !blocked && hasText;

                return Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Focus(
                            onKeyEvent: (node, event) {
                              if (event is! KeyDownEvent) {
                                return KeyEventResult.ignored;
                              }
                              if (event.logicalKey !=
                                  LogicalKeyboardKey.enter) {
                                return KeyEventResult.ignored;
                              }
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                return KeyEventResult.ignored;
                              }
                              if (_controller.value.composing.isValid) {
                                return KeyEventResult.ignored;
                              }
                              if (!blocked) {
                                _submit(ref);
                              }
                              return KeyEventResult.handled;
                            },
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              maxLines: 6,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: cs.onSurface,
                                fontSize: 16,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: '메시지를 입력하세요',
                                hintStyle: theme.textTheme.bodyLarge?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                isCollapsed: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SendButton(
                        enabled: canSend,
                        onPressed: () => _submit(ref),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 최신 ChatGPT 스타일의 검정 원형 전송 버튼.
class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _SendButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = enabled ? cs.primary : cs.outlineVariant;
    final fg = enabled ? cs.onPrimary : cs.onSurfaceVariant;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 20,
            color: fg,
          ),
        ),
      ),
    );
  }
}
