import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

// The Mint parts, built from one material rule: glazed porcelain dusted with
// powder. Depth is only the glaze (a cool highlight top-left, a hairline foot
// below); a press tamps the powder into a sunken well; loading whisks it; a
// failure spills it past the rim as loose hojicha grains.

/// Loose powder grains, laid deterministically so they never shimmer.
class SpeckPainter extends CustomPainter {
  const SpeckPainter({
    required this.colors,
    this.density = .9,
    this.seed = 7,
    this.minRadius = .35,
    this.maxRadius = .9,
    this.opacity = .55,
    this.fadeDown = false,
  });

  final List<Color> colors;

  /// Grains per 100 square logical pixels.
  final double density;
  final int seed;
  final double minRadius;
  final double maxRadius;
  final double opacity;

  /// Powder lies thinner toward the bottom (used for chart areas).
  final bool fadeDown;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(seed);
    final count = (size.width * size.height / 100 * density).round();
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final fade = fadeDown ? 1 - dy / size.height * .75 : 1.0;
      paint.color = colors[random.nextInt(colors.length)].withValues(
        alpha: (opacity * (.4 + random.nextDouble() * .6) * fade).clamp(0, 1),
      );
      canvas.drawCircle(
        Offset(dx, dy),
        minRadius + random.nextDouble() * (maxRadius - minRadius),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpeckPainter old) =>
      old.seed != seed || old.density != density || old.colors != colors;
}

/// An inner shadow for sunken wells and the struck slab.
class InsetPainter extends CustomPainter {
  const InsetPainter({
    required this.radius,
    this.offset = const Offset(1, 2),
    this.blur = 2,
    this.color = const Color(0x381D3C32),
    this.footColor = const Color(0xE6FFFFFF),
  });

  final double radius;
  final Offset offset;
  final double blur;
  final Color color;
  final Color footColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    // Everything outside the shifted shape, as an even-odd ring: the part of
    // it still inside the clip is the shadowed (or highlighted) rim.
    Path rim(Offset shift) => Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(24))
      ..addRRect(rrect.shift(shift));
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawPath(
      rim(offset),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
    canvas.drawPath(rim(const Offset(-1, -1)), Paint()..color = footColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant InsetPainter old) =>
      old.radius != radius ||
      old.offset != offset ||
      old.blur != blur ||
      old.color != color ||
      old.footColor != footColor;
}

/// Raised glazed porcelain (`.porc`).
BoxDecoration porcelainDecoration({double radius = 12, bool lifted = false}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment(-.85, -1),
        end: Alignment(.85, 1),
        colors: [Colors.white, MintColors.stock, MintColors.porcMid],
        stops: [0, .38, 1],
      ),
      boxShadow: [
        BoxShadow(color: MintColors.shade(.28), offset: const Offset(0, 1)),
        BoxShadow(
          color: MintColors.shade(lifted ? .45 : .38),
          offset: Offset(0, lifted ? 10 : 7),
          blurRadius: lifted ? 18 : 14,
          spreadRadius: -9,
        ),
      ],
    );

