import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme.dart';

/// The card at the top of Review (1.2.0 final screens, brief §2): one shell
/// for its three variants — Free "available" (orange), Free "used" (navy)
/// and Premium "Suggested Focus" (navy) — so they share the width, the
/// corner radius, the 18 pt padding and the edge rule. Only the colour, the
/// edge and the content differ.
class ReviewTopCard extends StatelessWidget {
  final Color color;

  /// The dark mode #5C7CFA edge of a navy card; none for the orange one.
  final Color? edge;
  final Widget child;

  /// A key for the [Card] itself (tests read its colour and edge).
  final Key? cardKey;

  const ReviewTopCard({
    super.key,
    required this.color,
    required this.child,
    this.edge,
    this.cardKey,
  });

  /// The shell's inner padding.
  static const double padding = 18;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: cardKey,
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appCardRadius),
        side: edge == null ? BorderSide.none : BorderSide(color: edge!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: child,
      ),
    );
  }
}

/// Lays out [child] at least as tall as [reference] would be in the same
/// place, and draws only [child]. [reference] is laid out but never painted,
/// hit or read by a screen reader: it only lends its height.
///
/// Premium's Suggested Focus uses it with the Free "available" content as
/// the reference (owner, 2026-10-06), so switching between the two never
/// moves the list. When [child] needs more (a long title at a large text
/// size) it grows: the text is never cut or shrunk to match.
class MatchHeight extends MultiChildRenderObjectWidget {
  MatchHeight({super.key, required Widget reference, required Widget child})
      : super(children: [reference, child]);

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMatchHeight();
}

class _MatchHeightParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMatchHeight extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MatchHeightParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MatchHeightParentData> {
  RenderBox get _reference => firstChild!;
  RenderBox get _child => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MatchHeightParentData) {
      child.parentData = _MatchHeightParentData();
    }
  }

  BoxConstraints _loose(BoxConstraints c) =>
      BoxConstraints(minWidth: c.maxWidth, maxWidth: c.maxWidth);

  @override
  void performLayout() {
    final width = _loose(constraints);
    _reference.layout(width, parentUsesSize: true);
    _child.layout(width, parentUsesSize: true);
    final height = math.max(_reference.size.height, _child.size.height);
    // Again with the final height as its minimum, so the child can place
    // its parts in it (Suggested Focus keeps its button at the bottom).
    // Not tight: tight constraints would make the child a relayout
    // boundary, and a later change inside it (loading → loaded) would lay
    // it out again alone, at the old height.
    _child.layout(
        BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
            minHeight: height),
        parentUsesSize: true);
    size = constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
      _reference.getMinIntrinsicHeight(width),
      _child.getMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
      _reference.getMaxIntrinsicHeight(width),
      _child.getMaxIntrinsicHeight(width));

  @override
  double computeMinIntrinsicWidth(double height) =>
      _child.getMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _child.getMaxIntrinsicWidth(height);

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(_child, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      _child.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      visitor(_child);
}
