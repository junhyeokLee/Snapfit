import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)

  try {
    const user = await getUser(req)
    const supabase = adminClient()

    // Best-effort app data cleanup before deleting auth.users.
    await supabase.from('profiles').delete().eq('id', user.id)
    const { error } = await supabase.auth.admin.deleteUser(user.id)
    if (error) throw error

    return jsonResponse({ success: true })
  } catch (e) {
    console.error(e)
    const message = String(e?.message ?? e)
    return jsonResponse(
      { error: message },
      message.includes('Unauthorized') ? 401 : 500,
    )
  }
})
