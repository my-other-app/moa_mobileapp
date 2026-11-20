import 'package:flutter/material.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/motion.dart';
import 'package:finnet/shared/widgets/app_spinner.dart';

/// Pull to refresh in the app's look: a round white badge slides down with
/// the finger, its ring filling as the pull nears the point of release; it
/// turns pale yellow once a release will refresh, and spins while
/// [onRefresh] runs.
///
/// The pull itself is Material's [RefreshIndicator] (its no-spinner form):
/// the same distance to arm it, the same edge rule, the same `show()`, the
/// same scroll physics. Only what is drawn is the app's. Takes what a
/// [RefreshIndicator] takes, so it drops in where one was.
class AppRefresh extends StatefulWidget {
  const AppRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.displacement = 40.0,
    this.edgeOffset = 0.0,
    this.color,
    this.backgroundColor,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.semanticsLabel,
    this.semanticsValue,
    this.strokeWidth,
    this.triggerMode = RefreshIndicatorTriggerMode.onEdge,
    this.elevation = 2.0,
  });

  final RefreshCallback onRefresh;
  final Widget child;

  /// How far below the top (past [edgeOffset]) the badge rests while it
  /// spins.
  final double displacement;

  /// Where the top is: below a header drawn over the list.
  final double edgeOffset;

  /// The spinner's ink; [AppColors.ink] when null.
  final Color? color;

  /// The badge's fill before it is armed; white when null.
  final Color? backgroundColor;
  final ScrollNotificationPredicate notificationPredicate;
  final String? semanticsLabel;
  final String? semanticsValue;
  final double? strokeWidth;
  final RefreshIndicatorTriggerMode triggerMode;

  /// Accepted for a [RefreshIndicator]'s callers; the badge has its own
  /// soft shadow.
  final double elevation;

  /// The badge, across.
  static const badgeSize = 40.0;

  /// The badge, for tests.
  static const badgeKey = ValueKey('app-refresh-badge');

  @override
  State<AppRefresh> createState() => AppRefreshState();
}

/// Public so a caller can [show] it, as with [RefreshIndicatorState].
class AppRefreshState extends State<AppRefresh> {
  final _indicator = GlobalKey<RefreshIndicatorState>();
  RefreshIndicatorStatus? _status;

  /// How far the list has been pulled past its top, while a finger is on
  /// it.
  double _pull = 0;
  bool _tracking = false;

  /// The pull that arms a release: [RefreshIndicator]'s own (a quarter of
  /// the viewport, over its 1.5 limit), known once a scroll is seen.
  double _armAt = 100;

  /// What [RefreshIndicatorState.show] does: spins and runs [onRefresh].
  Future<void> show({bool atTop = true}) =>
      _indicator.currentState?.show(atTop: atTop) ?? Future<void>.value();

  RefreshIndicatorStatus? get status => _status;

  bool _onScroll(ScrollNotification n) {
    if (!widget.notificationPredicate(n)) return false;
    final metrics = n.metrics;
    if (metrics.axis != Axis.vertical) return false;
    _armAt = metrics.viewportDimension * 0.25 / 1.5;
    var pull = _pull;
    if (n is ScrollStartNotification) {
      _tracking = n.dragDetails != null && metrics.extentBefore == 0;
      pull = 0;
    } else if (!_tracking) {
      return false;
    } else if (n is OverscrollNotification) {
      // Clamping physics: the list stays put and reports what it refused.
      pull -= n.overscroll;
    } else if (n is ScrollUpdateNotification) {
      // Bouncing physics: the list itself comes down past its top.
      pull = metrics.pixels < metrics.minScrollExtent
          ? metrics.minScrollExtent - metrics.pixels
          : pull - (n.scrollDelta ?? 0);
      if (n.dragDetails == null && metrics.pixels >= metrics.minScrollExtent) {
        pull = 0;
      }
    } else if (n is ScrollEndNotification) {
      _tracking = false;
      pull = 0;
    }
    pull = pull.clamp(0.0, double.infinity);
    if (pull != _pull) setState(() => _pull = pull);
    return false;
  }

