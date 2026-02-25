import 'package:apidash_core/apidash_core.dart';

/// What we expect from a test case execution.
class TestExpectation {
  // Valid HTTP status codes for this scenario (e.g. [200, 201] or [400, 422])
  final List<int> expectedStatusCodes;

  // Optional performance limit
  final Duration? maxResponseTime;

  // For GraphQL: body must contain this string (e.g. '"errors"')
  final String? bodyMustContain;

  // For GraphQL: body must NOT contain this string
  final String? bodyMustNotContain;

  const TestExpectation({
    required this.expectedStatusCodes,
    this.maxResponseTime,
    this.bodyMustContain,
    this.bodyMustNotContain,
  });
}

/// A single mutated request + its expected outcome.
class TestCase {
  final String id; // UUID
  final String scenarioName; // e.g. "Missing authentication"
  final HttpRequestModel request; // Mutated request to execute
  final TestExpectation expectation;

  const TestCase({
    required this.id,
    required this.scenarioName,
    required this.request,
    required this.expectation,
  });
}