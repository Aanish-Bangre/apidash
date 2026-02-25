import 'package:flutter/foundation.dart';
import 'package:apidash_core/apidash_core.dart';
import '../../models/request_model.dart';
import '../../models/test_result_model.dart';
import '../../utils/utils.dart';
import 'rule_engine.dart';
import 'test_evaluator.dart';

/// Runs a full deterministic test suite for a RequestModel.
class TestOrchestratorService {
  static Future<List<TestResult>> runSuite(
    RequestModel requestModel, {
    SupportedUriSchemes defaultUriScheme = SupportedUriSchemes.https,
    bool noSSL = false,
    Map<String?, List<EnvironmentVariableModel>> envMap = const {},
    String? activeEnvId,
  }) async {
    if (requestModel.httpRequestModel == null) {
      debugPrint(
        '[TestOrchestrator] No HTTP model for "${requestModel.name}" — skipping.',
      );
      return [];
    }

    final cases = RuleEngine.generateCases(requestModel);
    if (cases.isEmpty) {
      debugPrint(
        '[TestOrchestrator] No test cases generated for "${requestModel.name}".',
      );
      return [];
    }

    debugPrint(
      '[TestOrchestrator] ▶ Starting suite for "${requestModel.name}" '
      '— ${cases.length} case(s)',
    );
    debugPrint('[TestOrchestrator] ${'─' * 60}');

    final results = <TestResult>[];

    for (final testCase in cases) {
      final requestId = getNewUuid();
      debugPrint('[TestOrchestrator]   Running: "${testCase.scenarioName}"');

      try {
        final substituted = substituteHttpRequestModel(
          testCase.request,
          envMap,
          activeEnvId,
        );

        final (response, duration, error) = await sendHttpRequest(
          requestId,
          requestModel.apiType,
          substituted,
          defaultUriScheme: defaultUriScheme,
          noSSL: noSSL,
        );

        final result = TestEvaluator.evaluate(
          testCase,
          statusCode: response?.statusCode,
          body: response?.body,
          duration: duration,
          error: error,
        );

        results.add(result);
        _printResult(result);
      } catch (e) {
        final result = TestEvaluator.evaluate(
          testCase,
          error: 'Unexpected exception: $e',
        );
        results.add(result);
        _printResult(result);
      }
    }

    _printSummary(requestModel.name, results);
    return results;
  }

  static void _printResult(TestResult result) {
    final icon = switch (result.status) {
      TestStatus.passed => '✅',
      TestStatus.failed => '❌',
      TestStatus.error => '⚠️',
    };

    final status = result.actualStatusCode != null
        ? ' [HTTP ${result.actualStatusCode}]'
        : '';
    final time = result.actualResponseTime != null
        ? ' (${result.actualResponseTime!.inMilliseconds}ms)'
        : '';

    debugPrint(
      '[TestOrchestrator]   $icon ${result.testCase.scenarioName}'
      '$status$time',
    );

    if (!result.passed && result.failureReason != null) {
      debugPrint('[TestOrchestrator] ↳ ${result.failureReason}');
    }
  }

  static void _printSummary(String name, List<TestResult> results) {
    final total = results.length;
    final passed = results.where((r) => r.passed).length;
    final failed = results.where((r) => r.failed).length;
    final errored = results.where((r) => r.errored).length;

    debugPrint('[TestOrchestrator] ${'─' * 60}');
    debugPrint('[TestOrchestrator] Suite complete for "$name"');
    debugPrint(
      '[TestOrchestrator]   Total: $total  '
      '✅ Passed: $passed  '
      '❌ Failed: $failed  '
      '⚠️ Errors: $errored',
    );
    debugPrint('[TestOrchestrator] ${'─' * 60}');
  }
}