  /// No badge in the tree: nothing pulled, or its fade-out over (so a
  /// screen at rest has no spinner in it, hidden or not).
  bool _gone = true;

  void _onStatus(RefreshIndicatorStatus? status) {
    if (!mounted) return;
    setState(() {
      _status = status;
      final ending = status == null ||
          status == RefreshIndicatorStatus.done ||
          status == RefreshIndicatorStatus.canceled;
      if (!ending) _gone = false;
      // A pull let go before the mark just goes; a refresh fades out.
      if (ending &&
          (status != RefreshIndicatorStatus.done || reduceMotion(context))) {
        _gone = true;
      }
      if (status == RefreshIndicatorStatus.snap ||
          status == RefreshIndicatorStatus.refresh) {
        _tracking = false;
      }
    });
  }

  void _faded() {
    final status = _status;
    if (!mounted ||
        !(status == null ||
            status == RefreshIndicatorStatus.done ||
            status == RefreshIndicatorStatus.canceled)) {
      return;
    }
    setState(() => _gone = true);
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final pulling = status == RefreshIndicatorStatus.drag ||
        status == RefreshIndicatorStatus.armed;
    final busy = status == RefreshIndicatorStatus.snap ||
        status == RefreshIndicatorStatus.refresh;
    final armed = status == RefreshIndicatorStatus.armed || busy;
    final progress =
        _armAt <= 0 ? 0.0 : (_pull / _armAt).clamp(0.0, 1.0).toDouble();
    const size = AppRefresh.badgeSize;

    // Hidden above the top until pulled; following the finger (slower than
    // it) while pulled; resting at [displacement] while it spins.
    final double top;
    final double opacity;
    if (busy) {
      top = widget.displacement;
      opacity = 1;
    } else if (pulling) {
      top = -size + (_pull * 0.5).clamp(0.0, widget.displacement + size);
      opacity = progress;
    } else {
      top = -size;
      opacity = 0;
    }
    final quick = pulling && !reduceMotion(context);
    final ink = widget.color ?? AppColors.ink;
    final fill =
        armed ? AppColors.paleYellow : (widget.backgroundColor ?? Colors.white);

    final badge = Container(
      key: AppRefresh.badgeKey,
      width: size,
      height: size,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.border.withValues(alpha: 0.12), width: 0.5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: AppSpinner(
        color: ink,
        strokeWidth: widget.strokeWidth ?? 2.5,
        // Filling as the pull goes on; turning once released.
        value: busy ? null : progress * 0.85,
      ),
    );

    final indicator = RefreshIndicator.noSpinner(
      key: _indicator,
      onRefresh: widget.onRefresh,
      onStatusChange: _onStatus,
      notificationPredicate: widget.notificationPredicate,
      semanticsLabel: widget.semanticsLabel,
      semanticsValue: widget.semanticsValue,
      triggerMode: widget.triggerMode,
      elevation: widget.elevation,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
    if (_gone) return Stack(children: [indicator]);
    return Stack(
      children: [
        indicator,
        AnimatedPositioned(
          duration:
              quick ? Duration.zero : motionDuration(context, Motion.slow),
          curve: Motion.curve,
          top: widget.edgeOffset + top,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: AnimatedOpacity(
                duration: quick
                    ? Duration.zero
                    : motionDuration(context, Motion.medium),
                opacity: opacity,
                onEnd: opacity == 0 ? _faded : null,
                child: AnimatedScale(
                  duration: motionDuration(context, Motion.fast),
                  scale: armed ? 1.0 : 0.9,
                  child: Semantics(
                    label: busy
                        ? (widget.semanticsLabel ??
                            MaterialLocalizations.of(context)
                                .refreshIndicatorSemanticLabel)
                        : null,
                    child: badge,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
