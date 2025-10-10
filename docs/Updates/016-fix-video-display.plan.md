<!-- 5a25d122-f62d-437f-a48d-f35aa8cc8924 abd3f6c8-3771-41bd-bf11-b93b7dfbf9ee -->
# Fix Video Card Display in Shelves

## Root Cause

The `PageStorageKey('shelf_${shelf.title}')` on line 241 of `home_screen.dart` creates a storage collision:

- `ExpansionTile` stores a **boolean** (expanded state)
- `GridView.builder` tries to read a **double** (scroll position)
- Result: `TypeError: true: type 'bool' is not a subtype of type 'double?'`

This prevents the GridView from building, so no video cards render.

## Solution

Remove the `PageStorageKey` from `ExpandableVideoShelf` in `home_screen.dart`. The expansion state is already managed by the BLoC via `expandedShelfKey`, so PageStorage is unnecessary and causing the collision.

## Implementation

### Step 1: Remove PageStorageKey

**File**: `lib/features/youtube/presentation/screens/home_screen.dart`

Line 241: Remove the `key` parameter entirely from `ExpandableVideoShelf`:

```dart
// Before:
return ExpandableVideoShelf(
  key: PageStorageKey('shelf_${shelf.title}'),
  title: shelf.title,
  ...
);

// After:
return ExpandableVideoShelf(
  title: shelf.title,
  ...
);
```

### Step 2: Remove KeyedSubtree (Now Unnecessary)

**File**: `lib/features/youtube/presentation/widgets/responsive_video_grid.dart`

Lines 32-48: Remove the `KeyedSubtree` wrapper since there's no longer a collision to avoid:

```dart
// Before:
return KeyedSubtree(
  key: ValueKey('grid_${videos.length}_${videos.hashCode}'),
  child: GridView.builder(
    ...
  ),
);

// After:
return GridView.builder(
  physics: const NeverScrollableScrollPhysics(),
  shrinkWrap: true,
  ...
);
```

### Step 3: Test the Fix

1. Sign in and sync liked videos
2. Expand multiple shelves - videos should now display
3. Collapse/expand shelves - state should work via BLoC
4. Use search bar - should continue working
5. Sign out - should not throw assertion errors

## Expected Outcome

- Video cards display correctly in all expanded shelves
- No `TypeError: true: type 'bool' is not a subtype of type 'double?'`
- Expansion state managed by BLoC's `expandedShelfKey`
- Shelves start collapsed on page refresh (acceptable per user requirement)

## Files Modified

- `lib/features/youtube/presentation/screens/home_screen.dart` (line 241)
- `lib/features/youtube/presentation/widgets/responsive_video_grid.dart` (lines 32-48)

### To-dos

- [ ] Remove PageStorageKey from ExpandableVideoShelf instantiation in home_screen.dart line 241
- [ ] Remove KeyedSubtree wrapper from GridView.builder in responsive_video_grid.dart lines 32-48
- [ ] Test that video cards display in expanded shelves and verify no type errors occur