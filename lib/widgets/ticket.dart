import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';

/// The ticket's state (X04).
enum TicketState { free, tearing, used }

/// The free practice ticket (X04, SPEC §3.6): one component on Home, Review
/// and the weak spot detail. Body + stub (the stub is [stubWidth] wide, the
/// body takes the rest: 266 + 84 on a 350 pt column), corner radius 22, two
/// half-circle notches (radius 12) cut out of the shape at the perforation,
/// top and bottom — part of the shape, never circles painted on top.
///
/// - **free**: orange, dashed perforation, the stub's sparkle; the lip under
///   the whole ticket; a glint every 3.4 s.
/// - **tearing**: the body turns navy (250 ms); the stub, with its own notch
///   halves and its torn zigzag edge, rotates from its top-left corner and
///   falls (450 ms, easeIn) with 4 paper bits; the USED stamp lands (2.2 →
///   1, −14°). About 700 ms, then [onTorn].
/// - **used**: the body with a torn right edge and its notch halves; the
///   stub's place is a dashed empty slot of the same shape with the time
///   left until the next ticket ([nextIn]); the lip under the body only.
///   When the state goes back to free (a new day) a stub slides into the
///   slot and the body turns orange (400 ms).
class Ticket extends StatefulWidget {
  final TicketState state;

  /// Home's shorter ticket (112 instead of 132 high).
  final bool compact;

  /// The ticket's title and line (e.g. "1 free practice" / "Use it on: …").
  final String title;
  final String subtitle;

  /// Time left until the next ticket (local midnight), for the used slot.
  final Duration? nextIn;

  /// Tap on a free ticket.
  final VoidCallback? onTap;

  /// Called once the tear has played (the caller starts practice).
  final VoidCallback? onTorn;

  const Ticket({
    super.key,
    required this.state,
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.nextIn,
    this.onTap,
    this.onTorn,
  });

  static const double stubWidth = 84;
  static const double notchRadius = 12;
  static const double cornerRadius = 22;
  static const double lip = 5;
  static double heightOf({required bool compact}) => compact ? 112 : 132;

  /// The tear's total length (V16b: about 700 ms).
  static const Duration tearDuration = Duration(milliseconds: 700);

  @override
  State<Ticket> createState() => _TicketState();
}

