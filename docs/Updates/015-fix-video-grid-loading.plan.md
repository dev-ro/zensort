<!-- 34d1e84c-e613-4acc-ba8d-b7587c3e171a f7a2bef2-5ad3-4bc7-95f7-f1a8e7c98446 -->
# Fix PageStorage Key Collision in Video Shelves

## Root Cause Identified

The error `TypeError: true: type 'bool' is not a subtype of type 'double?'` is caused by a **PageStorage key collision**.

### Stack Trace Analysis:

```
package:flutter/src/widgets/scroll_position.dart 538:90  restoreScrollOffset
```

The `GridView.builder` is calling `restoreScrollOffset`, expecting a `double?` from PageStorage, but finding a `bool` instead.

### Why This Happens:

1. **Home Screen** (line 241): `ExpandableVideoShelf` has `key: PageStorageKey('shelf_${shelf.title}')`
2. **ExpansionTile**: Uses this key to store its expansion state as a **boolean** (true/false)
3. **GridView.builder**: Also tries to use the same inherited key to store scroll position as a **double**
4. **Collision**: When GridView tries to restore scroll position, it reads the boolean expansion state instead

### Why Search Works But Shelves Don't:

- **Search**: `ResponsiveVideoGrid` is used directly without `ExpansionTile`, so no key collision
- **Shelves**: `ResponsiveVideoGrid` → `GridView.builder` inherits the `PageStorageKey` from `ExpandableVideoShelf`/`ExpansionTile`, causing the collision

## Solution

Prevent the `GridView.builder` from using PageStorage by explicitly setting `key: null` or by wrapping it to isolate it from the parent's PageStorageKey.

### Option 1: Disable GridView PageStorage (Recommended)

Explicitly prevent `GridView.builder` from participating in PageStorage restoration by wrapping it or using a different key strategy.

### Option 2: Use Unique Keys

Give the `GridView.builder` its own unique `PageStorageKey` that doesn't collide with the ExpansionTile's key.

### Option 3: Remove PageStorageKey from ExpandableVideoShelf

Let ExpansionTile manage its own state without PageStorage (use `initiallyExpanded` parameter only).

## Implementation Steps

### Step 1: Isolate GridView from PageStorage

**File**: `lib/features/youtube/presentation/widgets/responsive_video_grid.dart`

Wrap the `GridView.builder` in a widget with `key: const ValueKey('grid')` or `key: ObjectKey(videos)` to give it a unique identity separate from the parent's PageStorageKey.

Alternatively, wrap it in a `KeyedSubtree` with a unique key to isolate it from the parent's PageStorage context.

### Step 2: Verify ExpansionTile Behavior

**File**: `lib/features/youtube/presentation/widgets/expandable_video_shelf.dart`

Ensure the `ExpansionTile` still works correctly with its `initiallyExpanded` parameter without relying on PageStorage for the child GridView.

### Step 3: Test Solution

1. Open multiple shelves → no type errors
2. Expand/collapse shelves → expansion state works correctly
3. Scroll within expanded shelves → no scroll position conflicts
4. Search functionality → continues to work as before

## Files to Modify

- `lib/features/youtube/presentation/widgets/responsive_video_grid.dart` - Isolate GridView from parent's PageStorage
- Possibly `lib/features/youtube/presentation/screens/home_screen.dart` - Consider removing PageStorageKey from ExpandableVideoShelf if not needed

## Expected Outcome

- Videos load correctly in expandable shelves
- No `TypeError: true: type 'bool' is not a subtype of type 'double?'` errors
- Expansion state continues to work as designed
- Search functionality unaffected