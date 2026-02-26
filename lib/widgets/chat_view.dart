import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
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

    return Column(
      children: [
        if (learningState.instructionalDesign.syllabus.isNotEmpty)
          _buildSyllabusHeader(context, learningState),
        _buildStatusBanner(context, learningState),
        Expanded(
          child: Container(
            color: const Color(0xFFF7F7F8),
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
    final isDesigning = state.isDesigning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: isDesigning
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.tertiaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: isDesigning
                ? theme.colorScheme.outlineVariant
                : theme.colorScheme.tertiary.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
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
                      color: theme.colorScheme.primary,
                    ),
                  )
                else
                  Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: theme.colorScheme.tertiary,
                  ),
                const SizedBox(width: 8),
                Text(
                  isDesigning ? '로드맵 생성 중...' : '로드맵 준비 완료',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isDesigning
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusHeader(
    BuildContext context,
    LearningState learningState,
  ) {
    final theme = Theme.of(context);
    final totalSteps = learningState.instructionalDesign.syllabus.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
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
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '학습 로드맵 ($totalSteps단계)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _showSyllabusModal(context, learningState),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.list_alt, size: 16),
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
                        Icons.map,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '학습 플랜',
                        style: theme.textTheme.titleLarge,
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
                      // 로드맵 리스트
                      ...design.syllabus.map((step) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildStepCard(theme, step),
                          )),
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
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTheoryCard(ThemeData theme, InstructionalTheory theory) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
          Icons.menu_book,
          color: theme.colorScheme.tertiary,
          size: 20,
        ),
        title: Text(
          theory.theoryName,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
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
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (theory.applicability.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 14,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            theory.applicability,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 헤더
        Row(
          children: [
            Icon(Icons.psychology, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '적용된 교수설계론',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
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
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              leading: Icon(
                Icons.source,
                size: 18,
                color: theme.colorScheme.secondary,
              ),
              title: Text(
                '원문 보기',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'RAG 검색 결과 ${uniqueChunks.length}개',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'p.${chunk.pageNumber}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (chunk.sectionHeader != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    chunk.sectionHeader!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(ThemeData theme, LearningResource resource) {
    final iconData = _getResourceIcon(resource.resourceType);
    final typeLabel = _getResourceTypeLabel(resource.resourceType);
    final hasUrl = resource.url.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                iconData,
                color: theme.colorScheme.secondary,
                size: 20,
              ),
            ),
            title: Text(
              resource.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.secondary,
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
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: '원문 보기',
                    onPressed: () => _launchUrl(resource.url),
                  )
                : null,
          ),
          // 요약 정보
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.summary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (hasUrl) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _launchUrl(resource.url),
                      child: Text(
                        resource.url,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '학습 정보',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
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

  Widget _buildStepCard(ThemeData theme, id.Step step) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          child: Text(
            '${step.step}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          step.topic,
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            step.objective,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '무엇을 도와드릴까요?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D2D2F),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatSession session) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 18),
      itemCount: session.messages.length,
      itemBuilder: (context, index) {
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
