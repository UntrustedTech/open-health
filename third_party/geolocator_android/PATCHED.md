geolocator_android 5.1.1+1 (MIT, Baseflow), vendored from pub.dev with two
changes so the "Workout in progress" notification shows while a GPS workout
records:

- location/BackgroundNotification.java: the channel is created with
  IMPORTANCE_LOW instead of IMPORTANCE_NONE, which hid the notification.
- GeolocatorLocationService.java: the channel ID is "workout_tracking", as
  Android won't raise the importance of the old channel on phones that
  already have it. The old channel is deleted.

Remove this override once upstream stops using IMPORTANCE_NONE.
