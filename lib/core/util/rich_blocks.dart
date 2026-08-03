/// 마크다운 ↔ 블록 문서(JSON) 변환
///
/// 회의록 본문은 서버가 **블록 배열**(`Meeting.blocks`)로 들고 있다.
/// 문단·제목·목록이 중첩된 트리라 마크다운 한 덩어리인 앱 모델과 모양이 다르다.
/// 앱 에디터([BlockEditor])는 마크다운으로 적고 읽으므로 여기서 옮긴다.
///
/// 다루는 것은 **앱 에디터가 만들 수 있는 것들**이다 — 제목(1~3) · 문단 ·
/// 글머리·번호·체크박스 목록 · 인용 · 코드블록, 그리고 굵게·기울임·코드·취소선.
/// 그 밖의 블록은 글자만 뽑아 문단으로 읽는다 (읽히기는 해야 하므로).
library;

// ── 마크다운 → 블록 ──

final _fence = RegExp(r'^\s*```');
final _heading = RegExp(r'^(#{1,3})\s+(.*)$');
final _checkbox = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s*(.*)$');
final _bullet = RegExp(r'^\s*[-*]\s+(.*)$');
final _ordered = RegExp(r'^\s*\d+\.\s+(.*)$');

/// 앱 본문(마크다운) → 서버가 받는 블록 배열
List<Map<String, dynamic>> blocksFromMarkdown(String source) {
  final blocks = <Map<String, dynamic>>[];
  final lines = source.split('\n');

  // 같은 종류의 목록·인용이 이어지면 한 블록으로 묶는다
  String? group;
  var items = <Map<String, dynamic>>[];

  void flush() {
    if (group == null || items.isEmpty) {
      group = null;
      items = [];
      return;
    }
    blocks.add({'type': group!, 'content': items});
    group = null;
    items = [];
  }

  void push(String type, Map<String, dynamic> item) {
    if (group != type) flush();
    group = type;
    items.add(item);
  }

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];

    // 코드블록 — 닫는 울타리까지 원문 그대로 담는다
    if (_fence.hasMatch(line)) {
      flush();
      final code = <String>[];
      i++;
      while (i < lines.length && !_fence.hasMatch(lines[i])) {
        code.add(lines[i]);
        i++;
      }
      blocks.add({
        'type': 'codeBlock',
        'content': [
          {'type': 'text', 'text': code.join('\n')},
        ],
      });
      continue;
    }

    if (line.trim().isEmpty) {
      flush();
      continue;
    }

    final heading = _heading.firstMatch(line);
    if (heading != null) {
      flush();
      blocks.add({
        'type': 'heading',
        'attrs': {'level': heading.group(1)!.length},
        'content': _inlineToJson(heading.group(2)!),
      });
      continue;
    }

    // 체크박스가 글머리보다 먼저다 — `- [ ]` 도 `- ` 로 시작하기 때문
    final checkbox = _checkbox.firstMatch(line);
    if (checkbox != null) {
      push('taskList', {
        'type': 'taskItem',
        'attrs': {'checked': checkbox.group(1)!.toLowerCase() == 'x'},
        'content': [_paragraph(checkbox.group(2)!)],
      });
      continue;
    }

    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      push('bulletList', {
        'type': 'listItem',
        'content': [_paragraph(bullet.group(1)!)],
      });
      continue;
    }

    final ordered = _ordered.firstMatch(line);
    if (ordered != null) {
      push('orderedList', {
        'type': 'listItem',
        'content': [_paragraph(ordered.group(1)!)],
      });
      continue;
    }

    if (line.trimLeft().startsWith('> ')) {
      push('blockquote', _paragraph(line.trimLeft().substring(2)));
      continue;
    }

    flush();
    blocks.add(_paragraph(line));
  }

  flush();
  return blocks;
}

Map<String, dynamic> _paragraph(String text) => {
  'type': 'paragraph',
  'content': _inlineToJson(text),
};

