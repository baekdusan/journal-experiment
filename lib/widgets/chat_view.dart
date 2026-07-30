import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/experiment_config.dart';
import '../models/chat_session.dart';
import '../models/message.dart';
import '../providers/chat_provider.dart';
import '../providers/learning_state_provider.dart';
import '../providers/streaming_message_provider.dart';
import '../models/instructional_design.dart' as id;
import '../models/learner_profile.dart';
import '../models/learning_state.dart';
import 'message_bubble.dart';
import 'chat_input.dart';
import 'typing_indicator.dart';

/// 현재 활성화된 채팅 세션의 메시지 목록과 입력 영역을 렌더링하는 메인 뷰 위젯.
///
/// [activeSessionProvider]를 구독하여 메시지가 변경될 때마다 UI를 업데이트한다.
/// 세션이 없거나 메시지가 비어있으면 환영 화면을 표시하고,
/// 그렇지 않으면 [MessageBubble] 리스트와 [ChatInput]을 표시한다.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key});

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

/// 답변을 따라 내려가지 않는 스크롤 모델(Gemini 웹 앱과 동일).
///
/// - 질문을 보내면 그 말풍선을 **화면 맨 위**로 올린다. 이전 대화는 위로 밀린다.
/// - 스트리밍 중에는 자동으로 따라 내려가지 **않는다**. 읽는 위치를 빼앗지 않는다.
/// - 아래에 아직 읽지 않은 내용이 남아 있으면 입력창 위에 "맨 아래로" 화살표를 띄운다.
class _ChatViewState extends ConsumerState<ChatView> {
  final _scrollController = ScrollController();

  /// 마지막 턴을 화면 맨 위까지 끌어올릴 수 있도록 리스트 끝에 확보하는 여백.
  ///
  /// 질문을 보낸 직후에는 그 아래에 내용이 거의 없어, 끝까지 스크롤해도 말풍선이
  /// 맨 위로 오지 않는다. 부족한 만큼만 확보하고 답변이 길어지면 회수한다.
  double _extraBottom = 0;

  /// 화면 맨 위에 고정한 사용자 메시지. 여백 회수 계산의 기준점이다.
  String? _pinnedMessageId;

  /// 메시지별 GlobalKey. 말풍선의 실제 위치를 재기 위해 필요하다.
  final _messageKeys = <String, GlobalKey>{};

  bool _showJumpToBottom = false;

