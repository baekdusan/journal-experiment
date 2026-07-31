import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_provider.dart';
import '../providers/learning_state_provider.dart';

/// 사용자가 메시지를 입력하고 전송할 수 있는 입력 영역 위젯.
///
/// Gemini 웹 앱 톤 — 보더 없는 완전 라운드 필(pill), 부드러운 섀도우,
/// 라이트 블루 원형 전송 버튼. 배경은 투명이라 빈 화면의 글로우 위에도 얹힌다.
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
  /// 한글 등 IME 조합 중에도 전송을 막지 않는다.
  ///
  /// `composing.isValid`로 막으면 한글 입력 시 마지막 글자가 조합 상태로 남아
  /// 첫 엔터가 조합 확정에만 쓰이고 버려진다 — 엔터를 두 번 눌러야 전송되는
  /// 원인이었다. [TextEditingController.text]는 조합 중인 글자까지 포함하므로
  /// 이 시점에 전송해도 입력한 문장이 온전히 넘어간다.
  void _submit(WidgetRef ref) {
    if (!mounted) return;
    final isDesigning = ref.read(learningStateProvider).isDesigning;
    final isProcessing = ref.read(isProcessingProvider);
    if (isDesigning || isProcessing) return;

    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatControllerProvider.notifier).sendMessage(text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.clear();
      // 전송 직후에는 대개 isProcessing이 켜져 입력창이 비활성 상태다.
      // 그때는 여기서 포커스를 잡을 수 없으므로 [_refocusIfIdle]이 no-op이 되고,
      // 처리가 끝나는 순간 아래 ref.listen이 포커스를 되돌린다.
      _refocusIfIdle(ref);
    });
  }

  /// 입력이 다시 가능해졌을 때만 입력창에 포커스를 되돌린다.
  ///
  /// 비활성 상태의 [TextField]는 포커스를 받을 수 없어, 다시 활성화된 프레임이
  /// 그려진 뒤에 요청해야 한다. 그래서 post-frame으로 미룬다.
  ///
  /// 단, **학습자가 그 사이 다른 곳으로 포커스를 옮겼다면 뺏지 않는다.**
  /// 대표적인 경우가 응답을 기다리며 이전 답변을 드래그해 두는 것인데,
  /// 여기서 포커스를 가져오면 그 선택이 그대로 지워진다
  /// (chat_view.dart의 SelectionArea가 포커스 기반으로 선택을 유지한다).
  ///
  /// 구분 기준은 실측으로 정했다 — 비활성화로 포커스가 풀리면 라우트의
  /// [FocusScopeNode]만 남고, 학습자가 무언가를 잡으면 그 위젯의 [FocusNode]가
  /// 주 포커스가 된다. 그래서 "스코프뿐일 때"만 되돌린다.
  void _refocusIfIdle(WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final blocked = ref.read(learningStateProvider).isDesigning ||
          ref.read(isProcessingProvider);
      if (blocked) return;

      final holder = FocusManager.instance.primaryFocus;
      final heldElsewhere =
          holder != null && holder is! FocusScopeNode && holder != _focusNode;
      if (heldElsewhere) return;

      if (_focusNode.canRequestFocus) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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

                // 처리가 끝나 입력이 다시 열리는 순간 포커스를 되돌린다.
                // 비활성화되면 TextField가 포커스를 잃기 때문에, 이 전이를 잡지
                // 않으면 학습자가 매 턴 입력창을 다시 클릭해야 한다.
                ref.listen(
                  isProcessingProvider,
                  (_, next) => _refocusIfIdle(ref),
                );
                ref.listen(
                  learningStateProvider.select((s) => s.isDesigning),
                  (_, next) => _refocusIfIdle(ref),
                );

                return Container(
                  padding: const EdgeInsets.fromLTRB(22, 10, 10, 10),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? cs.surfaceContainer
                        : cs.surface,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
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
                              // IME 조합 중(한글 마지막 글자)에도 전송한다.
                              // 자세한 이유는 [_submit] 주석 참고.
                              if (!blocked) {
                                _submit(ref);
                              }
                              return KeyEventResult.handled;
                            },
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              autofocus: true,
                              // 처리 중에는 입력 자체를 막는다. 예전에는 전송만
                              // 막혀서, 응답 생성 중에 친 엔터가 아무 반응 없이
                              // 버려졌다 — 피드백 없는 무시가 가장 나쁘다.
                              enabled: !blocked,
                              maxLines: 6,
                              minLines: 1,
                              keyboardType: TextInputType.multiline,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: cs.onSurface,
                                fontSize: 16,
                                height: 1.4,
                              ),
                              decoration: InputDecoration(
                                hintText: blocked
                                    ? '답변을 준비하는 중이에요'
                                    : '무엇이든 물어보세요',
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

/// Gemini 스타일의 라이트 블루 원형 전송 버튼.
class _SendButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _SendButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = enabled ? cs.secondaryContainer : cs.surfaceContainerHighest;
    final fg = enabled
        ? cs.onSecondaryContainer
        : cs.onSurfaceVariant.withValues(alpha: 0.6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 40,
      height: 40,
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