/// `**굵게**` `*기울임*` `` `코드` `` `~~취소~~` 를 마크로 옮긴다
final _inline = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`([^`]+)`|~~(.+?)~~');

const _markOf = {1: 'bold', 2: 'italic', 3: 'code', 4: 'strike'};

List<Map<String, dynamic>> _inlineToJson(String text) {
  if (text.isEmpty) return const [];
  final nodes = <Map<String, dynamic>>[];
  var cursor = 0;

  void plain(String value) {
    if (value.isNotEmpty) nodes.add({'type': 'text', 'text': value});
  }

  for (final match in _inline.allMatches(text)) {
    plain(text.substring(cursor, match.start));
    for (final group in _markOf.keys) {
      final value = match.group(group);
      if (value == null) continue;
      nodes.add({
        'type': 'text',
        'text': value,
        'marks': [
          {'type': _markOf[group]},
        ],
      });
      break;
    }
    cursor = match.end;
  }
  plain(text.substring(cursor));
  return nodes;
}

// ── 블록 → 마크다운 ──

/// 서버 블록 배열 → 앱 본문(마크다운)
String markdownFromBlocks(List<dynamic> blocks) {
  final lines = <String>[];
  for (final block in blocks) {
    if (block is! Map) continue;
    _writeBlock(block.cast<String, dynamic>(), lines);
  }
  // 블록 사이에 넣은 빈 줄이 끝에 남는다
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

void _writeBlock(Map<String, dynamic> block, List<String> lines) {
  final content = block['content'];
  final children = content is List ? content : const [];

  switch (block['type']) {
    case 'heading':
      final attrs = block['attrs'];
      final level = attrs is Map ? (attrs['level'] as int? ?? 2) : 2;
      lines.add('${'#' * level.clamp(1, 3)} ${_inlineToText(children)}');
      lines.add('');
    case 'bulletList':
      for (final item in children) {
        lines.add('- ${_flatText(item)}');
      }
      lines.add('');
    case 'orderedList':
      for (var i = 0; i < children.length; i++) {
        lines.add('${i + 1}. ${_flatText(children[i])}');
      }
      lines.add('');
    case 'taskList':
      for (final item in children) {
        final attrs = item is Map ? item['attrs'] : null;
        final checked = attrs is Map && attrs['checked'] == true;
        lines.add('- [${checked ? 'x' : ' '}] ${_flatText(item)}');
      }
      lines.add('');
    case 'blockquote':
      for (final item in children) {
        lines.add('> ${_flatText(item)}');
      }
      lines.add('');
    case 'codeBlock':
      lines.add('```');
      lines.addAll(_inlineToText(children).split('\n'));
      lines.add('```');
      lines.add('');
    default:
      // 문단과 모르는 블록 — 글자만 뽑는다
      final text = _inlineToText(children);
      if (text.isNotEmpty) lines.add(text);
      lines.add('');
  }
}

/// 한 줄짜리 자리(목록 칸·인용)의 글자를 뽑는다
///
/// 안에 문단이 한 겹 더 들어 있기도 하고(`listItem` > `paragraph`)
/// 문단이 바로 오기도 한다(`blockquote` > `paragraph`). 둘 다 받는다.
/// 문단이 여러 개면 한 줄로 붙인다 — 목록 한 칸이 여러 줄이면 마크다운이 깨진다.
String _flatText(dynamic node) {
  if (node is! Map) return '';
  final text = node['text'];
  if (text is String) return text;

  final content = node['content'];
  if (content is! List) return '';
  // 글자 노드가 바로 들어 있으면 인라인이다 (문단·제목) — 여기서 마크를 살린다
  if (content.any((child) => child is Map && child['text'] is String)) {
    return _inlineToText(content);
  }
  return [
    for (final child in content) _flatText(child),
  ].where((s) => s.isNotEmpty).join(' ');
}

const _wrapOf = {'bold': '**', 'italic': '*', 'code': '`', 'strike': '~~'};

String _inlineToText(List<dynamic> nodes) {
  final buffer = StringBuffer();
  for (final node in nodes) {
    if (node is! Map) continue;
    // 인라인이 또 감싸여 있으면 (link 등) 안쪽 글자를 꺼낸다
    final text = node['text'] as String?;
    if (text == null) {
      final inner = node['content'];
      if (inner is List) buffer.write(_inlineToText(inner));
      continue;
    }
    final marks = node['marks'];
    var wrapped = text;
    if (marks is List) {
      for (final mark in marks) {
        final wrap = mark is Map ? _wrapOf[mark['type']] : null;
        if (wrap != null) wrapped = '$wrap$wrapped$wrap';
      }
    }
    buffer.write(wrapped);
  }
  return buffer.toString();
}
