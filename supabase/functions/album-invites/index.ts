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
  const supabase = adminClient()
  try {
    const body = await req.json().catch(() => ({}))
    const action = String(body.action ?? '').trim()

    if (action === 'info') {
      const rawToken = String(body.token ?? '').trim()
      if (!rawToken) return jsonResponse({ error: 'token_required' }, 400)
      const { data: invite, error } = await supabase
        .from('album_invites')
        .select('token,album_id,role,created_by,expires_at,accepted_at')
        .eq('token', rawToken)
        .maybeSingle()
      if (error) throw error
      if (!invite) return jsonResponse({ error: 'invite_not_found' }, 404)
      if (invite.expires_at && new Date(invite.expires_at).getTime() < Date.now()) {
        return jsonResponse({ error: 'invite_expired' }, 410)
      }
      const { data: album } = await supabase
        .from('albums')
        .select('title')
        .eq('id', invite.album_id)
        .maybeSingle()
      const { data: inviter } = invite.created_by
        ? await supabase.from('profiles').select('name').eq('id', invite.created_by).maybeSingle()
        : { data: null }
      return jsonResponse({
        albumId: invite.album_id,
        albumTitle: album?.title ?? '앨범',
        inviterName: inviter?.name ?? 'SnapFit 사용자',
        role: invite.role ?? 'EDITOR',
      })
    }

    const user = await getUser(req)

    if (action === 'create') {
      const albumId = Number(body.albumId)
      const role = String(body.role ?? 'EDITOR').toUpperCase()
      if (!albumId || !['EDITOR', 'VIEWER'].includes(role)) return jsonResponse({ error: 'invalid_album_or_role' }, 400)
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
      return jsonResponse({ albumId, token: rawToken, link: `snapfit://invite?token=${rawToken}` })
    }

    if (action === 'accept') {
      const rawToken = String(body.token ?? '').trim()
      if (!rawToken) return jsonResponse({ error: 'token_required' }, 400)
      const { data: invite, error } = await supabase
        .from('album_invites')
        .select('token,album_id,role,expires_at,accepted_at')
        .eq('token', rawToken)
        .maybeSingle()
      if (error) throw error
      if (!invite) return jsonResponse({ error: 'invite_not_found' }, 404)
      if (invite.expires_at && new Date(invite.expires_at).getTime() < Date.now()) return jsonResponse({ error: 'invite_expired' }, 410)
      await supabase.from('album_members').upsert({
        album_id: invite.album_id,
        user_id: user.id,
        role: invite.role ?? 'EDITOR',
        status: 'ACCEPTED',
        invited_by: null,
        invite_token: rawToken,
      })
      await supabase.from('album_invites').update({ accepted_by: user.id, accepted_at: new Date().toISOString() }).eq('token', rawToken)
      return jsonResponse({ albumId: invite.album_id, role: invite.role ?? 'EDITOR', success: true })
    }

    return jsonResponse({ error: 'unknown_action' }, 400)
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: String(e?.message ?? e) }, String(e?.message ?? '').includes('Unauthorized') ? 401 : 500)
  }
})
