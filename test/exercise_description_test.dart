import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/demo/exercise_description.dart';

ExerciseDescription read(String name, List<String> steps) =>
    ExerciseDescription.read(name, steps);

void main() {
  group('sides', () {
    test('one arm, from the name', () {
      final d = read('Kettlebell One Arm Row', [
        'Stand with your feet shoulder-width apart, holding a kettlebell in '
            'one hand with an overhand grip.',
      ]);
      expect(d.sides, Sides.single);
      expect(d.limbs, Limbs.arms);
    });

    test('alternating, from the name or the steps', () {
      expect(
        read('Dumbbell Standing Alternate Overhead Press', [
          'Stand with your feet shoulder-width apart, holding a dumbbell in '
              'each hand at shoulder level.',
          'Press one dumbbell overhead, fully extending your arm.',
          'Repeat with the other arm.',
          'Continue alternating arms for the desired number of repetitions.',
        ]).sides,
        Sides.alternating,
      );
      expect(
        read('Dumbbell Alternate Biceps Curl', []).sides,
        Sides.alternating,
      );
    });

    test('one leg', () {
      final d = read('One Leg Squat', [
        'Stand with your feet shoulder-width apart.',
        'Extend one leg forward, keeping it off the ground.',
        'Repeat with the other leg.',
      ]);
      expect(d.sides, Sides.single);
      expect(d.limbs, Limbs.legs);
    });

    test('both, when nothing says otherwise', () {
      final d = read('Barbell Curl', ['Stand up straight holding a barbell.']);
      expect(d.sides, Sides.both);
    });

    test('"repeat on the other side" alone is one side at a time', () {
      expect(
        read('Side Lunge Stretch', ['Repeat on the other side.']).sides,
        Sides.both,
      );
    });
  });

  group('position', () {
    test('lying on a decline bench, head low', () {
      final d = read('EZ Barbell Decline Triceps Extension', [
        'Lie on a decline bench with your head lower than your feet and your '
            'feet secured.',
        'Hold the ez barbell with an overhand grip, hands shoulder-width '
            'apart.',
        'Lower the barbell slowly towards your forehead, bending your elbows.',
      ]);
      expect(d.posture, Posture.lyingBack);
      expect(d.bench, BenchAngle.decline);
      expect(d.slowLowering, isTrue);
    });

    test('seated on an incline bench', () {
      final d = read('Dumbbell Incline Curl', [
        'Set an incline bench to a 45-degree angle and sit on it with a '
            'dumbbell in each hand, palms facing forward.',
      ]);
      expect(d.posture, Posture.seated);
      expect(d.bench, BenchAngle.incline);
    });

    test('back on a stability ball', () {
      final d = read('Dumbbell Press On Exercise Ball', [
        'Sit on an exercise ball with your feet flat on the ground and '
            'dumbbells in each hand, resting on your thighs.',
        'Slowly walk your feet forward, rolling the exercise ball until your '
            'lower back is supported on the ball and your knees are at a '
            '90-degree angle.',
      ]);
      expect(d.props, contains(Prop.stabilityBall));
      expect(d.posture, Posture.lyingBack);
    });

    test('face down over a ball', () {
      final d = read('Exercise Ball Back Extension With Hands Behind Head', [
        'Place the stability ball on the ground and lie face down on top of '
            'it with your hips resting on the ball.',
        'Position your feet against a wall or other stable surface for '
            'support.',
      ]);
      expect(d.posture, Posture.lyingFace);
      expect(d.props, contains(Prop.stabilityBall));
    });

    test('a handstand against a wall', () {
      final d = read('Handstand Push-up', [
        'Find a wall and face away from it, standing a few feet away.',
        'Place your hands on the ground shoulder-width apart and kick your '
            'feet up against the wall, coming into a handstand position.',
      ]);
      expect(d.posture, Posture.handstand);
      expect(d.props, contains(Prop.wall));
    });

    test('push-up position on a bosu', () {
      final d = read('Push-up (bosu Ball)', [
        'Place the bosu ball on the ground with the flat side facing up.',
        'Position yourself in a push-up position with your hands on the '
            'outer edges of the bosu ball.',
      ]);
      expect(d.posture, Posture.plank);
      expect(d.props, contains(Prop.bosu));
    });

    test('hanging from a bar', () {
      final d = read('One Arm Chin-up', [
        'Stand facing a pull-up bar with your feet shoulder-width apart.',
        'Reach up and grab the bar with an underhand grip.',
        'Hang from the bar with your arm fully extended.',
      ]);
      expect(d.posture, Posture.hanging);
    });
  });

  test('grip width', () {
    expect(read('Barbell Wide-grip Upright Row', []).grip, Grip.wide);
    expect(read('Barbell Close Grip Bench Press', []).grip, Grip.close);
    expect(read('Barbell Curl', []).grip, Grip.normal);
  });

  test('an explosive move drives up fast', () {
    final d = read('Dumbbell Clean', [
      'Explosively extend your hips, knees and ankles.',
    ]);
    expect(d.explosive, isTrue);
  });
}
