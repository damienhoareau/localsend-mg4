import 'package:flutter/widgets.dart';

/// MG4: factor applied to the whole interface (text, icons, buttons, spacing) so it is readable on the head unit.
/// Override at build time with `--dart-define=UI_SCALE=1.8`.
///
/// Note: the layout switches to the phone layout below 700 logical pixels of width (see `SizingInformation`),
/// so very large factors change the layout, not only the size.
/// (Dart only has `fromEnvironment` for String, int and bool, hence the parsing.)
final double mg4UiScale = double.tryParse(const String.fromEnvironment('UI_SCALE', defaultValue: '1.6')) ?? 1.6;

/// Renders [child] as if the screen were [scale] times smaller, then magnifies the result by [scale].
/// Touches are mapped back through the same transform, and the [MediaQuery] is adjusted so that
/// responsive widgets, dialogs and menus see the reduced logical size.
class UiScale extends StatelessWidget {
  /// Magnification factor, [mg4UiScale] when null.
  final double? factor;
  final Widget child;

  const UiScale({
    required this.child,
    this.factor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final scale = factor ?? mg4UiScale;
    if (scale == 1.0) {
      return child;
    }

    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size / scale;

    return OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: MediaQuery(
          data: mediaQuery.copyWith(
            size: size,
            padding: mediaQuery.padding / scale,
            viewPadding: mediaQuery.viewPadding / scale,
            viewInsets: mediaQuery.viewInsets / scale,
            systemGestureInsets: mediaQuery.systemGestureInsets / scale,
          ),
          child: child,
        ),
      ),
    );
  }
}
