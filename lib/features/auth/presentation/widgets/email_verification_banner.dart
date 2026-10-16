import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// Whether the verify-your-email banner was closed. For this run of the app
/// only: it comes back on the next launch while the address is unverified.
final emailVerificationBannerDismissedProvider =
    StateProvider<bool>((ref) => false);

/// Opens the verify screen for the signed-in account; it asks for a code on
/// opening.
void openEmailVerification(BuildContext context, String email) {
  context.push('/auth/verify-email', extra: {'email': email});
}

/// "Verify your email to bring in tickets you booked on the website", for
/// an email/password account that has not verified its address. Nothing at
/// all for anyone else, or once closed.
class EmailVerificationBanner extends ConsumerWidget {
  const EmailVerificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).profile;
    final dismissed = ref.watch(emailVerificationBannerDismissedProvider);
    if (profile == null || !profile.needsEmailVerification || dismissed) {
      return const SizedBox.shrink();
    }
    return Container(
      key: const ValueKey('email-verification-banner'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: ShapeDecoration(
        color: AppColors.paleYellow,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.5, color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => openEmailVerification(context, profile.email),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    color: Color(0xFF17A58F)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Verify your email to bring in tickets you booked on the website',
                    style: TextStyle(
                      color: Color(0xFF2C333D),
                      fontSize: 13,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Text(
                  'VERIFY',
                  style: TextStyle(
                    color: Color(0xFF17A58F),
                    fontSize: 18,
                    fontFamily: 'BebasNeue',
                  ),
                ),
                IconButton(
                  key: const ValueKey('email-verification-banner-close'),
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close,
                      size: 18, color: Color(0xFF2C333D)),
                  onPressed: () => ref
                      .read(emailVerificationBannerDismissedProvider.notifier)
                      .state = true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
