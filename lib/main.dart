import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:source_maps/source_maps.dart';

void main() {
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends HookWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final initialTraceScrollController = useScrollController();
    final translatedTraceScrollController = useScrollController();
    return Consumer(
      builder: (context, ref, child) => MaterialApp(
        theme: ThemeData.dark(useMaterial3: true)
            .copyWith(scrollbarTheme: ScrollbarThemeData(thumbVisibility: MaterialStateProperty.all(true))),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _Panel(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      labelText: 'Source map path',
                      hintText: 'Path of your source map file',
                    ),
                    onChanged: (value) => ref.read(sourceMapPathProvider.notifier).state = value,
                  ),
                ),
                Expanded(
                  child: MultiSplitView(
                    axis: Axis.horizontal,
                    initialAreas: [
                      Area(weight: 0.5),
                      Area(weight: 0.5),
                    ],
                    children: [
                      _Panel(
                        child: Scrollbar(
                          controller: initialTraceScrollController,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: initialTraceScrollController,
                            child: SizedBox(
                              width: 1000,
                              child: TextFormField(
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: 'Copy your trace here',
                                ),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                                maxLines: null,
                                expands: true,
                                onChanged: (value) => ref.read(traceProvider.notifier).state = value,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Consumer(
                        builder: (context, ref, child) => _Panel(
                          child: Scrollbar(
                            controller: translatedTraceScrollController,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: translatedTraceScrollController,
                              child: SelectableText(
                                ref.watch(resultProvider).valueOrNull ?? 'Empty',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surfaceVariant,
          ),
          padding: const EdgeInsets.all(16.0),
          child: child,
        ),
      );
}

final sourceMapPathProvider = StateProvider((ref) => '');
final traceProvider = StateProvider((ref) => '');

final resultProvider = FutureProvider((ref) async {
  final sourceMapPath = ref.watch(sourceMapPathProvider);
  final fileContent = await File(sourceMapPath).readAsString();
  final json = jsonDecode(fileContent) as Map;
  final parser = parseJson(json);
  final trace = ref.watch(traceProvider);
  final lines = parse(trace, parser);
  return lines.map((line) => line.toString()).join('\n');
});

List<Line> parse(String input, Mapping parser) {
  final textLines = input.split('\n');
  final result = <Line>[];
  for (var textLine in textLines) {
    final regex = RegExp(r':(\d+):(\d+)');
    final match = regex.firstMatch(textLine);
    if (match == null) {
      result.add(Line(sourceLine: textLine));
      continue;
    }
    final matches = (int.tryParse(match.group(1) ?? ''), int.tryParse(match.group(2) ?? ''));
    if (matches case (int line, int column)) {
      final span = parser.spanFor(line - 1, column - 1);
      result.add(Line(sourceLine: textLine, span: span));
    }
  }
  return result;
}

class Line {
  Line({required this.sourceLine, this.span});

  final String sourceLine;
  final SourceMapSpan? span;

  @override
  String toString() => span?.format() ?? sourceLine;
}

extension on SourceMapSpan {
  String format() => 'at $text @ $sourceUrl:${start.line + 1}:${start.column + 1}';
}
