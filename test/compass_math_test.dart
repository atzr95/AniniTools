import 'package:flutter_test/flutter_test.dart';
import 'package:aninitools/viewmodels/compass_viewmodel.dart';

void main() {
  test('normalizeAngle wraps into 0-360', () {
    expect(CompassViewModel.normalizeAngle(0), 0);
    expect(CompassViewModel.normalizeAngle(359.9), closeTo(359.9, 1e-9));
    expect(CompassViewModel.normalizeAngle(360), 0);
    expect(CompassViewModel.normalizeAngle(370), closeTo(10, 1e-9));
    expect(CompassViewModel.normalizeAngle(-10), closeTo(350, 1e-9));
    expect(CompassViewModel.normalizeAngle(-370), closeTo(350, 1e-9));
  });

  test('normalizeAngleDiff takes the short way across the 0/360 seam', () {
    expect(CompassViewModel.normalizeAngleDiff(0), 0);
    expect(CompassViewModel.normalizeAngleDiff(10), closeTo(10, 1e-9));
    expect(CompassViewModel.normalizeAngleDiff(-10), closeTo(-10, 1e-9));
    expect(CompassViewModel.normalizeAngleDiff(190), closeTo(-170, 1e-9));
    expect(CompassViewModel.normalizeAngleDiff(-190), closeTo(170, 1e-9));
    expect(CompassViewModel.normalizeAngleDiff(350), closeTo(-10, 1e-9));
    expect(CompassViewModel.normalizeAngleDiff(180), closeTo(180, 1e-9));
    expect(CompassViewModel.normalizeAngleDiff(-180), closeTo(-180, 1e-9));
  });

  test('normalizeAngleDiff keeps the positive half turn at exactly 180', () {
    // The smoothing filter must not flip direction as the target crosses the
    // antipode: just under 180 turns one way, so exactly 180 has to keep that
    // sign. (+180, not -180 — `(diff + 540) % 360 - 180` gets this wrong.)
    expect(CompassViewModel.normalizeAngleDiff(179.999), closeTo(179.999, 1e-9));
    expect(CompassViewModel.normalizeAngleDiff(180), closeTo(180, 1e-9));
    expect(
      CompassViewModel.normalizeAngleDiff(180.001),
      closeTo(-179.999, 1e-9),
    );
  });

  test('directionIndex buckets 45 degrees wide, centred on the cardinals', () {
    // Lower boundary of each bucket, and the last degree before it.
    expect(CompassViewModel.directionIndex(0), 0); // N
    expect(CompassViewModel.directionIndex(22.4), 0); // still N
    expect(CompassViewModel.directionIndex(22.5), 1); // NE
    expect(CompassViewModel.directionIndex(67.5), 2); // E
    expect(CompassViewModel.directionIndex(112.5), 3); // SE
    expect(CompassViewModel.directionIndex(157.5), 4); // S
    expect(CompassViewModel.directionIndex(202.5), 5); // SW
    expect(CompassViewModel.directionIndex(247.5), 6); // W
    expect(CompassViewModel.directionIndex(292.5), 7); // NW
    expect(CompassViewModel.directionIndex(337.4), 7); // still NW
    expect(CompassViewModel.directionIndex(337.5), 0); // wraps back to N
    expect(CompassViewModel.directionIndex(359.9), 0);
  });
}
