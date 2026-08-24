/// Extra bottom padding reserved inside each bottom-nav tab's scrollable
/// content, so its last item can be scrolled fully clear of the floating
/// nav bar (`app.dart`) instead of stopping right at/under it. Content is
/// expected to sit *behind* the bar while at rest — that's the point of a
/// floating, translucent pill (Instagram-style) — this only guarantees a
/// user can scroll far enough to bring an important control (e.g.
/// Settings' Save button) out from under it. Shared by every tab screen
/// (Home, Review, Settings) so they can't drift out of sync with the bar's
/// actual footprint.
const double navBarClearance = 110;
