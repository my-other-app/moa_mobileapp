import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';

class NoRegisteredEventPage extends ConsumerWidget {
  const NoRegisteredEventPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 40,
            ),
            Center(
              child: SizedBox(
                height: MediaQuery.of(context).size.height / 4,
                child: Image(image: AssetImage(AssetResources.noevents)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: SizedBox(
                child: Text(
                  'You are not having any upcoming events',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Update bottom nav index to sync UI
                    ref.read(navigationIndexProvider.notifier).state = 0;
                    // Navigate to home page
                    context.go('/');
                  },
                  child: Text('EXPLORE EVENTS'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