class _TicketState extends State<Ticket> with TickerProviderStateMixin {
  late final AnimationController _tear =
      AnimationController(vsync: this, duration: Ticket.tearDuration);
  late final AnimationController _restore = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  late final AnimationController _stamp = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250));
  AnimationController? _glint;
  bool _stampHapticDone = false;

  @override
  void initState() {
    super.initState();
    _tear.addListener(_onTearTick);
    _tear.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onTorn?.call();
    });
    if (widget.state == TicketState.used) _stamp.value = 0;
    if (widget.state != TicketState.used) _restore.value = 1;
  }

  /// A ticket built already tearing starts its tear once its dependencies
  /// (Reduce Motion) can be read.
  bool _tearChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_tearChecked) {
      _tearChecked = true;
      if (widget.state == TicketState.tearing) _startTear();
    }
    _syncGlint();
    if (widget.state == TicketState.used && _stamp.value == 0) {
      // The stamp pops once on entry (V22).
      if (AppMotion.reduced(context)) {
        _stamp.value = 1;
      } else {
        _stamp.forward();
      }
    }
  }

  @override
  void didUpdateWidget(Ticket oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      if (widget.state == TicketState.tearing) _startTear();
      if (oldWidget.state == TicketState.used &&
          widget.state == TicketState.free) {
        // A new day: the stub slides in, the body turns orange.
        if (AppMotion.reduced(context)) {
          _restore.value = 1;
        } else {
          _restore.forward(from: 0);
        }
      }
      if (widget.state == TicketState.used && _tear.value == 0) {
        _stamp.value = 1;
      }
    }
    _syncGlint();
  }

  void _startTear() {
    _stampHapticDone = false;
    if (AppMotion.reduced(context)) {
      _tear.value = 1;
      HapticMap.medium();
      // Still hand over, a frame later, so the caller's flow is the same.
      scheduleMicrotask(() {
        if (mounted) widget.onTorn?.call();
      });
      return;
    }
    HapticMap.medium();
    _tear.forward(from: 0);
  }

  void _onTearTick() {
    if (!_stampHapticDone && _tear.value >= .64) {
      _stampHapticDone = true;
      HapticMap.light();
    }
  }

  void _syncGlint() {
    final on = widget.state == TicketState.free && AppMotion.loopsOn(context);
    if (on && _glint == null) {
      _glint = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 3400))
        ..repeat();
    } else if (!on && _glint != null) {
      _glint!.dispose();
      _glint = null;
    }
  }

  @override
  void dispose() {
    _tear.dispose();
    _restore.dispose();
    _stamp.dispose();
    _glint?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = Ticket.heightOf(compact: widget.compact);
    final c = AppColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(builder: (context, constraints) {
      final width =
          constraints.maxWidth.isFinite ? constraints.maxWidth : 350.0;
      final body = width - Ticket.stubWidth;
      Widget ticket = AnimatedBuilder(
        animation: Listenable.merge(
            [_tear, _restore, _stamp, if (_glint != null) _glint!]),
        builder: (context, _) => _paint(context, c, width, body, h),
      );
      // The geometry is drawn left to right; Arabic mirrors it.
      if (rtl) {
        ticket = Transform.flip(flipX: true, child: ticket);
      }
      final semantics = switch (widget.state) {
        TicketState.free => '${widget.title}. ${widget.subtitle}',
        _ => widget.nextIn == null
            ? context.l10n.ticketUsedTitle
            : '${context.l10n.ticketUsedTitle}. '
                '${context.l10n.ticketNextSemantics(widget.nextIn!.inHours, widget.nextIn!.inMinutes % 60)}',
      };
      return Semantics(
        button: widget.onTap != null && widget.state == TicketState.free,
        label: semantics,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.state == TicketState.free ? widget.onTap : null,
          child: SizedBox(width: width, height: h + Ticket.lip, child: ticket),
        ),
      );
    });
  }

  Widget _paint(
      BuildContext context, AppColors c, double width, double body, double h) {
    final tear = _tear.value;
    final used = widget.state != TicketState.free || tear > 0;
    final restored = _restore.value;
    // Body colour: orange → navy over the first 250 ms of the tear; back to
    // orange as a new stub slides in.
    final toNavy = widget.state == TicketState.free
        ? (1 - restored)
        : (widget.state == TicketState.tearing
            ? (tear / (250 / 700)).clamp(0.0, 1.0)
            : 1.0);
    final bodyColor = Color.lerp(c.orange, c.navy, toNavy)!;
    final bodyLip = Color.lerp(c.orangeDeep, c.navyDeep, toNavy)!;
    final onBody = Color.lerp(c.onOrange, c.onNavy, toNavy)!;
    final showUsedLayout = widget.state != TicketState.free;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    // The falling stub: from 0 to 450/700 of the tear.
    final fall = (tear / (450 / 700)).clamp(0.0, 1.0);
    final fallT = Curves.easeIn.transform(fall);
    // The stamp: 450 → 700.
    final stampT = widget.state == TicketState.tearing
        ? ((tear - 450 / 700) / (250 / 700)).clamp(0.0, 1.0)
        : _stamp.value;

    // Laid out left to right like the geometry; the whole ticket is
    // mirrored in Arabic and the texts flipped back (_Texts.flip).
    final texts = SizedBox(
      width: body,
      height: h,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            widget.compact ? 16 : 18, 0, showUsedLayout ? 100 : 16, 0),
        child: _Texts(
          eyebrow: context.l10n.ticketEyebrow,
          title: showUsedLayout
              ? (widget.state == TicketState.tearing
                  ? context.l10n.ticketTearingTitle
                  : context.l10n.ticketUsedTitle)
              : widget.title,
          subtitle: showUsedLayout
              ? (widget.state == TicketState.tearing
                  ? context.l10n.ticketTearingBody
                  : widget.subtitle)
              : widget.subtitle,
          color: onBody,
          titleSize: showUsedLayout || widget.compact ? 22 : 25,
          flip: rtl,
        ),
      ),
    );

    final children = <Widget>[];
    if (!used || (widget.state == TicketState.free && restored >= 1)) {
      // Free: one shape, lip under the whole ticket.
      children.add(Positioned.fill(
        child: CustomPaint(
          painter: _TicketPainter(
            width: width,
            body: body,
            height: h,
            color: bodyColor,
            lip: bodyLip,
            perforation: c.onOrange.withValues(alpha: .35),
            kind: _Shape.whole,
          ),
        ),
      ));
      children.add(Positioned(left: 0, top: 0, child: texts));
      children.add(Positioned(
        left: body,
        top: 0,
        width: Ticket.stubWidth,
        height: h,
        child: _flipBack(rtl,
            Icon(Icons.auto_awesome_outlined, color: c.onOrange, size: 34)),
      ));
      if (_glint != null) {
        children.add(Positioned(
          left: 0,
          top: 0,
          width: width,
          height: h,
          child: ClipPath(
            clipper: _ShapeClipper(width: width, body: body, height: h),
            child: _Glint(t: _glint!.value),
          ),
        ));
      }
    } else {
      // The body alone: torn right edge, lip under the body only.
      children.add(Positioned(
        left: 0,
        top: 0,
        width: body,
        height: h + Ticket.lip,
        child: CustomPaint(
          painter: _TicketPainter(
            width: width,
            body: body,
            height: h,
            color: bodyColor,
            lip: bodyLip,
            perforation: Colors.transparent,
            kind: _Shape.tornBody,
          ),
        ),
      ));
      children.add(Positioned(left: 0, top: 0, child: texts));
      // The used slot (dashed), or the stub sliding back in on a new day.
      if (widget.state == TicketState.used ||
          (widget.state == TicketState.free && restored < 1)) {
        children.add(Positioned(
          left: body + 6,
          top: 0,
          width: Ticket.stubWidth - 6,
          height: h,
          child: Opacity(
            opacity: widget.state == TicketState.free ? 1 - restored : 1,
            child: CustomPaint(
              painter: _SlotPainter(
                  fill: c.card.withValues(alpha: .6), stroke: c.line),
              child: _flipBack(
                  rtl,
                  _NextSlot(
                      nextIn: widget.nextIn, color: c.navy, muted: c.muted)),
            ),
          ),
        ));
      }
      if (widget.state == TicketState.free && restored < 1) {
        final slide = (1 - Curves.easeOutCubic.transform(restored)) * 60;
        children.add(Positioned(
          left: body + slide,
          top: 0,
          width: Ticket.stubWidth,
          height: h,
          child: CustomPaint(
            painter: _StubPainter(height: h, color: c.orange),
            child: Center(
                child: _flipBack(
                    rtl,
                    Icon(Icons.auto_awesome_outlined,
                        color: c.onOrange, size: 34))),
          ),
        ));
      }
      // The stamp in its own column inside the body.
      if (stampT > 0) {
        final scale = 2.2 - 1.2 * Curves.easeOutBack.transform(stampT);
        children.add(Positioned(
          left: body - 94,
          top: (h - 40) / 2,
          width: 72,
          height: 40,
          child: Opacity(
            opacity: stampT.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: -14 * math.pi / 180,
              child: Transform.scale(
                  scale: scale, child: _flipBack(rtl, _Stamp(color: c.gold))),
            ),
          ),
        ));
      }
      // The falling stub and its paper bits.
      if (widget.state == TicketState.tearing && fall < 1) {
        children.add(Positioned(
          left: body,
          top: 0,
          width: Ticket.stubWidth,
          height: h,
          child: Transform(
            alignment: Alignment.topLeft,
            transform: Matrix4.identity()
              ..translateByDouble(22 * fallT, 160 * fallT, 0, 1)
              ..rotateZ(24 * math.pi / 180 * fallT),
            child: Opacity(
              opacity: (1 - fallT * .6).clamp(0.0, 1.0),
              child: CustomPaint(
                painter: _StubPainter(height: h, color: c.orange),
                child: Center(
                    child: _flipBack(
                        rtl,
                        Icon(Icons.auto_awesome_outlined,
                            color: c.onOrange, size: 34))),
              ),
            ),
          ),
        ));
        for (var i = 0; i < 4; i++) {
          final dx = (10 + 6 * i) * fallT;
          children.add(Positioned(
            left: body + dx,
            top: 20 + 22.0 * i + 60 * fallT,
            child: Opacity(
              opacity: (1 - fallT).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: 200 * math.pi / 180 * fallT,
                child: Container(width: 6, height: 6, color: c.orange),
              ),
            ),
          ));
        }
      }
    }
    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// Text and icons inside the mirrored ticket are flipped back so they
  /// read correctly in Arabic.
  static Widget _flipBack(bool rtl, Widget child) => rtl
      ? Transform.flip(flipX: true, child: Center(child: child))
      : Center(child: child);
}

