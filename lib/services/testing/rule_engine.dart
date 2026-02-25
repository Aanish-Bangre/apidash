import 'package:apidash_core/apidash_core.dart';
import '../../models/request_model.dart';
import '../../models/test_case_model.dart';
import '../../utils/utils.dart';

/// Generates deterministic test cases from a RequestModel.
/// No AI, no network — just request mutations.
class RuleEngine {
  static List<TestCase> generateCases(RequestModel requestModel) {
    return switch (requestModel.apiType) {
      APIType.rest => _restCases(requestModel.httpRequestModel!),
      APIType.graphql => _graphqlCases(requestModel.httpRequestModel!),
      APIType.ai => [],
    };
  }

  // REST test variations
  static List<TestCase> _restCases(HttpRequestModel base) {
    final cases = <TestCase>[];

    // Baseline: original request, expect 2xx
    cases.add(TestCase(
      id: getNewUuid(),
      scenarioName: 'Baseline (valid request)',
      request: base,
      expectation: const TestExpectation(
        expectedStatusCodes: [200, 201, 202, 204],
      ),
    ));

    // Missing auth → expect 401/403
    if (base.authModel?.type != APIAuthType.none) {
      cases.add(TestCase(
        id: getNewUuid(),
        scenarioName: 'Missing authentication',
        request: base.copyWith(
          authModel: const AuthModel(type: APIAuthType.none),
        ),
        expectation: const TestExpectation(
          expectedStatusCodes: [401, 403],
        ),
      ));
    }

    // Empty body → expect client error
    if (base.hasBody) {
      cases.add(TestCase(
        id: getNewUuid(),
        scenarioName: 'Empty request body',
        request: base.copyWith(body: ''),
        expectation: const TestExpectation(
          expectedStatusCodes: [400, 422, 415],
        ),
      ));
    }

    // Malformed JSON → expect 400/422
    if (base.hasJsonContentType) {
      cases.add(TestCase(
        id: getNewUuid(),
        scenarioName: 'Malformed JSON body',
        request: base.copyWith(body: '{ "broken": >>>invalid<<<< }'),
        expectation: const TestExpectation(
          expectedStatusCodes: [400, 422],
        ),
      ));
    }

    // Remove query params → expect validation error
    if (base.enabledParams?.isNotEmpty ?? false) {
      cases.add(TestCase(
        id: getNewUuid(),
        scenarioName: 'Missing query parameters',
        request: base.copyWith(
          params: [],
          isParamEnabledList: [],
        ),
        expectation: const TestExpectation(
          expectedStatusCodes: [400, 422],
        ),
      ));
    }

    return cases;
  }

  // GraphQL test variations
  static List<TestCase> _graphqlCases(HttpRequestModel base) {
    final cases = <TestCase>[];

    // Baseline: 200 and no "errors"
    cases.add(TestCase(
      id: getNewUuid(),
      scenarioName: 'Baseline (valid GraphQL query)',
      request: base,
      expectation: const TestExpectation(
        expectedStatusCodes: [200],
        bodyMustNotContain: '"errors"',
      ),
    ));

    // Broken query → expect errors in body
    cases.add(TestCase(
      id: getNewUuid(),
      scenarioName: 'Malformed GraphQL query',
      request: base.copyWith(query: '{ broken >>> }'),
      expectation: const TestExpectation(
        expectedStatusCodes: [200, 400],
        bodyMustContain: '"errors"',
      ),
    ));

    // Empty query → expect 400
    cases.add(TestCase(
      id: getNewUuid(),
      scenarioName: 'Empty GraphQL query',
      request: base.copyWith(query: ''),
      expectation: const TestExpectation(
        expectedStatusCodes: [400],
      ),
    ));

    // Missing auth → expect 401/403
    if (base.authModel?.type != APIAuthType.none) {
      cases.add(TestCase(
        id: getNewUuid(),
        scenarioName: 'Missing authentication',
        request: base.copyWith(
          authModel: const AuthModel(type: APIAuthType.none),
        ),
        expectation: const TestExpectation(
          expectedStatusCodes: [401, 403],
        ),
      ));
    }

    return cases;
  }
}