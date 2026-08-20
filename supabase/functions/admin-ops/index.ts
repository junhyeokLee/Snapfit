import { corsHeaders, jsonResponse } from '../_shared/cors.ts'
import { adminClient, getUser } from '../_shared/supabase.ts'

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  try {
    const user = await getUser(req)
    if (user.app_metadata?.role !== 'admin') return jsonResponse({ error: 'forbidden' }, 403)
    const supabase = adminClient()
    const [orders, support] = await Promise.all([
      supabase.from('orders').select('status', { count: 'exact', head: false }),
      supabase.from('support_inquiries').select('status', { count: 'exact', head: false }),
    ])
    return jsonResponse({
      orders: orders.data ?? [],
      supportInquiries: support.data ?? [],
    })
  } catch (e) {
    console.error(e)
    return jsonResponse({ error: String(e?.message ?? e) }, String(e?.message ?? '').includes('Unauthorized') ? 401 : 500)
  }
})
