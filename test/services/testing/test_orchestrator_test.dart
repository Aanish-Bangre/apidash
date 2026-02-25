import 'package:flutter_test/flutter_test.dart';
import 'package:apidash_core/apidash_core.dart';
import 'package:apidash/models/request_model.dart';
import 'package:apidash/services/testing/test_orchestrator_service.dart';

// ─── Fixture helpers ─────────────────────────────────────────────────────────

/// A RequestModel with NO httpRequestModel — should short-circuit immediately.
RequestModel _requestWithNoHttpModel() => const RequestModel(
      id: 'no-http-model',
      apiType: APIType.rest,
      name: 'Incomplete Request',
      // httpRequestModel intentionally omitted
    );

/// An AI-type request — RuleEngine produces no cases for APIType.ai,
/// so runSuite returns early without making any network calls.
RequestModel _aiRequest() => const RequestModel(
      id: 'ai-request',
      apiType: APIType.ai,
      name: 'AI Request',
      httpRequestModel: HttpRequestModel(
        method: HTTPVerb.post,
        url: 'https://ai.example.com',
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('TestOrchestratorService', () {
    // ── Early-exit paths (no network calls) ──────────────────────────────────

    group('early exits — no network calls made', () {
      test('returns empty list when httpRequestModel is null', () async {
        final results = await TestOrchestratorService.runSuite(
          _requestWithNoHttpModel(),
        );
        expect(results, isEmpty);
      });

      test('does not throw when httpRequestModel is null', () async {
        expect(
          () => TestOrchestratorService.runSuite(_requestWithNoHttpModel()),
          returnsNormally,
        );
      });

      test('returns empty list for APIType.ai (RuleEngine generates no cases)',
          () async {
        final results = await TestOrchestratorService.runSuite(
          _aiRequest(),
        );
        expect(results, isEmpty);
      });

      test('does not throw for APIType.ai', () async {
        expect(
          () => TestOrchestratorService.runSuite(_aiRequest()),
          returnsNormally,
        );
      });
    });

    // ── Parameter defaults ────────────────────────────────────────────────────

    group('parameter defaults', () {
      test('runSuite accepts call with only requestModel (all params defaulted)',
          () async {
        // Should compile and run without explicit parameters.
        // Uses null httpRequestModel → early exit with no network call.
        final results = await TestOrchestratorService.runSuite(
          _requestWithNoHttpModel(),
        );
        expect(results, isA<List>());
      });

      test('runSuite accepts envMap and activeEnvId without error', () async {
        final results = await TestOrchestratorService.runSuite(
          _requestWithNoHttpModel(),
          defaultUriScheme: SupportedUriSchemes.https,
          noSSL: false,
          envMap: const {},
          activeEnvId: null,
        );
        expect(results, isEmpty);
      });

      test('runSuite accepts noSSL: true without error', () async {
        final results = await TestOrchestratorService.runSuite(
          _requestWithNoHttpModel(),
          noSSL: true,
        );
        expect(results, isEmpty);
      });

      test('runSuite accepts http scheme without error', () async {
        final results = await TestOrchestratorService.runSuite(
          _requestWithNoHttpModel(),
          defaultUriScheme: SupportedUriSchemes.http,
        );
        expect(results, isEmpty);
      });
    });

    // ── Return type contract ──────────────────────────────────────────────────

    group('return type contract', () {
      test('always returns a List (never throws, never returns null)', () async {
        final result1 = await TestOrchestratorService.runSuite(
          _requestWithNoHttpModel(),
        );
        final result2 = await TestOrchestratorService.runSuite(
          _aiRequest(),
        );
        expect(result1, isA<List>());
        expect(result2, isA<List>());
      });
    });
  });
}
