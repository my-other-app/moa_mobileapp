import 'package:flutter/material.dart';

class TermsAndConditionPage extends StatelessWidget {
  const TermsAndConditionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Terms and Conditions',
          style: TextStyle(
            fontSize: 24,
            fontFamily: "BebasNeue",
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(
              left: 20.0, right: 10.0, top: 5, bottom: 10),
          child: SizedBox(
            width: 361,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        'Welcome to Myotherapp! These Terms and Conditions ("Terms") govern your access to and use of our mobile application (the "App"). By downloading, installing, or using Myotherapp, you agree to be bound by these Terms. If you do not agree with any part of these Terms, please do not use the App.\n\nOwnership\nMyotherapp is developed and managed by Edwin Emmanuel Roy and Muhammed R ("we," "us," or "our"). While we are not a registered company, we strive to provide a reliable and user-friendly experience through this App.\n\nEligibility\nThere are no specific eligibility requirements to use Myotherapp. The app is open to all users who wish to access its features. However, by using this app, you confirm that you will comply with these Terms and applicable laws while using the app.\n\nUser Responsibilities\nBy using Myotherapp, you agree to:\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        '1. Provide Accurate Information: All users must provide true, complete, and up-to-date information during registration and while using the app. Any false or misleading details may result in disqualification from events, revocation of issued certificates, or suspension from the platform.\n2. Identity Verification for Events: To participate in registered events, users must complete a verification process using a valid government-issued ID. Failure to provide proper verification may result in denial of entry.\n3. Account Security: Users are responsible for maintaining the confidentiality of their login credentials. Any unauthorized access or suspicious activity should be reported immediately.\n4. Compliance with Laws: Users must not engage in fraudulent activities, violate laws, or attempt to misuse the platform in any manner.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'We reserve the right to suspend or terminate accounts that violate these responsibilities.\nPrivacy\nYour privacy is important to us. Please read our Privacy Policy to understand how we collect, use, and protect your information.\n\nPayments & Refunds\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Event Registration Fees\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Myotherapp serves as a platform that facilitates event registrations. Event fees are determined by the event organizers and displayed at the time of checkout.\nIn addition to the event fee, the total amount payable includes:\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Platform Fee – A service fee charged by Myotherapp, which varies between events.\nGateway Fee – A fixed 2% processing fee applied to all transactions.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: '\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Refund Policy\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'No Refunds for User-Initiated Cancellations – Once an event registration is completed, no refunds will be provided if a participant cancels or fails to attend the event.\nRefunds for Event Cancellations – If an event is cancelled by the event organizer, conducting club, or community, the responsibility of issuing refunds lies with the organizing committee. Myotherapp does not process refunds directly but facilitates the refund process initiated by the event organizers.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: '\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Payment Transparency\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'The total amount payable, including all applicable charges, will be clearly displayed during checkout before confirming the payment.\nBy proceeding with payment, users acknowledge and agree to these terms.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: '\nReviews & Feedback\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Posting Reviews\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Users can submit reviews and ratings only if they have attended an event.\nReviews will be visible only to the event host and will not be publicly displayed.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Content Guidelines\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Reviews must be respectful and constructive. Any review containing abusive language, hate speech, or inappropriate content will be deleted.\nHowever, the rating provided with the review will still be considered.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Moderation & Rights\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Myotherapp reserves the right to remove or moderate reviews that violate content guidelines.\nUsers are encouraged to provide honest feedback to help event hosts improve future events.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: '\nLimitations of Liability\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Use of the App at Your Own Risk\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Myotherapp is provided on an "as-is" and "as-available" basis. While we strive to ensure a seamless user experience, we do not guarantee that the app will always be available, error-free, or uninterrupted.\nUsers acknowledge that they use the app at their own risk, and we shall not be liable for any technical issues, data loss, or service interruptions that may occur.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'No Liability for Third-Party Actions\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Myotherapp acts as a platform that facilitates event registrations but does not organize or control the events listed by communities which are not under the direct control of Myotherapp.\nWe are not responsible for the actions, decisions, or policies of event hosts, organizers, or third-party service providers (such as payment gateways).\nAny disputes related to event content, execution, or refunds must be addressed directly with the event organizers.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'No Responsibility for Financial Transactions\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Payments made through Myotherapp involve platform fees and gateway fees, which are clearly displayed at checkout.\nWe do not store or process financial transactions directly; payments are handled through secure third-party payment processors.\nWe are not responsible for any unauthorized transactions, failed payments, or refund disputes.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'No Liability for User Misconduct\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'We do not actively monitor user activity but reserve the right to remove content, suspend accounts, or take necessary action if users violate our terms.\nAny consequences resulting from false information, misuse of the platform, or policy violations are solely the responsibility of the user.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Limitations on Damages\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'To the fullest extent permitted by law, Myotherapp, its creators (Edwin Emmanuel Roy and Muhammed R), and any affiliated parties shall not be liable for:\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Any indirect, incidental, special, or consequential damages, including loss of profits, data, goodwill, or reputation.\nAny damage caused due to service disruptions, technical failures, or cyber threats beyond our control.\nAny claims exceeding the total amount paid by a user for services within the last three (3) months (if applicable).\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Indemnification\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'By using Myotherapp, you agree to indemnify and hold harmless the platform, its creators, employees, and affiliates from any claims, damages, or legal disputes arising from:\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Your violation of these Terms.\nYour participation in events or transactions through the app.\nAny third-party claims related to your use of the platform.\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: 'Exclusions and Jurisdiction\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text:
                        'Some jurisdictions may not allow certain liability exclusions or limitations, so parts of this section may not apply to all users.\nIn such cases, our liability will be limited to the maximum extent permitted by applicable laws.',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
