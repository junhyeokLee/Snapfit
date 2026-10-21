import { corsHeaders } from './cors.ts'

type ReviewRow = { id: number | string }
type ReviewUser = { id: string; email?: string }
export type AccountDeletionReviewDependencies = {
  getUser(request: Request): Promise<ReviewUser>
  findOpenRequest(owner: string): Promise<ReviewRow | null>
  insertRequest(owner: string, email: string | null): Promise<ReviewRow>
}

const contactEmail = 'junhyeoklee616@gmail.com'
function response(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), { status, headers: {
    ...corsHeaders, 'Content-Type': 'application/json', 'Cache-Control': 'no-store',
  } })
}
function accepted(row: ReviewRow, existing: boolean): Response {
  if (!/^[1-9][0-9]{0,18}$/.test(String(row.id))) throw new Error('invalid_review_reference')
  return response({ requestAccepted: true, accountDeleted: false,
    alreadyRequested: existing, reference: `DEL-${row.id}`,
    message: '계정·개인정보 삭제 요청을 접수했습니다. 담당자 확인 후 처리하며 지금 계정이나 사진이 삭제된 것은 아닙니다.',
  }, 202)
}

/** No destructive operation is exposed by this handler. Financial records,
 * shared content and stored files require a separately reviewed removal plan. */
export function createAccountDeletionReviewHandler(deps: AccountDeletionReviewDependencies) {
  return async (request: Request): Promise<Response> => {
    if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
    if (request.method !== 'POST') return response({ error: 'method_not_allowed' }, 405)
    if (!/^Bearer\s+\S+$/i.test(request.headers.get('Authorization') ?? '')) {
      return response({ error: 'unauthorized', accountDeleted: false, requestAccepted: false }, 401)
    }
    try {
      const user = await deps.getUser(request)
      const body = await request.json().catch(() => null)
      // Old clients interpret a 2xx response as an account deletion and log out.
      // They must get an explicit failure, never a false deletion confirmation.
      if (body == null || typeof body !== 'object' || Array.isArray(body) ||
          Object.keys(body).length !== 1 || body.action !== 'REQUEST_REVIEW') {
        return response({ error: 'account_deletion_review_required', accountDeleted: false,
          requestAccepted: false, contactEmail,
          message: '계정 설정에서 삭제 요청을 접수하거나 문의 이메일로 연락해 주세요. 자동 즉시 삭제는 제공하지 않습니다.',
        }, 409)
      }
      const existing = await deps.findOpenRequest(user.id)
      if (existing) return accepted(existing, true)
      try {
        return accepted(await deps.insertRequest(user.id, user.email ?? null), false)
      } catch (error) {
        // The partial unique index protects simultaneous tabs and retries.
        if (error && typeof error === 'object' && 'code' in error && error.code === '23505') {
          const sameRequest = await deps.findOpenRequest(user.id)
          if (sameRequest) return accepted(sameRequest, true)
        }
        throw error
      }
    } catch (error) {
      const unauthorized = error instanceof Error && error.message === 'Unauthorized'
      return response({ error: unauthorized ? 'unauthorized' : 'account_deletion_request_unavailable',
        requestAccepted: false, accountDeleted: false, contactEmail,
        message: unauthorized ? '다시 로그인한 뒤 요청해 주세요.' : '삭제 요청을 접수하지 못했습니다. 잠시 후 다시 시도하거나 문의 이메일로 연락해 주세요.',
      }, unauthorized ? 401 : 503)
    }
  }
}
