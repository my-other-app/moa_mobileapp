import 'package:flutter/material.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/motion.dart';

/// One choice of an [AppSelectField] or [showAppSelect].
class AppOption<T> {
  const AppOption(this.value, this.label, {this.subtitle, this.icon, this.key});

  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;

  /// On the option's row, for tests.
  final Key? key;
}

/// What [showAppSelect] answers: the chosen value (which may itself be
/// null, "Any"), or no answer at all when the sheet was closed.
typedef AppSelection<T> = ({T value});

/// The app's picker, in place of a [DropdownButton]'s menu: a sheet from the
/// bottom with a Bebas Neue [title] and one row an option, the current one
/// ticked on a pale yellow wash. With [searchable], a search box filters a
/// long list by its labels.
Future<AppSelection<T>?> showAppSelect<T>(
  BuildContext context, {
  required String title,
  required List<AppOption<T>> options,
  T? selected,
  bool searchable = false,
}) {
  return showModalBottomSheet<AppSelection<T>>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => AppSelectSheet<T>(
      title: title,
      options: options,
      selected: selected,
      searchable: searchable,
    ),
  );
}

/// What [showAppSelect] shows.
class AppSelectSheet<T> extends StatefulWidget {
  const AppSelectSheet({
    super.key,
    required this.title,
    required this.options,
    this.selected,
    this.searchable = false,
  });

  final String title;
  final List<AppOption<T>> options;
  final T? selected;
  final bool searchable;

  static const searchKey = ValueKey('app-select-search');

  @override
  State<AppSelectSheet<T>> createState() => _AppSelectSheetState<T>();
}

class _AppSelectSheetState<T> extends State<AppSelectSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.options
        : [
            for (final o in widget.options)
              if (o.label.toLowerCase().contains(q) ||
                  (o.subtitle?.toLowerCase().contains(q) ?? false))
                o,
          ];
    return Padding(
      // Above the keyboard while searching.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    widget.title.toUpperCase(),
                    style: const TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 22,
                        color: AppColors.ink),
                  ),
                ),
              ),
              if (widget.searchable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    key: AppSelectSheet.searchKey,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.softGrey,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: shown.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nothing matches.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF6B7280))),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        children: [
                          for (final o in shown)
                            _OptionRow<T>(
                              option: o,
                              chosen: o.value == widget.selected,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option, required this.chosen});

  final AppOption<T> option;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    final o = option;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(
        button: true,
        selected: chosen,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: chosen ? AppColors.paleYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: o.key,
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Haptics.selection();
              Navigator.of(context).pop<AppSelection<T>>((value: o.value));
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    if (o.icon != null) ...[
                      Icon(o.icon, size: 20, color: AppColors.ink),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    chosen ? FontWeight.w700 : FontWeight.w500,
                                color: AppColors.ink,
                              )),
                          if (o.subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(o.subtitle!,
                                  style: const TextStyle(
                                      fontSize: 13, color: Color(0xFF6B7280))),
                            ),
                        ],
                      ),
                    ),
                    if (chosen)
                      const Icon(Icons.check_rounded,
                          size: 22, color: AppColors.ink),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The app's select field, in place of a [DropdownButton]: what is chosen on
/// a soft grey, rounded box with a chevron, opening [showAppSelect]. A
/// [label] above it, a [hint] while nothing is chosen, and an [errorText]
/// under it (see [AppSelectFormField] for a form's validation).
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.sheetTitle,
    this.hint,
    this.errorText,
    this.searchable = false,
    this.dense = false,
    this.semanticsLabel,
  });

  final List<AppOption<T>> options;
  final T? value;

  /// Null makes the field read-only.
  final ValueChanged<T>? onChanged;
  final String? label;

  /// The sheet's title; [label] when null.
  final String? sheetTitle;
  final String? hint;
  final String? errorText;
  final bool searchable;

  /// Lower, for a row of settings.
  final bool dense;
  final String? semanticsLabel;

  AppOption<T>? get _current {
    for (final o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  Future<void> _open(BuildContext context) async {
    final change = onChanged;
    if (change == null) return;
    final picked = await showAppSelect<T>(
      context,
      title: sheetTitle ?? label ?? hint ?? 'Choose',
      options: options,
      selected: value,
      searchable: searchable,
    );
    if (picked != null && picked.value != value) change(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final enabled = onChanged != null;
    final error = errorText;
    final box = Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel ?? label ?? hint,
      value: current?.label,
      excludeSemantics: true,
      child: Material(
        color: AppColors.softGrey,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => _open(context) : null,
          child: Container(
            constraints: BoxConstraints(minHeight: dense ? 44 : 52),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: error == null
                  ? null
                  : Border.all(color: Theme.of(context).colorScheme.error),
            ),
            child: Row(
              children: [
                if (current?.icon != null) ...[
                  Icon(current!.icon, size: 18, color: AppColors.ink),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    current?.label ?? hint ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: current == null
                          ? const Color(0xFF9CA3AF)
                          : (enabled ? AppColors.ink : const Color(0xFF6B7280)),
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: enabled ? AppColors.ink : const Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ),
    );
    if (label == null && error == null) return box;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label!,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151))),
          ),
        box,
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(error,
                style: TextStyle(
                    fontSize: 12, color: Theme.of(context).colorScheme.error)),
          ),
      ],
    );
  }
}

/// [AppSelectField] in a [Form]: validated and saved with it.
class AppSelectFormField<T> extends FormField<T> {
  AppSelectFormField({
    super.key,
    required List<AppOption<T>> options,
    super.initialValue,
    ValueChanged<T>? onChanged,
    super.validator,
    super.onSaved,
    super.autovalidateMode,
    String? label,
    String? sheetTitle,
    String? hint,
    bool searchable = false,
    super.enabled,
  }) : super(
          builder: (state) => AppSelectField<T>(
            options: options,
            value: state.value,
            label: label,
            sheetTitle: sheetTitle,
            hint: hint,
            searchable: searchable,
            errorText: state.errorText,
            onChanged: state.widget.enabled
                ? (v) {
                    state.didChange(v);
                    onChanged?.call(v);
                  }
                : null,
          ),
        );
}

/// [AppSelectField] for the end of a settings row: the choice and a chevron
/// on a small soft grey pill, opening the same sheet. The touch is 44 high.
class AppSelectPill<T> extends StatelessWidget {
  const AppSelectPill({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.sheetTitle,
    this.semanticsLabel,
  });

  final List<AppOption<T>> options;
  final T value;

  /// Null makes it read-only.
  final ValueChanged<T>? onChanged;
  final String sheetTitle;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    String? current;
    for (final o in options) {
      if (o.value == value) current = o.label;
    }
    final change = onChanged;
    Future<void> open() async {
      if (change == null) return;
      final picked = await showAppSelect<T>(context,
          title: sheetTitle, options: options, selected: value);
      if (picked != null && picked.value != value) change(picked.value);
    }

    return Semantics(
      button: true,
      enabled: change != null,
      label: semanticsLabel ?? sheetTitle,
      value: current,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(60),
          onTap: change == null ? null : open,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                decoration: BoxDecoration(
                  color: AppColors.softGrey,
                  borderRadius: BorderRadius.circular(60),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(current ?? '',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.ink)),
                    const SizedBox(width: 2),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 20, color: AppColors.ink),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
