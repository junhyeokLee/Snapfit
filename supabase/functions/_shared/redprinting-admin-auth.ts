export type VerifiedUserLookup = (req: Request) => Promise<{
  id?: unknown; app_metadata?: Record<string, unknown>
} | null>

export class RedprintingAdminAuthError extends Error {
  readonly code: string
  readonly status: number
  constructor(code: string, status: number) { super(code); this.code = code; this.status = status }
}

// The injectable lookup is Supabase Auth getUser in production, never locally
// decoded JWT claims. No environment key, header key, or request body authorizes
// this endpoint. Database access happens only after this function completes.
export async function assertRedprintingAdmin(req: Request, verifiedUser: VerifiedUserLookup): Promise<string> {
  const authorization = req.headers.get('Authorization') ?? ''
  if (!/^Bearer [^\s]+$/i.test(authorization)) throw new RedprintingAdminAuthError('authentication_required', 401)
  let user: Awaited<ReturnType<VerifiedUserLookup>>
  try { user = await verifiedUser(req) }
  catch { throw new RedprintingAdminAuthError('invalid_session', 401) }
  if (!user || typeof user.id !== 'string' || !user.id.trim()) throw new RedprintingAdminAuthError('invalid_session', 401)
  if (user.app_metadata?.role !== 'admin') throw new RedprintingAdminAuthError('forbidden', 403)
  return user.id
}
