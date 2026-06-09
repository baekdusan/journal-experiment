// LearningResource: Wikidata/OpenStax에서 가져온 학습 자료
class LearningResource {
  final String title;
  final String url;
  final String summary;
  final String resourceType; // 'wikidata_concept', 'openstax_chapter', 'openstax_exercise'

  LearningResource({
    required this.title,
    required this.url,
    required this.summary,
    required this.resourceType,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'summary': summary,
        'resourceType': resourceType,
      };

  factory LearningResource.fromJson(Map<String, dynamic> json) =>
      LearningResource(
        title: json['title'],
        url: json['url'],
        summary: json['summary'],
        resourceType: json['resourceType'],
      );
}

// SourceChunk: RAG에서 가져온 원본 chunk 메타데이터
class SourceChunk {
  final int pageNumber;
  final String? sectionHeader;
  final String content;

  SourceChunk({
    required this.pageNumber,
    this.sectionHeader,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'pageNumber': pageNumber,
        'sectionHeader': sectionHeader,
        'content': content,
      };

  factory SourceChunk.fromJson(Map<String, dynamic> json) => SourceChunk(
        pageNumber: json['pageNumber'] as int,
        sectionHeader: json['sectionHeader'] as String?,
        content: json['content'] as String,
      );
}

// InstructionalTheory: PDF RAG에서 가져온 교수설계 이론
class InstructionalTheory {
  final String theoryName;
  final String description;
  final String applicability;
  final List<SourceChunk>? rawChunks;

  InstructionalTheory({
    required this.theoryName,
    required this.description,
    required this.applicability,
    this.rawChunks,
  });

  Map<String, dynamic> toJson() => {
        'theoryName': theoryName,
        'description': description,
        'applicability': applicability,
        'rawChunks': rawChunks?.map((c) => c.toJson()).toList(),
      };

  factory InstructionalTheory.fromJson(Map<String, dynamic> json) =>
      InstructionalTheory(
        theoryName: json['theoryName'],
        description: json['description'],
        applicability: json['applicability'],
        rawChunks: (json['rawChunks'] as List?)
            ?.map((c) => SourceChunk.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

// ResourceCache: LearningState의 일부
class ResourceCache {
  final String? subject;
  final String sourceId;
  final List<LearningResource> learningResources;
  final List<InstructionalTheory> instructionalTheories;
  final DateTime? lastFetchedAt;

  ResourceCache({
    this.subject,
    required this.sourceId,
    required this.learningResources,
    required this.instructionalTheories,
    this.lastFetchedAt,
  });

  // 실험 브랜치: 교수이론(instructionalTheories) 미사용.
  // 학습 자료(CBBF)만 준비되면 ready로 판정한다.
  bool get isResourceReady => learningResources.isNotEmpty;

  /// 프롬프트에 삽입할 학습 자료 블록.
  /// 처치군 Tutor와 대조군 free form이 동일 텍스트를 쓰도록 한곳에서 생성한다.
  /// (실험 통제: 양 조건의 자료 제시를 글자 단위로 일치시킴)
  String toPromptBlock() {
    if (!isResourceReady) return '';
    final buffer = StringBuffer();
    buffer.writeln('[학습 자료]');
    buffer.writeln('아래 자료에 근거하여 학습을 진행하라. (영문 자료이나 설명은 한국어로 하라)');
    for (final resource in learningResources) {
      buffer.writeln('## ${resource.title}');
      buffer.writeln(resource.summary);
      if (resource.url.isNotEmpty) {
        buffer.writeln('(출처: ${resource.url})');
      }
    }
    return buffer.toString();
  }

  ResourceCache copyWith({
    String? subject,
    String? sourceId,
    List<LearningResource>? learningResources,
    List<InstructionalTheory>? instructionalTheories,
    DateTime? lastFetchedAt,
  }) =>
      ResourceCache(
        subject: subject ?? this.subject,
        sourceId: sourceId ?? this.sourceId,
        learningResources: learningResources ?? this.learningResources,
        instructionalTheories:
            instructionalTheories ?? this.instructionalTheories,
        lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
      );

  Map<String, dynamic> toJson() => {
        'subject': subject,
        'sourceId': sourceId,
        'learningResources':
            learningResources.map((r) => r.toJson()).toList(),
        'instructionalTheories':
            instructionalTheories.map((t) => t.toJson()).toList(),
        'lastFetchedAt': lastFetchedAt?.toIso8601String(),
      };

  factory ResourceCache.fromJson(Map<String, dynamic> json) => ResourceCache(
        subject: json['subject'],
        sourceId: json['sourceId'] ?? '',
        learningResources: (json['learningResources'] as List?)
                ?.map((r) => LearningResource.fromJson(r))
                .toList() ??
            [],
        instructionalTheories: (json['instructionalTheories'] as List?)
                ?.map((t) => InstructionalTheory.fromJson(t))
                .toList() ??
            [],
        lastFetchedAt: json['lastFetchedAt'] != null
            ? DateTime.parse(json['lastFetchedAt'])
            : null,
      );

  static ResourceCache empty() => ResourceCache(
        sourceId: '',
        learningResources: [],
        instructionalTheories: [],
      );
}
