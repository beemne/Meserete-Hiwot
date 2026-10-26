import 'package:flutter_test/flutter_test.dart';
import 'package:mezmur_zelideta/services/error_reporting_service.dart';
import 'package:mezmur_zelideta/services/file_opening_service.dart';

void main() {
  group('FileOpeningService Unit Tests', () {
    test('sanitizeFilename prevents path traversal and query strings', () {
      expect(
        FileOpeningService.sanitizeFilename('../../etc/passwd'),
        equals('passwd'),
      );
      expect(
        FileOpeningService.sanitizeFilename('..\\..\\windows\\system32\\cmd.exe'),
        equals('cmd.exe'),
      );
      expect(
        FileOpeningService.sanitizeFilename('lesson_guide.pdf?token=secret_12345'),
        equals('lesson_guide.pdf'),
      );
      expect(
        FileOpeningService.sanitizeFilename('bad:name*with?chars<.pdf'),
        equals('bad_name_with_chars_.pdf'),
      );
      expect(
        FileOpeningService.sanitizeFilename('report_final.docx'),
        equals('report_final.docx'),
      );
      expect(
        FileOpeningService.sanitizeFilename('curriculum_data.xlsx'),
        equals('curriculum_data.xlsx'),
      );
      expect(
        FileOpeningService.sanitizeFilename('hymn_audio.mp3?download=1'),
        equals('hymn_audio.mp3'),
      );
      expect(
        FileOpeningService.sanitizeFilename('   '),
        equals('document'),
      );
    });

    test('deriveCacheKey produces stable deterministic hash', () {
      final key1 = FileOpeningService.deriveCacheKey('/edu/materials/15/file');
      final key2 = FileOpeningService.deriveCacheKey('/edu/materials/15/file');
      final key3 = FileOpeningService.deriveCacheKey('/edu/materials/16/file');

      expect(key1, equals(key2));
      expect(key1.length, equals(16));
      expect(key1, isNot(equals(key3)));
    });
  });

  group('ErrorReportingService Unit Tests', () {
    test('sanitize strips JWT tokens, passwords, and secrets', () {
      const input = 'Exception during Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.secret '
          'with body {"password": "mypassword123", "pin": "1234"} and token=secret_token';

      final sanitized = ErrorReportingService.sanitize(input);

      expect(sanitized, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
      expect(sanitized, isNot(contains('mypassword123')));
      expect(sanitized, isNot(contains('secret_token')));
      expect(sanitized, contains('[REDACTED_JWT]'));
      expect(sanitized, contains('[REDACTED]'));
    });

    test('sanitizeEndpoint strips sensitive query strings', () {
      expect(
        ErrorReportingService.sanitizeEndpoint('/api/v1/edu/admin/scores?course_id=5&token=secret'),
        equals('/api/v1/edu/admin/scores'),
      );
      expect(
        ErrorReportingService.sanitizeEndpoint('https://app.hersolan.pro/api/v1/me?token=xyz'),
        equals('/api/v1/me'),
      );
    });

    test('generateReportId formats automated and user IDs correctly', () {
      final errId = ErrorReportingService.generateReportId(isUserReport: false);
      final repId = ErrorReportingService.generateReportId(isUserReport: true);

      expect(errId, startsWith('ERR-'));
      expect(repId, startsWith('REP-'));
      expect(errId.split('-').length, equals(3));
      expect(repId.split('-').length, equals(3));
    });
  });
}
