import 'package:flutter/widgets.dart';

/// Pages coming and going on the root navigator, for a page that must know
/// when another page covers it and when it is back on top -- My QR, which
/// turns the screen up only while it is the page on show.
///
/// Page routes only: a dialog or a sheet over a page doesn't cover it.
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();
