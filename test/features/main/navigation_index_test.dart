import 'package:finnet/features/home/presentation/providers/bottom_nav_provider.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resetting the old provider resets the tab the bar shows', () {
    // Sign-out reset bottomNavIndexProvider while the bar read
    // navigationIndexProvider, so the reset did nothing.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(navigationIndexProvider.notifier).state = 3;

    container.read(bottomNavIndexProvider.notifier).resetToHome();

    expect(container.read(navigationIndexProvider), 0);
  });

  test('they are one provider', () {
    expect(bottomNavIndexProvider, same(navigationIndexProvider));
  });
}
