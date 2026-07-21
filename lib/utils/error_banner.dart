import 'package:flutter/material.dart';

/// Error snackbars carry actionable info (raw API error text, why a save
/// failed) that the default 4s SnackBar duration disappears before it can be
/// read. Give errors a much longer duration and an explicit dismiss action.
void showErrorSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: 'Dismiss',
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}
