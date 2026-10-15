import { RedprintingAdminAuthError, type VerifiedUserLookup } from './redprinting-admin-auth.ts'

export { RedprintingAdminAuthError as PrintWorkerAuthError } from './redprinting-admin-auth.ts'
export type PrintWorkerUserLookup = VerifiedUserLookup

export type PrintWorkerActor = { id: string; role: 'admin' | 'print_worker' }

/**
 * Used behind the platform's signed-JWT gateway. Server Auth.getUser verifies
 * the current account; caller-supplied user IDs or decoded JWT claims never
 * authorize work. Credentials are neither returned nor copied to job records.
 */
export async function assertPrintWorker(request: Request, getUser: VerifiedUserLookup): Promise<PrintWorkerActor> {
  if (!/^Bearer [^\s]+$/i.test(request.headers.get('Authorization') ?? '')) {
    throw new RedprintingAdminAuthError('authentication_required', 401)
  }
  let user: Awaited<ReturnType<VerifiedUserLookup>>
  try { user = await getUser(request) }
  catch { throw new RedprintingAdminAuthError('invalid_session', 401) }
  if (!user || typeof user.id !== 'string' || !user.id.trim()) {
    throw new RedprintingAdminAuthError('invalid_session', 401)
  }
  const role = user.app_metadata?.role
  if (role !== 'admin' && role !== 'print_worker') {
    throw new RedprintingAdminAuthError('forbidden', 403)
  }
  return { id: user.id, role }
}
