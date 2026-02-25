import 'test_case_model.dart';

/// Execution outcome of a single test case.
enum TestStatus { passed, failed, error }

class TestResult {
  final TestCase testCase;
  final TestStatus status;

  // Present when we received a response
  final int? actualStatusCode;
  final Duration? actualResponseTime;
  final String? responseBody;

  // Present when failed or errored
  final String? failureReason;

  const TestResult({
    required this.testCase,
    required this.status,
    this.actualStatusCode,
    this.actualResponseTime,
    this.failureReason,
    this.responseBody,
  });

  bool get passed => status == TestStatus.passed;
  bool get failed => status == TestStatus.failed;
  bool get errored => status == TestStatus.error;
}