class _Texts extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color color;
  final double titleSize;
  final bool flip;

  const _Texts({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.titleSize,
    required this.flip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final column = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eyebrow,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall!
                  .withWeight(FontWeight.w900)
                  .copyWith(
                      color: color.withValues(alpha: .85),
                      fontSize: 12,
                      letterSpacing: 1.4)),
          const SizedBox(height: 4),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall!
                  .withWeight(FontWeight.w900)
                  .copyWith(
                      color: color,
                      fontSize: titleSize,
                      height: 1.1,
                      letterSpacing: -.4)),
          const SizedBox(height: 4),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!
                  .withWeight(FontWeight.w600)
                  .copyWith(
                      color: color.withValues(alpha: .9),
                      fontSize: 13,
                      height: 1.35)),
        ],
      ),
    );
    if (!flip) return column;
    // Undo the ticket's mirror so Arabic text reads right to left normally.
    return Transform.flip(flipX: true, child: column);
  }
}

class _Stamp extends StatelessWidget {
  final Color color;
  const _Stamp({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 3),
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: .08),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            context.l10n.ticketStamp,
            maxLines: 1,
            style: Theme.of(context)
                .textTheme
                .labelLarge!
                .withWeight(FontWeight.w900)
                .copyWith(color: color, fontSize: 15, letterSpacing: 1.5),
          ),
        ),
      ),
    );
  }
}

