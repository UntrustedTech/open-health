/// Muscle regions drawn on the body map. Each maps to one or more outline
/// "slugs" in the bundled body map (from MuscleMap, MIT).
enum Muscle {
  chest('Chest', ['chest', 'upperChest', 'lowerChest']),
  deltoids('Shoulders', ['deltoids', 'frontDeltoid', 'rearDeltoid']),
  biceps('Biceps', ['biceps']),
  triceps('Triceps', ['triceps']),
  forearms('Forearms', ['forearm']),
  abs('Abs', ['abs', 'upperAbs', 'lowerAbs']),
  obliques('Obliques', ['obliques', 'serratus']),
  trapezius('Traps', ['trapezius', 'upperTrapezius', 'lowerTrapezius']),
  upperBack('Upper Back & Lats', ['upperBack', 'rhomboids', 'rotatorCuff']),
  lowerBack('Lower Back', ['lowerBack']),
  glutes('Glutes', ['gluteal']),
  quadriceps('Quads', ['quadriceps', 'innerQuad', 'outerQuad']),
  hamstrings('Hamstrings', ['hamstring']),
  adductors('Adductors', ['adductors']),
  hipFlexors('Hip Flexors', ['hipFlexors']),
  calves('Calves', ['calves', 'tibialis']),
  neck('Neck', ['neck']);

  const Muscle(this.label, this.slugs);

  final String label;

  /// Body map outline names belonging to this muscle.
  final List<String> slugs;

  static final _bySlug = {
    for (final m in values)
      for (final s in m.slugs) s: m,
  };

  /// The muscle a body map outline belongs to.
  static Muscle? fromSlug(String slug) => _bySlug[slug];

  /// Maps the exercise dataset's muscle names (targets and secondaries).
  static Muscle? fromName(String name) => switch (name.toLowerCase().trim()) {
    'pectorals' || 'chest' || 'upper chest' => chest,
    'delts' || 'deltoids' || 'shoulders' || 'rear deltoids' => deltoids,
    'biceps' || 'brachialis' => biceps,
    'triceps' => triceps,
    'forearms' ||
    'wrists' ||
    'wrist flexors' ||
    'wrist extensors' ||
    'grip muscles' ||
    'hands' => forearms,
    'abs' || 'abdominals' || 'lower abs' || 'core' => abs,
    'obliques' || 'serratus anterior' => obliques,
    'traps' || 'trapezius' || 'levator scapulae' => trapezius,
    'upper back' ||
    'lats' ||
    'latissimus dorsi' ||
    'rhomboids' ||
    'back' ||
    'rotator cuff' => upperBack,
    'lower back' || 'spine' => lowerBack,
    'glutes' || 'abductors' => glutes,
    'quads' || 'quadriceps' => quadriceps,
    'hamstrings' => hamstrings,
    'adductors' || 'inner thighs' || 'groin' => adductors,
    'hip flexors' => hipFlexors,
    'calves' ||
    'soleus' ||
    'shins' ||
    'ankles' ||
    'ankle stabilizers' ||
    'feet' => calves,
    'sternocleidomastoid' || 'neck' => neck,
    _ => null,
  };
}