class Porcelain extends StatelessWidget {
  const Porcelain({
    required this.child,
    this.radius = 12,
    this.padding = const EdgeInsets.all(14),
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: porcelainDecoration(radius: radius),
    child: child,
  );
}

/// A sunken well with a fine grain (`.well`).
class Well extends StatelessWidget {
  const Well({
    required this.child,
    this.radius = 12,
    this.padding = const EdgeInsets.all(4),
    this.color = MintColors.well,
    super.key,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: ColoredBox(
      color: color,
      child: CustomPaint(
        painter: const SpeckPainter(
          colors: [MintColors.ink],
          density: .35,
          seed: 3,
          maxRadius: .6,
          opacity: .12,
        ),
        foregroundPainter: InsetPainter(radius: radius),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// Densely tamped spearmint: the struck slab every hero figure sits on.
class Slab extends StatelessWidget {
  const Slab({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 14),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [BoxShadow(color: Colors.white, offset: Offset(0, 1))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: ColoredBox(
        color: MintColors.deep,
        child: CustomPaint(
          painter: const SpeckPainter(
            colors: [
              MintColors.speckSlab,
              MintColors.speckDark,
              MintColors.powder,
            ],
            density: 1.6,
            seed: 19,
            opacity: .38,
          ),
          foregroundPainter: const InsetPainter(
            radius: 20,
            offset: Offset(2, 4),
            blur: 5,
            color: Color(0x8C081E16),
            footColor: Color(0x2EFFFFFF),
          ),
          child: Container(
            width: double.infinity,
            padding: padding,
            child: child,
          ),
        ),
      ),
    ),
  );
}

/// Loose powder (`.powder`); `tamped` when pressed flat.
class Powder extends StatelessWidget {
  const Powder({
    required this.child,
    this.radius = 26,
    this.tamped = false,
    super.key,
  });

  final Widget child;
  final double radius;
  final bool tamped;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: ColoredBox(
      color: tamped ? MintColors.tamped : MintColors.powder,
      child: CustomPaint(
        painter: SpeckPainter(
          colors: tamped
              ? const [MintColors.grainDark, MintColors.speckDark]
              : const [MintColors.grainDark, MintColors.speckLight],
          density: 1.8,
          seed: tamped ? 17 : 7,
          opacity: .42,
        ),
        foregroundPainter: tamped
            ? InsetPainter(
                radius: radius,
                offset: const Offset(3, 5),
                blur: 5,
                color: const Color(0x73143C2D),
                footColor: const Color(0x66FFFFFF),
              )
            : null,
        child: child,
      ),
    ),
  );
}

/// The milled reed under every screen title (`.mill`).
class Mill extends StatelessWidget {
  const Mill({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 9,
    width: double.infinity,
    child: CustomPaint(painter: _MillPainter()),
  );
}

class _MillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = MintColors.ink;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 1.5), paint);
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawRect(Rect.fromLTWH(x, 1.5, 1, 6), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The burnished gold edge under a chosen option.
const goldEdge = LinearGradient(
  colors: [
    MintColors.goldLo,
    MintColors.gold,
    MintColors.goldHi,
    MintColors.gold,
  ],
);

/// A set of choices in a well; the chosen one is raised porcelain with a gold
/// edge (`.seg`). `mini` is the small mono variant used for ranges.
class MintSegmented<T> extends StatelessWidget {
  const MintSegmented({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.mini = false,
    this.scrollable = false,
    super.key,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool mini;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final (value, label) in options)
        _SegItem(
          label: label,
          selected: value == selected,
          mini: mini,
          onTap: () => onChanged(value),
        ),
    ];
    final row = scrollable || mini
        ? Row(mainAxisSize: MainAxisSize.min, spacing: 2, children: items)
        : Row(
            spacing: 2,
            children: [for (final item in items) Expanded(child: item)],
          );
    return Well(
      radius: mini ? 9 : 12,
      padding: EdgeInsets.all(mini ? 3 : 4),
      child: scrollable
          ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: row)
          : row,
    );
  }
}

class _SegItem extends StatelessWidget {
  const _SegItem({
    required this.label,
    required this.selected,
    required this.mini,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool mini;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = mini ? 7.0 : 9.0;
    final style = mini
        ? MintText.mono(
            size: 11,
            weight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? MintColors.ink : MintColors.mute,
          )
        : MintText.serif(
            size: 15,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? MintColors.ink : MintColors.mute,
            height: 1.2,
          );
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: BoxConstraints(minHeight: mini ? 26 : 40),
          padding: EdgeInsets.symmetric(
            horizontal: mini ? 8 : 14,
            vertical: mini ? 5 : 9,
          ),
          decoration: selected
              ? porcelainDecoration(radius: radius)
              : BoxDecoration(borderRadius: BorderRadius.circular(radius)),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Text(label, style: style, textAlign: TextAlign.center),
              if (selected)
                Positioned(
                  left: mini ? -1 : 0,
                  right: mini ? -1 : 0,
                  bottom: mini ? -4 : -6,
                  child: Container(
                    height: mini ? 2 : 2.5,
                    decoration: BoxDecoration(
                      gradient: goldEdge,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A ruled section head: "01 WATCHING ........ the pairs on your counter".
class SectionRule extends StatelessWidget {
  const SectionRule({
    required this.number,
    required this.name,
    this.aside,
    super.key,
  });

  final String number;
  final String name;
  final String? aside;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 22, bottom: 4),
      padding: const EdgeInsets.fromLTRB(0, 7, 0, 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: MintColors.ink.withAlpha(158))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$number  ',
                  style: MintText.label(color: MintColors.deep)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: name.toUpperCase(),
                  style: MintText.label(color: MintColors.ink)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (aside != null)
            Expanded(
              child: Text(
                aside!,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: MintText.serif(
                  size: 13,
                  italic: true,
                  color: MintColors.mute,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A figure's move: the arrow always rides along with the colour.
class MoveText extends StatelessWidget {
  const MoveText({
    required this.change,
    required this.isUp,
    this.suffix,
    this.onSlab = false,
    this.size = 12,
    super.key,
  });

  final String change;
  final bool isUp;
  final String? suffix;
  final bool onSlab;
  final double size;

  @override
  Widget build(BuildContext context) {
    final neutral = change == '—';
    final color = neutral
        ? (onSlab ? MintColors.slabTint : MintColors.mute)
        : MintColors.move(isUp, onSlab: onSlab);
    return Text(
      '${neutral ? '' : (isUp ? '▲ ' : '▼ ')}$change${suffix == null ? '' : ' $suffix'}',
      style: MintText.mono(size: size, weight: FontWeight.w500, color: color),
    );
  }
}

/// The pill button: porcelain rim around a powder face that tamps flat when
/// pressed and whisks while it works (`.btn`).
class MintButton extends StatefulWidget {
  const MintButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<MintButton> createState() => _MintButtonState();
}

class _MintButtonState extends State<MintButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final face = Center(
      child: widget.loading
          ? const Whisk(size: 22, color: MintColors.ink)
          : Text(
              widget.label,
              style: MintText.serif(
                size: 18,
                weight: disabled ? FontWeight.w500 : FontWeight.w600,
                color: disabled ? const Color(0xFF8C9993) : MintColors.ink,
                height: 1,
              ),
            ),
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      child: GestureDetector(
        onTapDown: disabled || widget.loading
            ? null
            : (_) => setState(() => _down = true),
        onTapUp: disabled || widget.loading
            ? null
            : (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 62,
          padding: const EdgeInsets.all(5),
          transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
          decoration: disabled
              ? BoxDecoration(
                  color: const Color(0xFFEEF2EF),
                  borderRadius: BorderRadius.circular(31),
                  border: Border.all(color: MintColors.glazeDeep),
                )
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(31),
                  gradient: const LinearGradient(
                    begin: Alignment(-.9, -1),
                    end: Alignment(.9, 1),
                    colors: [
                      Colors.white,
                      Color(0xFFF1F6F3),
                      Color(0xFFDCE7E1),
                    ],
                    stops: [0, .45, 1],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MintColors.shade(.3),
                      offset: Offset(0, _down ? .5 : 1.5),
                    ),
                    if (!_down)
                      BoxShadow(
                        color: MintColors.shade(.5),
                        offset: const Offset(0, 14),
                        blurRadius: 22,
                        spreadRadius: -14,
                      ),
                  ],
                ),
          child: disabled
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: MintColors.glazeDeep, width: 1.5),
                  ),
                  child: face,
                )
              : Powder(radius: 26, tamped: _down, child: face),
        ),
      ),
    );
  }
}

/// A small round porcelain button that sinks when pressed (`.round`).
class RoundButton extends StatefulWidget {
  const RoundButton({
    required this.child,
    required this.onPressed,
    required this.tooltip,
    this.size = 42,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String tooltip;
  final double size;

  @override
  State<RoundButton> createState() => _RoundButtonState();
}

class _RoundButtonState extends State<RoundButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: GestureDetector(
          onTapDown: widget.onPressed == null
              ? null
              : (_) => setState(() => _down = true),
          onTapUp: widget.onPressed == null
              ? null
              : (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            width: widget.size,
            height: widget.size,
            transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
            decoration: _down
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    color: MintColors.well,
                  )
                : porcelainDecoration(radius: widget.size / 2),
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Loading whisks the powder into a swirl.
class Whisk extends StatefulWidget {
  const Whisk({this.size = 24, this.color = MintColors.ink, super.key});

  final double size;
  final Color color;

  @override
  State<Whisk> createState() => _WhiskState();
}

class _WhiskState extends State<Whisk> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _spin,
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _WhiskPainter(widget.color),
    ),
  );
}

class _WhiskPainter extends CustomPainter {
  _WhiskPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1.5;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    for (var i = 0; i < 3; i++) {
      final r = radius * (1 - i * .28);
      paint.color = color.withValues(alpha: 1 - i * .25);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        i * 2.1,
        math.pi * (1.2 - i * .2),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WhiskPainter old) => old.color != color;
}

/// Line icons drawn in the mock's 24-unit stroke style.
enum MintGlyph { coin, rate, history, alert, assay, plus, calc, swap }

class MintIcon extends StatelessWidget {
  const MintIcon(
    this.glyph, {
    this.size = 22,
    this.color = MintColors.ink,
    super.key,
  });

  final MintGlyph glyph;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _GlyphPainter(glyph, color),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final MintGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    switch (glyph) {
      case MintGlyph.coin:
        canvas.drawCircle(const Offset(12, 12), 8.5, paint);
        canvas.drawCircle(
          const Offset(12, 12),
          6,
          Paint()
            ..color = color.withValues(alpha: .45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        path
          ..moveTo(10, 15.2)
          ..lineTo(10, 8.8)
          ..lineTo(12, 11.5)
          ..lineTo(14, 8.8)
          ..lineTo(14, 15.2);
      case MintGlyph.rate:
        path
          ..moveTo(3.5, 17)
          ..lineTo(8.5, 11.5)
          ..lineTo(12, 14)
          ..lineTo(20, 6)
          ..moveTo(15.5, 6)
          ..lineTo(20, 6)
          ..lineTo(20, 10.5);
      case MintGlyph.history:
        canvas.drawCircle(const Offset(12, 12.5), 8, paint);
        path
          ..moveTo(12, 8)
          ..lineTo(12, 12.5)
          ..lineTo(15, 14.5)
          ..moveTo(4, 5.5)
          ..lineTo(6.5, 7.5);
      case MintGlyph.alert:
        path
          ..moveTo(6, 16.5)
          ..lineTo(6, 11)
          ..arcToPoint(const Offset(18, 11), radius: const Radius.circular(6))
          ..lineTo(18, 16.5)
          ..lineTo(19.5, 18)
          ..lineTo(4.5, 18)
          ..close()
          ..moveTo(10, 20.5)
          ..arcToPoint(
            const Offset(14, 20.5),
            radius: const Radius.circular(2),
            clockwise: false,
          );
      case MintGlyph.assay:
        path
          ..moveTo(12, 4)
          ..lineTo(12, 19.5)
          ..moveTo(7.5, 19.5)
          ..lineTo(16.5, 19.5)
          ..moveTo(4.5, 7)
          ..lineTo(19.5, 7)
          ..moveTo(4.5, 7)
          ..lineTo(2.5, 12.5)
          ..lineTo(6.5, 12.5)
          ..close()
          ..moveTo(19.5, 7)
          ..lineTo(17.5, 12.5)
          ..lineTo(21.5, 12.5)
          ..close();
      case MintGlyph.plus:
        path
          ..moveTo(12, 5.5)
          ..lineTo(12, 18.5)
          ..moveTo(5.5, 12)
          ..lineTo(18.5, 12);
      case MintGlyph.calc:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 3.5, 14, 17),
            const Radius.circular(2),
          ),
          paint,
        );
        path
          ..moveTo(8, 7.5)
          ..lineTo(16, 7.5)
          ..moveTo(8.5, 12)
          ..lineTo(9.5, 12)
          ..moveTo(14.5, 12)
          ..lineTo(15.5, 12)
          ..moveTo(8.5, 16)
          ..lineTo(9.5, 16)
          ..moveTo(14.5, 16)
          ..lineTo(15.5, 16);
      case MintGlyph.swap:
        path
          ..moveTo(4, 8.5)
          ..lineTo(18, 8.5)
          ..lineTo(14.5, 5)
          ..moveTo(20, 15.5)
          ..lineTo(6, 15.5)
          ..lineTo(9.5, 19);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// The tab bar: the chosen tab's disk is ringed in gold (`.tabbar`).
class MintTabBar extends StatelessWidget {
  const MintTabBar({
    required this.items,
    required this.index,
    required this.onChanged,
    super.key,
  });

  final List<(MintGlyph, String)> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MintColors.stock,
        border: Border(
          top: BorderSide(color: MintColors.glazeDeep, width: .75),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: items[i].$2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: i == index
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    center: Alignment(-.3, -.4),
                                    colors: [Colors.white, MintColors.stock],
                                  ),
                                  border: Border.all(
                                    color: MintColors.gold,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MintColors.goldLo.withAlpha(64),
                                      offset: const Offset(0, 1),
                                      spreadRadius: 1,
                                    ),
                                  ],
                                )
                              : const BoxDecoration(shape: BoxShape.circle),
                          child: MintIcon(
                            items[i].$1,
                            color: i == index
                                ? MintColors.ink
                                : MintColors.mute,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].$2.toUpperCase(),
                          style:
                              MintText.label(
                                size: 10,
                                color: i == index
                                    ? MintColors.ink
                                    : MintColors.mute,
                              ).copyWith(
                                letterSpacing: .6,
                                fontWeight: i == index
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The counter reacts in one word, then the detail (`.toast`).
void showMintToast(BuildContext context, String word, String detail) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 2600),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: MintColors.powder,
              shape: BoxShape.circle,
              border: Border.all(color: MintColors.stock),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check, size: 17, color: MintColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word,
                  style: MintText.serif(
                    size: 16,
                    weight: FontWeight.w600,
                    italic: true,
                    color: MintColors.stock,
                    height: 1.2,
                  ),
                ),
                Text(
                  detail,
                  style: MintText.mono(
                    size: 11.5,
                    color: MintColors.stock.withAlpha(217),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A failure, said plainly: what did not strike, the last figure still
/// trusted with its time, and one way back (`.fail`).
class FailCard extends StatelessWidget {
  const FailCard({
    required this.message,
    required this.onRetry,
    this.trusted,
    super.key,
  });

  final String message;
  final String? trusted;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CustomPaint(
            painter: _HatchPainter(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MintColors.hoji.withAlpha(90)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not struck.',
                    style: MintText.display(
                      size: 34,
                      color: MintColors.hoji,
                    ).copyWith(fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 6),
                  Text(message, style: MintText.body()),
                  if (trusted != null) ...[
                    const SizedBox(height: 4),
                    Text(trusted!, style: MintText.caption()),
                  ],
                  const SizedBox(height: 10),
                  _SmallPill(label: 'Weigh again', onTap: onRetry),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          right: -6,
          top: -12,
          child: SizedBox(
            width: 92,
            height: 26,
            child: CustomPaint(
              painter: SpeckPainter(
                colors: [MintColors.hoji, Color(0xFF8A3412)],
                density: 4,
                seed: 13,
                minRadius: .6,
                maxRadius: 1.6,
                opacity: .8,
                fadeDown: true,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = MintColors.hojiTint);
    final line = Paint()
      ..color = MintColors.hoji.withAlpha(33)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The small porcelain pill (`.mbtn`).
class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.center,
      decoration: porcelainDecoration(radius: 20),
      child: Text(
        label,
        style: MintText.serif(size: 14.5, weight: FontWeight.w600, height: 1),
      ),
    ),
  );
}

/// A text link that moves you on: "Calculate purchase →".
class MintLink extends StatelessWidget {
  const MintLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: MintText.serif(
                size: 14.5,
                weight: FontWeight.w600,
                color: MintColors.deep,
              ),
            ),
            const SizedBox(width: 6),
            Text('→', style: MintText.mono(size: 14, color: MintColors.deep)),
          ],
        ),
      ),
    ),
  );
}

/// A sheet's handle-and-title block, shared by every bottom sheet.
class SheetHead extends StatelessWidget {
  const SheetHead({required this.title, required this.subtitle, super.key});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: MintText.display(size: 36)),
      const SizedBox(height: 8),
      const Mill(),
      const SizedBox(height: 10),
      Text(subtitle, style: MintText.body(color: MintColors.mute)),
    ],
  );
}
