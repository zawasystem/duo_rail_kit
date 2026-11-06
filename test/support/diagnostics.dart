import 'package:duo_rail_kit/src/toolbar/vertical_bar_toolbar.dart' show VerticalBarShellDebugStats;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expects no paint-phase fix and no exception: how every shell test ends.
void expectClean(WidgetTester tester) {
  expect(VerticalBarShellDebugStats.paintFixes, 0);
  expect(tester.takeException(), isNull);
}

/// Runs [body] and returns the `VerticalBarShell: ` notes printed meanwhile.
Future<List<String>> notesDuring(Future<void> Function() body) async {
  final notes = <String>[];
  final previous = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null && message.startsWith('VerticalBarShell: ')) {
      notes.add(message);
    } else {
      previous(message, wrapWidth: wrapWidth);
    }
  };
  try {
    await body();
  } finally {
    debugPrint = previous;
  }
  return notes;
}

/// Runs [body] and returns the errors Flutter reported meanwhile, which then do not fail the test.
Future<List<FlutterErrorDetails>> collectErrors(Future<void> Function() body) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}
