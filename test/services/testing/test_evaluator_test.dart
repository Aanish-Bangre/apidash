import 'package:flutter_test/flutter_test.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:apidash/models/test_case_model.dart';
import 'package:apidash/models/test_result_model.dart';
import 'package:apidash/services/testing/test_evaluator.dart';

// ─── Fixture helpers ─────────────────────────────────────────────────────────

/// Minimal [TestCase] for a REST endpoint expecting 200.
TestCase _makeCase({
  List<int> expectedStatusCodes = const [200],
  Duration? maxResponseTime,
  String? bodyMustContain,
  String? bodyMustNotContain,
  String scenarioName = 'Test Scenario',
}) =>
    TestCase(
      id: 'eval-test-id',
      scenarioName: scenarioName,
      request: const HttpRequestModel(
        method: HTTPVerb.get,
        url: 'https://example.com/api',
      ),
      expectation: TestExpectation(
        expectedStatusCodes: expectedStatusCodes,
        maxResponseTime: maxResponseTime,
        bodyMustContain: bodyMustContain,
        bodyMustNotContain: bodyMustNotContain,
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('TestEvaluator', () {
    // ── Step 1: Network / exception error ─────────────────────────────────────
    group('Step 1 — network error', () {
      test('returns TestStatus.error when error is non-null', () {
        final result = TestEvaluator.evaluate(
          _makeCase(),
          error: 'SocketException: Connection refused',
        );
        expect(result.status, TestStatus.error);
      });

      test('populates failureReason from the error string', () {
        const errorMsg = 'Connection timeout';
        final result = TestEvaluator.evaluate(
          _makeCase(),
          error: errorMsg,
        );
        expect(result.failureReason, errorMsg);
      });

      test('does not set actualStatusCode when errored', () {
        final result = TestEvaluator.evaluate(
          _makeCase(),
          error: 'timeout',
        );
        expect(result.actualStatusCode, isNull);
      });
    });

    // ── Step 2: Null status code ──────────────────────────────────────────────
    group('Step 2 — null status code (no error string)', () {
      test('returns TestStatus.error when statusCode is null and error is null',
          () {
        final result = TestEvaluator.evaluate(
          _makeCase(),
          // statusCode intentionally omitted → null
          // error intentionally omitted → null
        );
        expect(result.status, TestStatus.error);
      });

      test('null statusCode produces an explanatory failureReason', () {
        final result = TestEvaluator.evaluate(_makeCase());
        expect(result.failureReason, isNotEmpty);
        expect(result.failureReason, contains('No status code'));
      });
    });

    // ── Step 3: Status code mismatch ──────────────────────────────────────────
    group('Step 3 — status code check', () {
      test('returns TestStatus.failed when status code is not expected', () {
        final result = TestEvaluator.evaluate(
          _makeCase(expectedStatusCodes: [200, 201]),
          statusCode: 500,
        );
        expect(result.status, TestStatus.failed);
      });

      test('failure reason contains the actual status code', () {
        final result = TestEvaluator.evaluate(
          _makeCase(expectedStatusCodes: [200]),
          statusCode: 404,
        );
        expect(result.failureReason, contains('404'));
      });

      test('failure reason lists all expected codes joined with ", "', () {
        final result = TestEvaluator.evaluate(
          _makeCase(expectedStatusCodes: [400, 422]),
          statusCode: 200,
        );
        expect(result.failureReason, contains('400, 422'));
      });

      test('passes when actual code is in the expected list', () {
        final result = TestEvaluator.evaluate(
          _makeCase(expectedStatusCodes: [200, 201]),
          statusCode: 201,
        );
        // Should not fail on status code — may still pass or fail on later checks
        expect(result.status, isNot(equals(TestStatus.error)));
        // For a case with no other constraints, expect passed
        expect(result.status, TestStatus.passed);
      });

      test('records actualStatusCode in the result', () {
        final result = TestEvaluator.evaluate(
          _makeCase(expectedStatusCodes: [200]),
          statusCode: 400,
        );
        expect(result.actualStatusCode, 400);
      });
    });

    // ── Step 4: bodyMustContain ───────────────────────────────────────────────
    group('Step 4 — bodyMustContain check', () {
      test('fails when body does not contain the required substring', () {
        final result = TestEvaluator.evaluate(
          _makeCase(
            expectedStatusCodes: [200],
            bodyMustContain: '"errors"',
          ),
          statusCode: 200,
          body: '{"data":{"users":[]}}',
        );
        expect(result.status, TestStatus.failed);
      });

      test('failure reason mentions the missing substring', () {
        final result = TestEvaluator.evaluate(
          _makeCase(bodyMustContain: '"errors"'),
          statusCode: 200,
          body: '{"data":"ok"}',
        );
        expect(result.failureReason, contains('"errors"'));
      });

      test('passes when body contains the required substring', () {
        final result = TestEvaluator.evaluate(
          _makeCase(
            expectedStatusCodes: [200],
            bodyMustContain: '"errors"',
          ),
          statusCode: 200,
          body: '{"errors":[{"message":"not found"}]}',
        );
        expect(result.status, TestStatus.passed);
      });

      test('handles whitespace in body via trim()', () {
        final result = TestEvaluator.evaluate(
          _makeCase(bodyMustContain: 'hello'),
          statusCode: 200,
          body: '   hello world   ',
        );
        expect(result.status, TestStatus.passed);
      });

      test('treats null body as empty string for containment check', () {
        final result = TestEvaluator.evaluate(
          _makeCase(bodyMustContain: '"errors"'),
          statusCode: 200,
          body: null,
        );
        expect(result.status, TestStatus.failed);
      });
    });

    // ── Step 5: bodyMustNotContain ────────────────────────────────────────────
    group('Step 5 — bodyMustNotContain check', () {
      test('fails when body contains the forbidden substring', () {
        final result = TestEvaluator.evaluate(
          _makeCase(
            expectedStatusCodes: [200],
            bodyMustNotContain: '"errors"',
          ),
          statusCode: 200,
          body: '{"errors":[{"message":"unexpected"}]}',
        );
        expect(result.status, TestStatus.failed);
      });

      test('passes when body does not contain the forbidden substring', () {
        final result = TestEvaluator.evaluate(
          _makeCase(
            expectedStatusCodes: [200],
            bodyMustNotContain: '"errors"',
          ),
          statusCode: 200,
          body: '{"data":{"users":[{"id":1}]}}',
        );
        expect(result.status, TestStatus.passed);
      });

      test('failure reason mentions the forbidden substring', () {
        final result = TestEvaluator.evaluate(
          _makeCase(bodyMustNotContain: '"errors"'),
          statusCode: 200,
          body: '{"errors":[]}',
        );
        expect(result.failureReason, contains('"errors"'));
      });

      test('treats null body as empty string for exclusion check', () {
        // null body doesn't contain anything — should pass
        final result = TestEvaluator.evaluate(
          _makeCase(bodyMustNotContain: '"errors"'),
          statusCode: 200,
          body: null,
        );
        expect(result.status, TestStatus.passed);
      });
    });

    // ── Step 6: Performance threshold ────────────────────────────────────────
    group('Step 6 — performance threshold', () {
      test('fails when response time exceeds the threshold', () {
        final result = TestEvaluator.evaluate(
          _makeCase(maxResponseTime: const Duration(milliseconds: 500)),
          statusCode: 200,
          duration: const Duration(milliseconds: 800),
        );
        expect(result.status, TestStatus.failed);
      });

      test('failure reason contains actual and threshold milliseconds', () {
        final result = TestEvaluator.evaluate(
          _makeCase(maxResponseTime: const Duration(milliseconds: 500)),
          statusCode: 200,
          duration: const Duration(milliseconds: 800),
        );
        expect(result.failureReason, contains('800ms'));
        expect(result.failureReason, contains('500ms'));
      });

      test('passes when response time is within the threshold', () {
        final result = TestEvaluator.evaluate(
          _makeCase(maxResponseTime: const Duration(milliseconds: 500)),
          statusCode: 200,
          duration: const Duration(milliseconds: 300),
        );
        expect(result.status, TestStatus.passed);
      });

      test('passes when response time equals the threshold exactly', () {
        final result = TestEvaluator.evaluate(
          _makeCase(maxResponseTime: const Duration(milliseconds: 500)),
          statusCode: 200,
          duration: const Duration(milliseconds: 500),
        );
        expect(result.status, TestStatus.passed);
      });

      test('fails with explanation when duration is unavailable', () {
        final result = TestEvaluator.evaluate(
          _makeCase(maxResponseTime: const Duration(milliseconds: 500)),
          statusCode: 200,
          // duration intentionally omitted → null
        );
        expect(result.status, TestStatus.failed);
        expect(result.failureReason, contains('unavailable'));
      });

      test('does not check performance when maxResponseTime is null', () {
        // No maxResponseTime, slow duration — should still pass
        final result = TestEvaluator.evaluate(
          _makeCase(), // no maxResponseTime
          statusCode: 200,
          duration: const Duration(seconds: 60),
        );
        expect(result.status, TestStatus.passed);
      });
    });

    // ── Happy path ────────────────────────────────────────────────────────────
    group('happy path', () {
      test('returns TestStatus.passed when all checks pass', () {
        final result = TestEvaluator.evaluate(
          _makeCase(
            expectedStatusCodes: [200],
            bodyMustContain: '"data"',
            bodyMustNotContain: '"errors"',
            maxResponseTime: const Duration(milliseconds: 1000),
          ),
          statusCode: 200,
          body: '{"data":{"id":42}}',
          duration: const Duration(milliseconds: 150),
        );
        expect(result.status, TestStatus.passed);
      });

      test('passed result has null failureReason', () {
        final result = TestEvaluator.evaluate(
          _makeCase(),
          statusCode: 200,
        );
        expect(result.failureReason, isNull);
      });

      test('passed result stores actualStatusCode', () {
        final result = TestEvaluator.evaluate(
          _makeCase(),
          statusCode: 200,
        );
        expect(result.actualStatusCode, 200);
      });

      test('passed result stores actualResponseTime', () {
        final result = TestEvaluator.evaluate(
          _makeCase(),
          statusCode: 200,
          duration: const Duration(milliseconds: 42),
        );
        expect(result.actualResponseTime, const Duration(milliseconds: 42));
      });

      test('passed result stores responseBody', () {
        final result = TestEvaluator.evaluate(
          _makeCase(),
          statusCode: 200,
          body: '{"ok":true}',
        );
        expect(result.responseBody, '{"ok":true}');
      });
    });

    // ── Convenience getters ───────────────────────────────────────────────────
    group('TestResult convenience getters', () {
      test('passed getter is true for passed result', () {
        final result = TestEvaluator.evaluate(_makeCase(), statusCode: 200);
        expect(result.passed, isTrue);
        expect(result.failed, isFalse);
        expect(result.errored, isFalse);
      });

      test('failed getter is true for failed result', () {
        final result = TestEvaluator.evaluate(
          _makeCase(expectedStatusCodes: [200]),
          statusCode: 404,
        );
        expect(result.failed, isTrue);
        expect(result.passed, isFalse);
        expect(result.errored, isFalse);
      });

      test('errored getter is true for error result', () {
        final result = TestEvaluator.evaluate(
          _makeCase(),
          error: 'Network unreachable',
        );
        expect(result.errored, isTrue);
        expect(result.passed, isFalse);
        expect(result.failed, isFalse);
      });
    });
  });
}
