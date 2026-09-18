// Production AWS HTTP API (aksdwfbnn5), region ap-south-1, stage $default.
// Override at launch with --dart-define=API_BASE_URL=... (see launch_demo.sh).
const String apiBase = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://aksdwfbnn5.execute-api.ap-south-1.amazonaws.com',
);

const String sosLive         = '$apiBase/sos/live';
const String sosDispatch     = '$apiBase/sos/dispatch';
const String sosResolve      = '$apiBase/sos/resolve';
const String policeSosActive = '$apiBase/police/sos/active';
const String policeSosAccept = '$apiBase/police/sos';   // PATCH /police/sos/{id}/status
const String patrolsList     = '$apiBase/patrols';
const String patrolStatus    = '$apiBase/patrols';
// Live per-zone safety grid (SageMaker-backed). Replaces the retired
// POST /score/refresh, which is no longer called from anywhere.
const String heatmapLive     = '$apiBase/heatmap/live';
const String patrolOptimizer = '$apiBase/patrol/optimize';

const String citizensActive = '$apiBase/police/citizens/active';
const String policeRoute    = '$apiBase/police/route';
const String sosActive      = '$apiBase/police/sos/active';
const String sosCancelled   = '$apiBase/sos/cancelled';