/// The used slot's content: a clock, the time left (h:mm) and "NEXT".
class _NextSlot extends StatelessWidget {
  final Duration? nextIn;
  final Color color;
  final Color muted;

  const _NextSlot(
      {required this.nextIn, required this.color, required this.muted});

  @override
  Widget build(BuildContext context) {
    final left = nextIn ?? Duration.zero;
    final hh = left.inHours;
    final mm = (left.inMinutes % 60).toString().padLeft(2, '0');
    final theme = Theme.of(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 20, color: color),
          const SizedBox(height: 3),
          Text('$hh:$mm', // l10n-guard: a time span of numbers
              style: theme.textTheme.titleSmall!
                  .withWeight(FontWeight.w900)
                  .copyWith(
                      color: color,
                      fontSize: 15,
                      fontFeatures: const [FontFeature.tabularFigures()])),
          Text(context.l10n.ticketNext,
              maxLines: 1,
              style: theme.textTheme.labelSmall!
                  .withWeight(FontWeight.w800)
                  .copyWith(color: muted, fontSize: 10, letterSpacing: .6)),
        ],
      ),
    );
  }
}

/// A light band sweeping over the free ticket (`gl-shine` 3.4 s).
class _Glint extends StatelessWidget {
  final double t;
  const _Glint({required this.t});

