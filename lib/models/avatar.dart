/// Local "stock" avatars (PRD v2 §11) — a small fixed set the user can pick
/// from; no upload pipeline, no image assets to bundle. Just an emoji glyph
/// per avatar, kept free of any Flutter/UI dependency (same reasoning as
/// [AppThemeMode] in `app_theme_mode.dart`) so the storage layer doesn't
/// need to import `package:flutter/material.dart`. Null means "no avatar
/// picked yet" — callers show a generic placeholder.
enum Avatar { fox, cat, owl, panda, koala, penguin, lion, turtle }

extension AvatarInfo on Avatar {
  String get emoji {
    switch (this) {
      case Avatar.fox:
        return '🦊';
      case Avatar.cat:
        return '🐱';
      case Avatar.owl:
        return '🦉';
      case Avatar.panda:
        return '🐼';
      case Avatar.koala:
        return '🐨';
      case Avatar.penguin:
        return '🐧';
      case Avatar.lion:
        return '🦁';
      case Avatar.turtle:
        return '🐢';
    }
  }

  String toJson() {
    switch (this) {
      case Avatar.fox:
        return 'fox';
      case Avatar.cat:
        return 'cat';
      case Avatar.owl:
        return 'owl';
      case Avatar.panda:
        return 'panda';
      case Avatar.koala:
        return 'koala';
      case Avatar.penguin:
        return 'penguin';
      case Avatar.lion:
        return 'lion';
      case Avatar.turtle:
        return 'turtle';
    }
  }

  static Avatar? fromJson(String? value) {
    switch (value) {
      case 'fox':
        return Avatar.fox;
      case 'cat':
        return Avatar.cat;
      case 'owl':
        return Avatar.owl;
      case 'panda':
        return Avatar.panda;
      case 'koala':
        return Avatar.koala;
      case 'penguin':
        return Avatar.penguin;
      case 'lion':
        return Avatar.lion;
      case 'turtle':
        return Avatar.turtle;
      default:
        return null;
    }
  }
}