  /// 고정 시 말풍선 위에 남기는 숨 쉴 틈.
  static const _pinTopInset = 12.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateJumpButton);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateJumpButton);
    _scrollController.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) =>
      _messageKeys.putIfAbsent(id, () => GlobalKey());

  /// 확보 여백을 제외한 '실제 내용'이 화면 아래로 얼마나 남았는지.
  ///
  /// [_extraBottom]까지 바닥으로 세면 빈 여백만 남았을 때도 화살표가 떠서,
  /// 내려가도 볼 것이 없는 버튼이 된다.
  double _contentBelowFold() {
    if (!_scrollController.hasClients) return 0;
    final position = _scrollController.position;
    return (position.maxScrollExtent - _extraBottom) - position.pixels;
  }

  void _updateJumpButton() {
    final show = _contentBelowFold() > 120;
    if (show != _showJumpToBottom && mounted) {
      setState(() => _showJumpToBottom = show);
    }
  }

  /// 실제 내용의 끝으로 스크롤한다(확보 여백 안쪽까지는 내려가지 않는다).
  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    _scrollTo(_scrollController.position.maxScrollExtent - _extraBottom,
        animate: animate);
  }

  void _scrollTo(double offset, {bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target =
        offset.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  /// [messageId] 말풍선의 위쪽 끝을 뷰포트 맨 위에 맞추는 스크롤 오프셋.
  double? _offsetToPin(String messageId) {
    final context = _messageKeys[messageId]?.currentContext;
    if (context == null || !_scrollController.hasClients) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    // ensureVisible과 같은 계산. alignment 0 = 대상의 위쪽을 뷰포트 위쪽에 맞춤.
    final reveal = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0);
    return reveal.offset - _pinTopInset;
  }

  /// 질문 말풍선을 화면 맨 위로 올린다. 필요하면 아래 여백을 먼저 확보한다.
  ///
  /// [retry]는 내부 재시도 방지용이다. 말풍선이 아직 화면 밖이면 ListView가
  /// 그것을 빌드하지 않아 위치를 잴 수 없으므로(GlobalKey에 context 없음),
  /// 바닥으로 붙여 레이아웃시킨 다음 프레임에 한 번 다시 시도한다.
  void _pinToTop(String messageId, {int retry = 0}) {
    if (_messageKeys[messageId]?.currentContext == null) {
      if (retry >= 2) return;
      _scrollToBottom(animate: false);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _pinToTop(messageId, retry: retry + 1),
      );
      return;
    }

    final target = _offsetToPin(messageId);
    if (target == null) return;
    final shortfall =
        target - (_scrollController.position.maxScrollExtent - _extraBottom);
    final needed = shortfall > 0 ? shortfall : 0.0;

    if ((needed - _extraBottom).abs() > 1) {
      // 여백이 반영된 레이아웃이 나온 다음 프레임에 스크롤해야 목표까지 간다.
      setState(() => _extraBottom = needed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollTo(target);
        _updateJumpButton();
      });
      return;
    }
    _scrollTo(target);
    _updateJumpButton();
  }

  /// 답변이 길어져 필요 없어진 여백을 회수한다(바닥의 빈 공간 제거).
  void _shrinkExtraBottom() {
    if (_extraBottom == 0 || _pinnedMessageId == null) return;
    final target = _offsetToPin(_pinnedMessageId!);
    if (target == null) return;
    final shortfall =
        target - (_scrollController.position.maxScrollExtent - _extraBottom);
    final needed = shortfall > 0 ? shortfall : 0.0;
    if ((needed - _extraBottom).abs() > 1 && mounted) {
      setState(() => _extraBottom = needed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final learningState = ref.watch(learningStateProvider);

    // 세션 변화에 따른 스크롤 처리.
    // addPostFrameCallback을 쓰는 이유는 새 말풍선이 레이아웃된 뒤에야
    // 위치를 잴 수 있기 때문이다.
    ref.listen(activeSessionProvider, (previous, next) {
      if (next == null) return;

      // 세션 최초 로드: 마지막 대화가 보이도록 바닥에 붙인다.
      if (previous == null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToBottom(animate: false),
        );
        return;
      }

      final added = next.messages.length > previous.messages.length;

      // 새 질문 → 그 말풍선을 화면 맨 위로. 이후 답변은 아래에서 채워진다.
      if (added && next.messages.last.role == MessageRole.user) {
        final id = next.messages.last.id;
        _pinnedMessageId = id;
        WidgetsBinding.instance.addPostFrameCallback((_) => _pinToTop(id));
        return;
      }

      // 스트리밍 종료 → 남는 여백 회수 + 화살표 상태 재계산.
      final streamingEnded = previous.messages.isNotEmpty &&
          next.messages.isNotEmpty &&
          previous.messages.last.isStreaming &&
          !next.messages.last.isStreaming;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (streamingEnded) _shrinkExtraBottom();
        _updateJumpButton();
      });
    });

    // 스트리밍 청크는 따라 내려가지 않는다. 읽던 위치를 빼앗지 않기 위해서다.
    // 대신 아래로 내용이 쌓이면 "맨 아래로" 화살표가 뜨도록 상태만 갱신한다.
    //
    // 청크는 ChatSession이 아니라 streamingMessageProvider에만 누적되므로
    // (streaming_message_provider.dart 참고 — 세션은 완료 시 1회만 갱신된다)
    // 위의 activeSessionProvider 리스너는 청크 도중 호출되지 않는다.
    ref.listen(streamingMessageProvider, (previous, next) {
      if (next == null) return;
      if (previous?.content == next.content) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateJumpButton());
    });

    // Gemini 스타일 레이아웃:
    // - 빈 화면: 라디얼 글로우 배경 + 중앙 인사말 + 중앙 입력 필
    // - 대화 중: 메시지 리스트 + 하단 입력 필 + 디스클레이머
    final isEmpty = session == null || session.messages.isEmpty;

    return Column(
      children: [
        if (ExperimentConfig.showLearningRoadmap) ...[
          if (learningState.instructionalDesign.syllabus.isNotEmpty)
            _buildSyllabusHeader(context, learningState),
          // 상태 배너("로드맵 생성 중/준비 완료")도 로드맵의 존재를 드러내므로
          // 같은 플래그로 묶는다. 설계가 도는 동안에는 타이핑 인디케이터가
          // 대신 떠 있어(양 조건 동일) 피드백이 사라지지는 않는다.
          _buildStatusBanner(context, learningState),
        ],
        Expanded(
          child: isEmpty
              ? _buildWelcome(context)
              : Container(
                  color: Theme.of(context).colorScheme.surface,
                  // "맨 아래로" 화살표는 입력창 바로 위 가운데에 떠 있어야 하므로
                  // 리스트 위에 겹쳐 놓는다.
                  child: Stack(
                    children: [
                      _buildMessageList(session),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Center(child: _buildJumpToBottom(context)),
                      ),
                    ],
                  ),
                ),
        ),
        if (!isEmpty) ...[
          const ChatInput(),
          _buildDisclaimer(context),
        ],
      ],
    );
  }

  /// 읽지 않은 내용이 아래에 남았을 때만 뜨는 "맨 아래로" 원형 버튼.
  Widget _buildJumpToBottom(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      opacity: _showJumpToBottom ? 1 : 0,
      duration: const Duration(milliseconds: 150),
      child: IgnorePointer(
        ignoring: !_showJumpToBottom,
        child: Tooltip(
          message: '맨 아래로',
          child: Material(
            color: cs.surfaceContainerHigh,
            shape: CircleBorder(side: BorderSide(color: cs.outlineVariant)),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _scrollToBottom,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.arrow_downward,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Gemini 스타일 하단 디스클레이머.
  Widget _buildDisclaimer(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      child: Text(
        'AI 튜터는 실수를 할 수 있으니 중요한 정보는 다시 확인하세요.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, LearningState state) {
    if (!state.isDesigning && !state.showDesignReady) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDesigning = state.isDesigning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDesigning)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cs.onSurface,
                  ),
                )
              else
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: cs.onSurface,
                ),
              const SizedBox(width: 8),
              Text(
                isDesigning ? '로드맵 생성 중...' : '로드맵 준비 완료',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyllabusHeader(
    BuildContext context,
    LearningState learningState,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalSteps = learningState.instructionalDesign.syllabus.length;
    final progressLabel = learningState.progressLabel;
    final currentTopic = learningState.currentStep?.topic ?? '-';
    final headerText = learningState.isCourseCompleted
        ? '학습 로드맵 · 완료 ($totalSteps단계)'
        : '학습 로드맵 · $progressLabel단계 · $currentTopic';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 18,
                  color: cs.onSurface,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    headerText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showSyllabusModal(context, learningState),
                  style: TextButton.styleFrom(
                    foregroundColor: cs.onSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.list_alt_outlined, size: 16),
                  label: const Text('목차 보기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSyllabusModal(BuildContext context, LearningState learningState) {
    final design = learningState.instructionalDesign;
    final profile = learningState.learnerProfile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '학습 플랜',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      // 학습 플랜 요약 섹션
                      _buildPlanSummarySection(theme, profile, design),
                      const SizedBox(height: 24),
                      // 로드맵 섹션 헤더
                      _buildSectionHeader(theme, Icons.route, '학습 로드맵'),
                      const SizedBox(height: 12),
                      // 로드맵 리스트 (✓ 완료 / ▶ 현재 / ○ 예정)
                      ...design.syllabus.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final step = entry.value;
                        final isCurrent = !learningState.isCourseCompleted &&
                            idx == learningState.currentStepIndex;
                        final isDone = learningState.isCourseCompleted ||
                            idx < learningState.currentStepIndex;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildStepCard(
                            theme,
                            step,
                            isCurrent: isCurrent,
                            isDone: isDone,
                          ),
                        );
                      }),
                      // 자료는 로컬에 캐시하지 않고 Google Search grounding으로
                      // 호출 시점에 취득하므로, 여기에 별도의 자료 섹션을 두지 않는다.
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.onSurface,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSummarySection(
    ThemeData theme,
    LearnerProfile profile,
    id.InstructionalDesign design,
  ) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: cs.onSurface,
              ),
              const SizedBox(width: 8),
              Text(
                '학습 정보',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(theme, '학습 주제', profile.subject ?? '-'),
          const SizedBox(height: 12),
          _buildInfoRow(theme, '학습 목표', profile.goal ?? '-'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoChip(
                  theme,
                  Icons.trending_up,
                  '수준',
                  _getLevelDisplayName(profile.level),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoChip(
                  theme,
                  Icons.format_list_numbered,
                  '총 단계',
                  '${design.syllabus.length}단계',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurface),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLevelDisplayName(LearnerLevel? level) {
    switch (level) {
      case LearnerLevel.beginner:
        return '초급';
      case LearnerLevel.intermediate:
        return '중급';
      case LearnerLevel.expert:
        return '고급';
      default:
        return '-';
    }
  }

  Widget _buildStepCard(
    ThemeData theme,
    id.Step step, {
    bool isCurrent = false,
    bool isDone = false,
  }) {
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: isCurrent ? cs.surfaceContainerHigh : cs.surface,
        border: Border.all(
          color: isCurrent ? cs.primary : cs.outlineVariant,
          width: isCurrent ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrent ? cs.primary : cs.surfaceContainerHighest,
          foregroundColor: isCurrent ? cs.onPrimary : cs.onSurfaceVariant,
          child: isDone
              ? const Icon(Icons.check, size: 18)
              : Text(
                  '${step.step}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Text(
          step.topic,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.normal,
            color: cs.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            step.objective,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        trailing: isCurrent
            ? Text(
                '진행 중',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }

  /// Gemini 스타일 빈 화면: 라디얼 블루 글로우 위에 인사말과 입력 필을
  /// 세로 중앙 정렬로 배치하고, 페이지 하단에 디스클레이머를 둔다.
  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final glowColor = isDark
        ? const Color(0xFF0842A0).withValues(alpha: 0.25)
        : const Color(0xFFD3E3FD).withValues(alpha: 0.9);

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, 0.05),
          radius: 0.85,
          colors: [glowColor, glowColor.withValues(alpha: 0), ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Column(
        children: [
          const Spacer(flex: 5),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w400,
                color: cs.onSurface,
                letterSpacing: -0.3,
                height: 1.3,
              ),
              children: const [
                TextSpan(text: '개인 '),
                TextSpan(
                  text: 'AI 튜터',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: '와 학습을 시작해 보세요'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const ChatInput(),
          const Spacer(flex: 7),
          _buildDisclaimer(context),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatSession session) {
    // 처리 중이고 마지막 메시지가 스트리밍 중이 아닐 때만 타이핑 인디케이터를 표시한다.
    // (스트리밍 응답은 청크가 직접 버블에 채워지므로 인디케이터가 불필요)
    final isProcessing = ref.watch(isProcessingProvider);
    final lastIsStreaming =
        session.messages.isNotEmpty && session.messages.last.isStreaming;
    final showTyping = isProcessing && !lastIsStreaming;

    // 사라진 메시지의 GlobalKey를 정리한다(세션 초기화 등).
    final liveIds = session.messages.map((m) => m.id).toSet();
    _messageKeys.removeWhere((id, _) => !liveIds.contains(id));

    // 대화 전체를 하나의 선택 영역으로 묶는다. MessageBubble 쪽에서
    // selectable을 끄고 여기서 감싸야 메시지·문단 경계를 넘는 드래그가 된다.
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController,
        // 아래 여백은 마지막 턴을 맨 위까지 올리기 위해 동적으로 확보된다.
        padding: EdgeInsets.only(top: 18, bottom: 18 + _extraBottom),
        itemCount: session.messages.length + (showTyping ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= session.messages.length) {
            return Center(
              key: const ValueKey('typing-indicator'),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: const TypingIndicator(),
              ),
            );
          }
          final message = session.messages[index];
          return Center(
            // 말풍선 위치를 재서 맨 위로 올리려면 GlobalKey가 필요하다.
            key: _keyFor(message.id),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: MessageBubble(message: message),
            ),
          );
        },
      ),
    );
  }
}

