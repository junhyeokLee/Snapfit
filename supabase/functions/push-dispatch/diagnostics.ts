export type DispatchStage = 'credential_parse' | 'credential_import_key' | 'credential_sign'
  | 'oauth' | 'admin_client' | 'cleanup' | 'claim' | 'delivery';

// Only controlled codes and numeric HTTP statuses cross the logging boundary.
// Provider messages, SQL details, credentials, recipients and payloads never do.
export class DispatchError extends Error {
  readonly stage: DispatchStage;
  readonly code: string;
  readonly httpStatus?: number;
  constructor(stage: DispatchStage, code: string, httpStatus?: number) {
    super(code);
    this.name = 'DispatchError';
    this.stage = stage;
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

export function dispatchDiagnostic(error: unknown, fallback: DispatchStage) {
  if (error instanceof DispatchError) {
    return { stage: error.stage, code: error.code,
      ...(error.httpStatus === undefined ? {} : { http_status: error.httpStatus }) };
  }
  const code = error && typeof error === 'object' && 'code' in error ? error.code : undefined;
  return { stage: fallback, code: 'operation_failed',
    ...(typeof code === 'string' && /^(?:[0-9A-Z]{5}|PGRST\d{3})$/.test(code) ? { database_code: code } : {}) };
}