  @override
  Widget build(BuildContext context) {
    final p = (t / .55).clamp(0.0, 1.0);
    return IgnorePointer(
      child: FractionalTranslation(
        translation: Offset(-1.4 + 4.6 * p, 0),
        child: FractionallySizedBox(
          widthFactor: .3,
          alignment: Alignment.centerLeft,
          child: Transform(
            transform: Matrix4.skewX(-.35),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color(0x00FFFFFF),
                  Color(0x59FFFFFF),
                  Color(0x00FFFFFF),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Shape { whole, tornBody }

/// The ticket's outline (X04's SVG paths), for a [width] × [height] ticket
/// whose perforation sits at x = [body].
Path _wholePath(double width, double body, double h) {
  const r = Ticket.cornerRadius;
  const n = Ticket.notchRadius;
  return Path()
    ..moveTo(r, 0)
    ..lineTo(body - n, 0)
    ..arcToPoint(Offset(body + n, 0),
        radius: const Radius.circular(n), clockwise: false)
    ..lineTo(width - r, 0)
    ..arcToPoint(Offset(width, r), radius: const Radius.circular(r))
    ..lineTo(width, h - r)
    ..arcToPoint(Offset(width - r, h), radius: const Radius.circular(r))
    ..lineTo(body + n, h)
    ..arcToPoint(Offset(body - n, h),
        radius: const Radius.circular(n), clockwise: false)
    ..lineTo(r, h)
    ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
    ..lineTo(0, r)
    ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
    ..close();
}

/// The body after the tear: its notch halves and a zigzag right edge.
Path _tornBodyPath(double body, double h) {
  const r = Ticket.cornerRadius;
  const n = Ticket.notchRadius;
  final p = Path()
    ..moveTo(r, 0)
    ..lineTo(body - n, 0)
    ..arcToPoint(Offset(body, n),
        radius: const Radius.circular(n), clockwise: false);
  var y = n;
  var left = true;
  while (y + 8 < h - n) {
    y += 8;
    p.lineTo(left ? body - 7 : body, y);
    left = !left;
  }
  p
    ..lineTo(body, h - n)
    ..arcToPoint(Offset(body - n, h),
        radius: const Radius.circular(n), clockwise: false)
    ..lineTo(r, h)
    ..arcToPoint(Offset(0, h - r), radius: const Radius.circular(r))
    ..lineTo(0, r)
    ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
    ..close();
  return p;
}

/// The stub alone (84 wide): its notch halves and its torn left edge.
Path _stubPath(double h) {
  const r = Ticket.cornerRadius;
  const n = Ticket.notchRadius;
  const w = Ticket.stubWidth;
  final p = Path()
    ..moveTo(n, 0)
    ..lineTo(w - r, 0)
    ..arcToPoint(const Offset(w, r), radius: const Radius.circular(r))
    ..lineTo(w, h - r)
    ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
    ..lineTo(n, h)
    ..arcToPoint(Offset(0, h - n),
        radius: const Radius.circular(n), clockwise: false);
  var y = h - n;
  var right = true;
  while (y - 8 > n) {
    y -= 8;
    p.lineTo(right ? 7 : 0, y);
    right = !right;
  }
  p
    ..lineTo(0, n)
    ..arcToPoint(const Offset(n, 0),
        radius: const Radius.circular(n), clockwise: false)
    ..close();
  return p;
}

class _TicketPainter extends CustomPainter {
  final double width;
  final double body;
  final double height;
  final Color color;
  final Color lip;
  final Color perforation;
  final _Shape kind;

  _TicketPainter({
    required this.width,
    required this.body,
    required this.height,
    required this.color,
    required this.lip,
    required this.perforation,
    required this.kind,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = kind == _Shape.whole
        ? _wholePath(width, body, height)
        : _tornBodyPath(body, height);
    canvas.drawPath(
        path.shift(const Offset(0, Ticket.lip)), Paint()..color = lip);
    canvas.drawPath(path, Paint()..color = color);
    if (kind == _Shape.whole && perforation.a > 0) {
      final dash = Paint()
        ..color = perforation
        ..strokeWidth = 3;
      for (var y = 16.0; y < height - 16; y += 12) {
        canvas.drawLine(
            Offset(body, y), Offset(body, math.min(y + 6, height - 16)), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_TicketPainter old) =>
      old.color != color ||
      old.lip != lip ||
      old.width != width ||
      old.body != body ||
      old.kind != kind;
}

class _StubPainter extends CustomPainter {
  final double height;
  final Color color;
  _StubPainter({required this.height, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_stubPath(height), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StubPainter old) =>
      old.color != color || old.height != height;
}

/// The empty slot where the stub was: the stub's shape, dashed.
class _SlotPainter extends CustomPainter {
  final Color fill;
  final Color stroke;
  _SlotPainter({required this.fill, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    const r = Ticket.cornerRadius;
    const n = Ticket.notchRadius;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(n, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: const Radius.circular(r))
      ..lineTo(n, h)
      ..arcToPoint(Offset(0, h - n),
          radius: const Radius.circular(n), clockwise: false)
      ..lineTo(0, n)
      ..arcToPoint(const Offset(n, 0),
          radius: const Radius.circular(n), clockwise: false)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
            metric.extractPath(d, math.min(d + 7, metric.length)), paint);
        d += 13;
      }
    }
  }

  @override
  bool shouldRepaint(_SlotPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

class _ShapeClipper extends CustomClipper<Path> {
  final double width;
  final double body;
  final double height;
  _ShapeClipper(
      {required this.width, required this.body, required this.height});

  @override
  Path getClip(Size size) => _wholePath(width, body, height);

  @override
  bool shouldReclip(_ShapeClipper old) =>
      old.width != width || old.body != body || old.height != height;
}
