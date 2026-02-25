import 'package:flutter_test/flutter_test.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:apidash/models/request_model.dart';
import 'package:apidash/services/testing/rule_engine.dart';

// ─── Fixture helpers ─────────────────────────────────────────────────────────
// Minimal RequestModel builders so every test clearly states what it configures.

/// A basic REST GET request with no auth, no body, no params.
RequestModel _restRequest({
  HttpRequestModel? httpRequestModel,
}) =>
    RequestModel(
      id: 'test-id',
      apiType: APIType.rest,
      name: 'Test Request',
      httpRequestModel: httpRequestModel ??
          const HttpRequestModel(
            method: HTTPVerb.get,
            url: 'https://example.com/api',
          ),
    );

/// REST POST request with Bearer auth and a JSON body.
RequestModel _restRequestWithAuthAndBody() => RequestModel(
      id: 'test-auth-id',
      apiType: APIType.rest,
      name: 'Auth Request',
      httpRequestModel: const HttpRequestModel(
        method: HTTPVerb.post,
        url: 'https://example.com/api/resource',
        authModel: AuthModel(
          type: APIAuthType.bearer,
          bearer: AuthBearerModel(token: 'secret-token'),
        ),
        bodyContentType: ContentType.json,
        body: '{"name":"test"}',
      ),
    );

/// REST GET request with two enabled query parameters.
RequestModel _restRequestWithParams() => RequestModel(
      id: 'test-params-id',
      apiType: APIType.rest,
      name: 'Params Request',
      httpRequestModel: HttpRequestModel(
        method: HTTPVerb.get,
        url: 'https://example.com/api/search',
        params: const [
          NameValueModel(name: 'q', value: 'flutter'),
          NameValueModel(name: 'page', value: '1'),
        ],
        isParamEnabledList: const [true, true],
      ),
    );

/// GraphQL request with a valid query.
RequestModel _graphqlRequest() => RequestModel(
      id: 'test-gql-id',
      apiType: APIType.graphql,
      name: 'GraphQL Request',
      httpRequestModel: const HttpRequestModel(
        method: HTTPVerb.post,
        url: 'https://api.example.com/graphql',
        query: '{ users { id name } }',
      ),
    );

