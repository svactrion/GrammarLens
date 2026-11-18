import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Locale, Offset;

import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter/services.dart' show AssetBundle;

import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../models/review_sort_order.dart';
import '../widgets/monthly_climb/climb_route.dart';
import '../widgets/monthly_climb/climb_trail_table.dart';
import 'native_bridge.dart';
import 'storage_service.dart';
import 'widget_images.dart';
import 'widget_payload.dart';

/// Writes the home-screen widgets' payload and images into the App Group
/// and reloads the widgets (TASK-widgets fixed decision 3, W3). Run by
/// `DeviceSync` at launch, on resume (a new day or month), and whenever the
/// Daily Test, practice, the profile or the language changes.
class WidgetSync {
  WidgetSync({
    required this.storage,
    required this.bridge,
    required this.locale,
    DateTime Function()? clock,
    this.bundle,
  }) : clock = clock ?? DateTime.now;

  final StorageService storage;
  final NativeBridge bridge;

  /// The interface's locale now.
  final Locale Function() locale;
  final DateTime Function() clock;
  final AssetBundle? bundle;

  static const payloadFile = 'payload.json';

  /// Returns whether a payload was written. Nothing happens without the App
  /// Group (no widget extension, web, tests) or before onboarding.
  Future<bool> run() async {
    if (!await bridge.appGroupAvailable()) return false;
    final profile = await storage.getUserProfile();
    if (profile == null) return false;
    final now = clock();
    final appLocale = locale();
    final l10n = lookupAppLocalizations(appLocale);

    final today = await storage.getDailyTestSetForToday();
    final progress = await storage.getClimbProgress(now.year, now.month);
    final medal = await storage.getMonthlyMedalProgress(now.year, now.month);
    final themeId = await storage.resolveClimbMonthTheme(now.year, now.month);
    final avatar = profile.avatar ?? Avatar.fox;

    final month = await _month(
      l10n,
      year: now.year,
      month: now.month,
      theme: ClimbThemes.byId(themeId),
      avatarDay: progress.steps,
    );
    final midnight = nextLocalMidnight(now);
    WidgetMonth nextMonth = month;
    if (midnight.month != now.month) {
      // Read only: the new month's theme is recorded when Home shows it.
      final stored = await storage.getClimbMonthThemes();
      final theme = stored[(midnight.year, midnight.month)] != null
          ? ClimbThemes.byId(stored[(midnight.year, midnight.month)]!)
          : ClimbThemeRotation.shownFor(midnight.year, midnight.month);
      nextMonth = await _month(l10n,
          year: midnight.year,
          month: midnight.month,
          theme: theme,
          avatarDay: 0);
    }

    final avatarFile = await _avatar(avatar);
    final sleepFile = await _avatar(avatar, pose: 'sleep');
    final mistakes = await _mistakes();
    final payload = buildWidgetPayload(
      WidgetInput(
        now: now,
        userName: profile.name,
        avatarImage: avatarFile,
        dailyTestDone: today?.isCompleted == true,
        stepsDone: progress.steps,
        monthPoints: medal.score,
        month: month,
        nextMonth: nextMonth,
        mistakes: mistakes,
        sleepImage: sleepFile,
        rtl: appLocale.languageCode == 'ar',
      ),
      l10n,
    );
    final written = await bridge.writeAppGroupFile(
        payloadFile, Uint8List.fromList(utf8.encode(jsonEncode(payload))));
    await _deleteUnused({
      payloadFile,
      avatarFile,
      sleepFile,
      month.lightImage,
      month.darkImage,
      nextMonth.lightImage,
      nextMonth.darkImage,
    });
    await bridge.reloadWidgets();
    return written;
  }

  /// The month's mountain crops around the avatar's point, written once per
  /// theme, month length and step.
  Future<WidgetMonth> _month(
    AppLocalizations l10n, {
    required int year,
    required int month,
    required ClimbTheme theme,
    required int avatarDay,
  }) async {
    final days = DateUtils.getDaysInMonth(year, month);
    final point = ClimbRoute(days).stepAt(avatarDay);
    final crop = widgetCrop(point, imageAspect: climbImageAspect);
    final base = 'mountain_${theme.id}_d${days}_s${avatarDay.clamp(0, days)}';
    final light = '${base}_light.png';
    final dark = '${base}_dark.png';
    final lightAsset = theme.backgroundLight;
    final darkAsset = theme.backgroundDark ?? lightAsset;
    if (lightAsset != null) {
      await _ensure(light, () async {
        final image = await loadAssetImage(lightAsset, bundle: bundle);
        return renderCrop(image, crop.rect, widgetMountainSize);
      });
    }
    if (darkAsset != null) {
      await _ensure(dark, () async {
        final image = await loadAssetImage(darkAsset, bundle: bundle);
        return renderCrop(image, crop.rect, widgetMountainSize);
      });
    }
    return WidgetMonth(
      year: year,
      month: month,
      days: days,
      mountainName: theme.title(l10n),
      monthName: monthName(month, l10n),
      lightImage: light,
      darkImage: dark,
      avatarPoint: Offset(crop.avatar.dx, crop.avatar.dy),
    );
  }

  /// W01 v12: the user's weak spots (the most recent first, at most
  /// [widgetMistakeLimit]), each with its latest mistake that has both the
  /// user's answer and its correction. Read from Review's own records.
  Future<List<WidgetMistake>> _mistakes() async {
    final spots = await storage.getWeakSpots(
        limit: widgetMistakeLimit, sortOrder: ReviewSortOrder.recent);
    final out = <WidgetMistake>[];
    for (final spot in spots) {
      final latest =
          await storage.getRecentMistakes(spot.topicId, spot.errorType);
      for (final entry in latest) {
        final user = entry.userAnswer?.trim() ?? '';
        final corrected = entry.correctedAnswer?.trim() ?? '';
        if (user.isEmpty || corrected.isEmpty) continue;
        out.add(WidgetMistake(
          topicId: spot.topicId,
          errorType: spot.errorType,
          userAnswer: user,
          correctedAnswer: corrected,
          prompt: entry.prompt,
          rule: entry.rule,
        ));
        break;
      }
    }
    return out;
  }

  /// The avatar (or, with [pose], that pose of it: the tip widget's sleeping
  /// companion) as a PNG in the App Group.
  Future<String> _avatar(Avatar avatar, {String? pose}) async {
    final path = pose == null ? avatar.assetPath : avatar.posePath(pose);
    final name = path.split('/').last.replaceFirst(RegExp(r'\.webp$'), '.png');
    await _ensure(name, () async {
      final image = await loadAssetImage(path, bundle: bundle);
      return renderSquare(image, widgetAvatarSize);
    });
    return name;
  }

  Set<String>? _existing;

  Future<void> _ensure(String name, Future<Uint8List> Function() make) async {
    _existing ??= (await bridge.listAppGroupFiles()).toSet();
    if (_existing!.contains(name)) return;
    final bytes = await make();
    if (await bridge.writeAppGroupFile(name, bytes)) {
      _existing!.add(name);
    }
  }

  Future<void> _deleteUnused(Set<String> keep) async {
    final names = await bridge.listAppGroupFiles();
    for (final name in names) {
      if (!keep.contains(name)) await bridge.deleteAppGroupFile(name);
    }
    _existing = null;
  }
}
