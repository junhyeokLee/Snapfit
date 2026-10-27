import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

function token() {
  const bytes = new Uint8Array(24)
  crypto.getRandomValues(bytes)
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)
  try {
    const body = await req.json().catch(() => ({}))
    if (!body || typeof body !== 'object' || Array.isArray(body)) return jsonResponse({ error: 'invalid_request' }, 400)
    const action = String(body.action ?? '').trim()
    if (!['info', 'create', 'accept'].includes(action)) return jsonResponse({ error: 'unknown_action' }, 400)
    const rawToken = typeof body.token === 'string' ? body.token : ''
    if (action !== 'create' && !/^[A-Za-z0-9_-]{1,256}$/.test(rawToken)) return jsonResponse({ error: 'token_required' }, 400)
    const supabase = adminClient()

    if (action === 'info') {
      const { data: invite, error } = await supabase
        .from('album_invites')
        .select('token,album_id,role,created_by,expires_at,accepted_at,accepted_by')
        .eq('token', rawToken)
        .maybeSingle()
      if (error) throw error
      if (!invite) return jsonResponse({ error: 'invite_not_found' }, 404)
      let currentRole = invite.role
      if (invite.accepted_at) {
        // The same current member may recover a committed acceptance after a lost
        // response/restart. A consumed link is never reusable by a removed member.
        const current = await getUser(req).catch(() => null)
        if (!current || current.id !== invite.accepted_by) return jsonResponse({ error: 'invite_used' }, 409)
        const { data: membership, error: memberError } = await supabase.from('album_members')
          .select('role,status').eq('album_id', invite.album_id).eq('user_id', current.id).maybeSingle()
        if (memberError) throw memberError
        if (membership?.status !== 'ACCEPTED') return jsonResponse({ error: 'invite_used' }, 409)
        currentRole = membership.role === 'OWNER' ? 'VIEWER' : membership.role
      }
      if (!invite.accepted_at && invite.expires_at && new Date(invite.expires_at).getTime() <= Date.now()) {
        return jsonResponse({ error: 'invite_expired' }, 410)
      }
      const { data: album, error: albumError } = await supabase
        .from('albums')
        .select('title')
        .eq('id', invite.album_id)
        .maybeSingle()
      if (albumError) throw albumError
      if (!album) return jsonResponse({ error: 'invite_not_found' }, 404)
      const { data: inviter, error: inviterError } = invite.created_by
        ? await supabase.from('social_profiles').select('display_name').eq('user_id', invite.created_by).maybeSingle()
        : { data: null, error: null }
      if (inviterError) throw inviterError
      return jsonResponse({
        albumId: invite.album_id,
        albumTitle: album?.title ?? '앨범',
        inviterName: inviter?.display_name?.trim() || 'SnapFit 사용자',
        role: currentRole === 'EDITOR' ? 'EDITOR' : 'VIEWER',
      })
    }

    const user = await getUser(req)
    if (body.expectedActorId !== undefined) {
      if (typeof body.expectedActorId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(body.expectedActorId)) {
        return jsonResponse({ error: 'invalid_expected_actor' }, 400)
      }
      if (body.expectedActorId.toLowerCase() !== user.id.toLowerCase()) return jsonResponse({ error: 'album_editor_session_changed' }, 403)
    }

    if (action === 'create') {
      const albumId = Number(body.albumId)
      const role = String(body.role ?? 'EDITOR').toUpperCase()
      if (!Number.isSafeInteger(albumId) || albumId <= 0 || !['EDITOR', 'VIEWER'].includes(role)) return jsonResponse({ error: 'invalid_album_or_role' }, 400)
      const { data: album, error: albumError } = await supabase
        .from('albums')
        .select('id,owner_id')
        .eq('id', albumId)
        .maybeSingle()
      if (albumError) throw albumError
      if (!album || album.owner_id !== user.id) return jsonResponse({ error: 'forbidden' }, 403)
      const rawToken = token()
      const expiresAt = new Date(Date.now() + 14 * 24 * 60 * 60_000).toISOString()
      const { error } = await supabase.from('album_invites').insert({
        token: rawToken,
        album_id: albumId,
        created_by: user.id,
        role,
        expires_at: expiresAt,
      })
      if (error) throw error
      return jsonResponse({ albumId, token: rawToken, link: `https://snapfit-c719d.web.app/invite/${rawToken}` })
    }

    if (action === 'accept') {
      const { data, error } = await supabase.rpc('accept_album_invite', {
        p_token: rawToken,
        p_user_id: user.id,
      })
      if (error) throw error
      if (data?.error) return jsonResponse({ error: data.error }, data.status ?? 500)
      if (!data?.success || !data?.albumId) throw new Error('Invalid acceptance result')
      return jsonResponse(data)
    }

    return jsonResponse({ error: 'unknown_action' }, 400)
  } catch (e) {
    const unauthorized = e instanceof Error && e.message === 'Unauthorized'
    return jsonResponse({ error: unauthorized ? 'unauthorized' : 'invite_unavailable' }, unauthorized ? 401 : 500)
  }
})