/// AI type request — not supported for HTTP-level testing.
RequestModel _aiRequest() => RequestModel(
      id: 'test-ai-id',
      apiType: APIType.ai,
      name: 'AI Request',
      httpRequestModel: const HttpRequestModel(
        method: HTTPVerb.post,
        url: 'https://ai.example.com',
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('RuleEngine', () {
    // ── Null / empty guard ────────────────────────────────────────────────────
    group('null / empty guards', () {
      test('returns empty list when httpRequestModel is null', () {
        final request = RequestModel(
          id: 'no-http-model',
          apiType: APIType.rest,
          name: 'No HTTP Model',
          // httpRequestModel intentionally omitted
        );
        expect(RuleEngine.generateCases(request), isEmpty);
      });

      test('returns empty list for APIType.ai', () {
        final cases = RuleEngine.generateCases(_aiRequest());
        expect(cases, isEmpty);
      });
    });

    // ── REST rules ────────────────────────────────────────────────────────────
    group('REST rules', () {
      test('always generates a Baseline case', () {
        final cases = RuleEngine.generateCases(_restRequest());
        final baseline = cases.where(
          (c) => c.scenarioName.contains('Baseline'),
        );
        expect(baseline, hasLength(1));
      });

      test(
          'generates "Missing authentication" when request has auth configured',
          () {
        final cases = RuleEngine.generateCases(_restRequestWithAuthAndBody());
        final authCase = cases.where(
          (c) => c.scenarioName == 'Missing authentication',
        );
        expect(authCase, hasLength(1));
      });

      test(
          'the "Missing authentication" case uses APIAuthType.none as auth',
          () {
        final cases = RuleEngine.generateCases(_restRequestWithAuthAndBody());
        final authCase = cases.firstWhere(
          (c) => c.scenarioName == 'Missing authentication',
        );
        expect(authCase.request.authModel?.type, APIAuthType.none);
      });

      test(
          '"Missing authentication" expects 401 or 403',
          () {
        final cases = RuleEngine.generateCases(_restRequestWithAuthAndBody());
        final authCase = cases.firstWhere(
          (c) => c.scenarioName == 'Missing authentication',
        );
        expect(authCase.expectation.expectedStatusCodes, containsAll([401, 403]));
      });

      test('does NOT generate "Missing authentication" when request has no auth',
          () {
        final cases = RuleEngine.generateCases(_restRequest());
        final authCases = cases.where(
          (c) => c.scenarioName == 'Missing authentication',
        );
        expect(authCases, isEmpty);
      });

      test('generates "Empty request body" case when request has a body', () {
        final cases = RuleEngine.generateCases(_restRequestWithAuthAndBody());
        final bodyCase = cases.where(
          (c) => c.scenarioName == 'Empty request body',
        );
        expect(bodyCase, hasLength(1));
      });

      test('does NOT generate "Empty request body" when request has no body',
          () {
        // GET with no body content type JSON but no actual body — hasBody = false
        final cases = RuleEngine.generateCases(_restRequest());
        final bodyCases = cases.where(
          (c) => c.scenarioName == 'Empty request body',
        );
        expect(bodyCases, isEmpty);
      });

      test('generates "Malformed JSON body" for JSON content type', () {
        final cases = RuleEngine.generateCases(_restRequestWithAuthAndBody());
        final jsonCase = cases.where(
          (c) => c.scenarioName == 'Malformed JSON body',
        );
        expect(jsonCase, hasLength(1));
      });

      test('generates "Missing query parameters" when params are present', () {
        final cases = RuleEngine.generateCases(_restRequestWithParams());
        final paramCase = cases.where(
          (c) => c.scenarioName == 'Missing query parameters',
        );
        expect(paramCase, hasLength(1));
      });

      test(
          '"Missing query parameters" case sends empty params list',
          () {
        final cases = RuleEngine.generateCases(_restRequestWithParams());
        final paramCase = cases.firstWhere(
          (c) => c.scenarioName == 'Missing query parameters',
        );
        expect(paramCase.request.params, isEmpty);
      });

      test('does NOT generate "Missing query parameters" when no params exist',
          () {
        final cases = RuleEngine.generateCases(_restRequest());
        final paramCases = cases.where(
          (c) => c.scenarioName == 'Missing query parameters',
        );
        expect(paramCases, isEmpty);
      });

      test('each case has a unique non-empty ID', () {
        final cases = RuleEngine.generateCases(_restRequestWithAuthAndBody());
        final ids = cases.map((c) => c.id).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: 'all IDs must be unique');
        for (final id in ids) {
          expect(id, isNotEmpty);
        }
      });

      test('Baseline case is a defensive copy, not the same object', () {
        final base = const HttpRequestModel(
          method: HTTPVerb.get,
          url: 'https://example.com',
        );
        final request = _restRequest(httpRequestModel: base);
        final cases = RuleEngine.generateCases(request);
        final baseline = cases.first;
        // copyWith produces a value-equal but distinct object
        expect(identical(baseline.request, base), isFalse);
        expect(baseline.request.url, base.url);
      });
    });

    // ── GraphQL rules ─────────────────────────────────────────────────────────
    group('GraphQL rules', () {
      test('generates exactly 4 cases for a valid GraphQL request', () {
        final cases = RuleEngine.generateCases(_graphqlRequest());
        expect(cases, hasLength(4));
      });

      test('generates a baseline GraphQL case', () {
        final cases = RuleEngine.generateCases(_graphqlRequest());
        final baseline = cases.where(
          (c) => c.scenarioName.contains('Baseline'),
        );
        expect(baseline, hasLength(1));
      });

      test('GraphQL baseline bodyMustNotContain is set to "errors" key', () {
        final cases = RuleEngine.generateCases(_graphqlRequest());
        final baseline = cases.firstWhere(
          (c) => c.scenarioName.contains('Baseline'),
        );
        expect(baseline.expectation.bodyMustNotContain, '"errors"');
      });

      test('generates "Malformed GraphQL query" case', () {
        final cases = RuleEngine.generateCases(_graphqlRequest());
        final malformed = cases.where(
          (c) => c.scenarioName == 'Malformed GraphQL query',
        );
        expect(malformed, hasLength(1));
      });

      test('"Malformed GraphQL query" bodyMustContain is "errors"', () {
        final cases = RuleEngine.generateCases(_graphqlRequest());
        final malformed = cases.firstWhere(
          (c) => c.scenarioName == 'Malformed GraphQL query',
        );
        expect(malformed.expectation.bodyMustContain, '"errors"');
      });

      test('generates "Empty GraphQL query" case', () {
        final cases = RuleEngine.generateCases(_graphqlRequest());
        final empty = cases.where(
          (c) => c.scenarioName == 'Empty GraphQL query',
        );
        expect(empty, hasLength(1));
      });

      test('"Empty GraphQL query" sends an empty query string', () {
        final cases = RuleEngine.generateCases(_graphqlRequest());
        final emptyCase = cases.firstWhere(
          (c) => c.scenarioName == 'Empty GraphQL query',
        );
        expect(emptyCase.request.query, isEmpty);
      });

      test('generates GraphQL "Missing authentication" when auth is set', () {
        final gqlWithAuth = RequestModel(
          id: 'gql-auth',
          apiType: APIType.graphql,
          name: 'GQL Auth',
          httpRequestModel: const HttpRequestModel(
            method: HTTPVerb.post,
            url: 'https://api.example.com/graphql',
            query: '{ users { id } }',
            authModel: AuthModel(type: APIAuthType.bearer, bearer: AuthBearerModel(token: 'tok')),
          ),
        );
        final cases = RuleEngine.generateCases(gqlWithAuth);
        final authCase = cases.where(
          (c) => c.scenarioName == 'Missing authentication',
        );
        expect(authCase, hasLength(1));
      });
    });
  });
}
