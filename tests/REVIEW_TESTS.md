# Independent headless review checks

These exercise real Godot physics and game methods, not GUI input events. They do not establish visual quality or Web playability. Run on a disposable copy of the project with imported assets and isolated user data; startup writes local telemetry. Do not use an existing player profile.

```sh
XDG_DATA_HOME=/tmp/hyouka-test-data XDG_CACHE_HOME=/tmp/hyouka-test-cache godot --headless --fixed-fps 60 --path /path/to/disposable/project --script res://tests/review_routes.gd
XDG_DATA_HOME=/tmp/hyouka-test-data XDG_CACHE_HOME=/tmp/hyouka-test-cache godot --headless --fixed-fps 60 --path /path/to/disposable/project --script res://tests/review_regressions.gd
```

- `review_routes.gd`: actual movement on corridor stairs up/down, house entry/interior paths, classroom perimeter/narrow window aisle, clubroom table-side round trip, and schoolyard southwest exit/north entrance paths; checks grounded status and horizontal arrival error (0.25 m tolerance)
- `review_regressions.gd`: six scene spawns, eight portal destinations, pause drift, loaded character swapping without position/yaw changes or accumulated character nodes
- Teleport checks place the player near interaction markers; they do not prove walking reachability of every marker
- Stair/house route checks follow selected paths; they are not exhaustive collision coverage
- No camera visual assertion, browser pointer-lock check, animation visual assertion, or malformed-save test is claimed by these scripts

- `review_chitanda_import.gd`: checks the tracked non-default import descriptor,
  post-import metadata, 27 zero-specular hair surfaces, embedded untinted face
  and iris textures, 17 bones, idle/walk/run durations, and the existing body
  palette color-space adapter. CI runs it on a clean checkout.
