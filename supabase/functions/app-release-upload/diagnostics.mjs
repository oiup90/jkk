// Only these fixed identifiers and an HTTP status may enter publication logs.
// Exception messages, SDK responses and URLs can contain credentials.
const stages = new Set([
  'authorize', 'sign_upload', 'public_base', 'copy_upload', 'staging_head',
  'sign_download', 'validator_request', 'validator_result', 'release_copy',
  'reauthorize', 'publish', 'publish_rpc',
]);

function httpStatus(value) {
  return Number.isInteger(value) && value >= 100 && value <= 599 ? value : null;
}

export class StageFailure extends Error {
  /** @param {string} stage @param {unknown} [status] */
  constructor(stage, status = null) {
    super('App release operation failed');
    this.stage = stages.has(stage) ? stage : 'unknown';
    this.httpStatus = httpStatus(status);
  }
}

export async function runStage(stage, operation) {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof StageFailure) throw error;
    throw new StageFailure(stage, error?.$metadata?.httpStatusCode);
  }
}

export function failureLog(error) {
  return JSON.stringify({
    event: 'app_release_failure',
    stage: error instanceof StageFailure && stages.has(error.stage) ? error.stage : 'unknown',
    httpStatus: error instanceof StageFailure ? httpStatus(error.httpStatus) : null,
  });
}
