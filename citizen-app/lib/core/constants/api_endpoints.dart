/// API Endpoints for Rakshak Sentinel
import '../../config/api.dart' show apiBase;

class ApiEndpoints {
  ApiEndpoints._();

  // Single source of truth for the backend host, shared with config/api.dart so
  // --dart-define=API_BASE_URL overrides every endpoint in the app, not just the
  // ones that happened to read the config file.
  static const _base = apiBase;

  static const predict  = '$_base/predict';
  static const sos      = '$_base/sos';
  static const user     = '$_base/user';
  static const events   = '$_base/incidents';

  // Gemma/Ollama layer is out of scope for the SIH demo. These now point at the
  // AWS base; the callers already fall back to a canned bilingual message on any
  // non-200, so Suraksha check-in/escalate still works without a Gemma service.
  static const _gemmaBase = _base;
  static const gemmaCheckin  = '$_gemmaBase/gemma/checkin';
  static const gemmaEscalate = '$_gemmaBase/gemma/escalate';
}
