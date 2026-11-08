import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/shared/utils/external_links.dart';

/// Opens [url] -- a link the server sent, to the website -- on the app's
/// own screen for it when the app has one ([webLocation]: a ticket, a
/// request, the missing-answers page...), else in the browser: our own site
/// inside the app, anything else outside it. Completes when the screen it
/// opened is closed again (at once for the browser).
Future<void> openSiteLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || url.trim().isEmpty) return;
  final location = webLocation(uri);
  if (location != null) {
    await context.push<Object?>(location);
    return;
  }
  if (!uri.hasScheme) return;
  await (isOwnSite(uri) ? openInAppThenBrowser(uri) : openExternally(uri));
}
