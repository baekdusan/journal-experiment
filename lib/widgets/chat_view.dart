import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/experiment_config.dart';
import '../models/chat_session.dart';
import '../providers/chat_provider.dart';
import '../providers/learning_state_provider.dart';
import '../models/instructional_design.dart' as id;
import '../models/learner_profile.dart';
import '../models/learning_state.dart';
import '../models/resource_cache.dart';
import 'message_bubble.dart';
import 'chat_input.dart';

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

class _ChatViewState extends ConsumerState<ChatView> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 메시지 목록을 최하단으로 애니메이션 스크롤한다.
  ///
  /// 새 메시지가 추가되거나 스트리밍 중일 때 호출되어
  /// 사용자가 항상 최신 메시지를 볼 수 있도록 한다.
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final learningState = ref.watch(learningStateProvider);

    // activeSessionProvider 변경을 감지하여 자동 스크롤을 트리거한다.
    // 스크롤 트리거 조건:
    // 1. 세션이 처음 로드됨 (previous == null)
    // 2. 새 메시지가 추가됨 (메시지 개수 증가)
    // 3. 스트리밍이 완료됨 (isStreaming: true → false 전환)
    // addPostFrameCallback을 사용하여 프레임 렌더링 완료 후 스크롤을 실행한다.
    ref.listen(activeSessionProvider, (previous, next) {
      if (next == null) return;

      final shouldScroll = previous == null ||
          // 새 메시지 추가
          next.messages.length > previous.messages.length ||
          // 스트리밍 완료 (청크 수신 중에는 스크롤 안 함)
          (previous.messages.isNotEmpty &&
              next.messages.isNotEmpty &&
              previous.messages.last.isStreaming &&
              !next.messages.last.isStreaming);

      if (shouldScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    // 타이핑 인디케이터가 나타나면 하단으로 스크롤하여 보이게 한다.
    ref.listen(isProcessingProvider, (previous, next) {
      if (next == true && previous != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Column(
      children: [
        if (ExperimentConfig.showLearningRoadmap &&
            learningState.instructionalDesign.syllabus.isNotEmpty)
          _buildSyllabusHeader(context, learningState),
        _buildStatusBanner(context, learningState),
        Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: session == null || session.messages.isEmpty
                ? _buildWelcome(context)
                : _buildMessageList(session),
          ),
        ),
        const ChatInput(),
      ],
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
    final resourceCache = learningState.resourceCache;

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
                      // 적용된 교수설계론 섹션
                      if (resourceCache.instructionalTheories.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildTheorySectionWithSources(
                          theme,
                          resourceCache.instructionalTheories,
                        ),
                      ],
                      // 참고 자료 섹션
                      if (resourceCache.learningResources.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(theme, Icons.link, '참고 자료'),
                        const SizedBox(height: 12),
                        ...resourceCache.learningResources.map((resource) =>
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildResourceCard(theme, resource),
                            )),
                      ],
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

  Widget _buildTheoryCard(ThemeData theme, InstructionalTheory theory) {
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
          Icons.menu_book_outlined,
          color: cs.onSurface,
          size: 20,
        ),
        title: Text(
          theory.theoryName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theory.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                if (theory.applicability.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            theory.applicability,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTheorySectionWithSources(
    ThemeData theme,
    List<InstructionalTheory> theories,
  ) {
    // 모든 rawChunks 수집 (중복 제거)
    final allChunks = <SourceChunk>[];
    for (final theory in theories) {
      if (theory.rawChunks != null) {
        allChunks.addAll(theory.rawChunks!);
      }
    }

    // 중복 제거 (같은 페이지, 같은 내용)
    final uniqueChunks = <SourceChunk>[];
    for (final chunk in allChunks) {
      if (!uniqueChunks.any((c) =>
          c.pageNumber == chunk.pageNumber && c.content == chunk.content)) {
        uniqueChunks.add(chunk);
      }
    }

    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Icon(Icons.psychology_outlined, size: 18, color: cs.onSurface),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '적용된 교수설계론',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // theory 카드들 (원문 보기 제외)
        ...theories.map((theory) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTheoryCard(theme, theory),
            )),
        // 통합 원문 보기 ExpansionTile
        if (uniqueChunks.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              shape: const Border(),
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Icon(
                Icons.description_outlined,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              title: Text(
                '원문 보기',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'RAG 검색 결과 ${uniqueChunks.length}개',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              children: uniqueChunks
                  .map((chunk) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildSourceChunkCard(theme, chunk),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSourceChunkCard(ThemeData theme, SourceChunk chunk) {
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 14,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'p.${chunk.pageNumber}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (chunk.sectionHeader != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chunk.sectionHeader!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            chunk.content,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(ThemeData theme, LearningResource resource) {
    final cs = theme.colorScheme;
    final iconData = _getResourceIcon(resource.resourceType);
    final typeLabel = _getResourceTypeLabel(resource.resourceType);
    final hasUrl = resource.url.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                iconData,
                color: cs.onSurface,
                size: 20,
              ),
            ),
            title: Text(
              resource.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            trailing: hasUrl
                ? IconButton(
                    icon: Icon(
                      Icons.open_in_new,
                      size: 20,
                      color: cs.onSurface,
                    ),
                    tooltip: '원문 보기',
                    onPressed: () => _launchUrl(resource.url),
                  )
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  if (hasUrl) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _launchUrl(resource.url),
                      child: Text(
                        resource.url,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurface,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  IconData _getResourceIcon(String resourceType) {
    switch (resourceType) {
      case 'wikidata_concept':
        return Icons.public;
      case 'openstax_chapter':
        return Icons.book;
      case 'openstax_exercise':
        return Icons.quiz;
      default:
        return Icons.article;
    }
  }

  String _getResourceTypeLabel(String resourceType) {
    switch (resourceType) {
      case 'wikidata_concept':
        return 'Wikidata';
      case 'openstax_chapter':
        return 'OpenStax 교재';
      case 'openstax_exercise':
        return 'OpenStax 연습문제';
      default:
        return '참고자료';
    }
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

  Widget _buildWelcome(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '무엇을 도와드릴까요?',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 18),
      itemCount: session.messages.length + (showTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= session.messages.length) {
          return Center(
            key: const ValueKey('typing-indicator'),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: const _TypingIndicator(),
            ),
          );
        }
        final message = session.messages[index];
        return Center(
          key: ValueKey(message.id),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: MessageBubble(message: message),
          ),
        );
      },
    );
  }
}

/// 비스트리밍 응답을 준비하는 동안 채팅창에 표시하는 타이핑 인디케이터.
///
/// ChatGPT/Gemini처럼 점 3개가 순차적으로 깜빡이며 "답변 준비 중"임을 알린다.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: cs.onSurface,
              child: Icon(Icons.auto_awesome, size: 14, color: cs.surface),
            ),
            const SizedBox(width: 12),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    // 각 점을 시차를 두고 깜빡이게 한다.
                    final t = (_controller.value - i * 0.2) % 1.0;
                    final opacity = 0.3 + 0.7 * (1 - (t * 2 - 1).abs()).clamp(0.0, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: cs.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
