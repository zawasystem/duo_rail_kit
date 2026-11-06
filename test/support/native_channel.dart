import 'package:duo_rail_kit/duo_rail_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns [answer] from the mocked native query and records the requested methods.
List<Object?> answerGetEdge(WidgetTester tester, Object? Function() answer) {
  final calls = <Object?>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, (call) async {
    calls.add(call.method);
    return answer();
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(VerticalBarEdge.channel, null));
  return calls;
}

/// Delivers a simulated native edgeChanged event.
Future<void> pushFromNative(WidgetTester tester, Object? value) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    VerticalBarEdge.channel.name,
    VerticalBarEdge.channel.codec.encodeMethodCall(MethodCall('edgeChanged', value)),
    (_) {},
  );
  await tester.pump();
}
