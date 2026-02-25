import '../../models/test_case_model.dart';
import '../../models/test_result_model.dart';

/// Evaluates a test case against the actual HTTP outcome.
class TestEvaluator {
  static TestResult evaluate(
    TestCase testCase, {
    int? statusCode,
    String? body,
    Duration? duration,
    String? error,
  }) {
    // Network / execution error
    if (error != null) {
      return TestResult(
        testCase: testCase,
        status: TestStatus.error,
        failureReason: error,
      );
    }

    // Should not happen unless execution layer misbehaved
    if (statusCode == null) {
      return TestResult(
        testCase: testCase,
        status: TestStatus.error,
        failureReason:
            'No status code received — possible execution layer issue',
      );
    }

    // Status code validation
    if (!testCase.expectation.expectedStatusCodes.contains(statusCode)) {
      return TestResult(
        testCase: testCase,
        status: TestStatus.failed,
        actualStatusCode: statusCode,
        actualResponseTime: duration,
        responseBody: body,
        failureReason:
            'Expected one of '
            '${testCase.expectation.expectedStatusCodes.join(", ")}, '
            'got $statusCode',
      );
    }

    final bodyStr = body?.trim() ?? '';

    // Required body content (GraphQL error cases)
    final mustContain = testCase.expectation.bodyMustContain;
    if (mustContain != null && !bodyStr.contains(mustContain)) {
      return TestResult(
        testCase: testCase,
        status: TestStatus.failed,
        actualStatusCode: statusCode,
        actualResponseTime: duration,
        responseBody: body,
        failureReason:
            'Expected body to contain "$mustContain" but it did not',
      );
    }

    // Forbidden body content (GraphQL baseline)
    final mustNotContain = testCase.expectation.bodyMustNotContain;
    if (mustNotContain != null && bodyStr.contains(mustNotContain)) {
      return TestResult(
        testCase: testCase,
        status: TestStatus.failed,
        actualStatusCode: statusCode,
        actualResponseTime: duration,
        responseBody: body,
        failureReason:
            'Expected body NOT to contain "$mustNotContain" but it did',
      );
    }

    // Performance threshold
    final maxTime = testCase.expectation.maxResponseTime;
    if (maxTime != null) {
      if (duration == null) {
        return TestResult(
          testCase: testCase,
          status: TestStatus.failed,
          actualStatusCode: statusCode,
          responseBody: body,
          failureReason:
              'Response time unavailable — cannot verify performance threshold',
        );
      }
      if (duration > maxTime) {
        return TestResult(
          testCase: testCase,
          status: TestStatus.failed,
          actualStatusCode: statusCode,
          actualResponseTime: duration,
          responseBody: body,
          failureReason:
              'Response time ${duration.inMilliseconds}ms exceeded '
              'threshold of ${maxTime.inMilliseconds}ms',
        );
      }
    }

    // Passed
    return TestResult(
      testCase: testCase,
      status: TestStatus.passed,
      actualStatusCode: statusCode,
      actualResponseTime: duration,
      responseBody: body,
    );
  }
}