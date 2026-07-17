import 'package:flutter_test/flutter_test.dart';
import 'package:finnet/core/network/dio_client.dart';

void main() {
  group('ApiResult', () {
    test('success folds into onSuccess with the data', () {
      final result = ApiResult<int>.success(42);

      final folded = result.fold(
        onSuccess: (data) => 'got $data',
        onFailure: (error) => 'error: $error',
      );

      expect(folded, 'got 42');
    });

    test('failure folds into onFailure with the error message', () {
      final result = ApiResult<int>.failure('network down');

      final folded = result.fold(
        onSuccess: (data) => 'got $data',
        onFailure: (error) => 'error: $error',
      );

      expect(folded, 'error: network down');
    });
  });
}
