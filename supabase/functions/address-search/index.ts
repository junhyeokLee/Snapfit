import { corsHeaders, jsonResponse } from '../_shared/cors.ts'

function intParam(value: unknown, fallback: number) {
  const parsed = Number(value)
  return Number.isFinite(parsed) ? Math.trunc(parsed) : fallback
}

function text(value: unknown) {
  return String(value ?? '').trim()
}

function enc(value: string) {
  return encodeURIComponent(value)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return jsonResponse({ error: 'method_not_allowed' }, 405)

  try {
    const body = await req.json().catch(() => ({})) as Record<string, unknown>
    const keyword = text(body.keyword)
    if (keyword.length < 2) {
      return jsonResponse({ error: 'keyword_too_short', message: 'keyword must be at least 2 chars' }, 400)
    }

    const enabled = text(Deno.env.get('SNAPFIT_ADDRESS_JUSO_ENABLED') ?? 'true').toLowerCase() !== 'false'
    const page = Math.max(1, intParam(body.page, 1))
    const countPerPage = Math.max(1, Math.min(50, intParam(body.countPerPage, intParam(Deno.env.get('SNAPFIT_ADDRESS_JUSO_COUNT_PER_PAGE'), 10))))

    if (!enabled) {
      return jsonResponse({ keyword, page, countPerPage, totalCount: 0, items: [] })
    }

    const key = text(Deno.env.get('SNAPFIT_ADDRESS_JUSO_KEY'))
    if (!key) {
      return jsonResponse({ error: 'address_juso_key_not_configured', message: 'SNAPFIT_ADDRESS_JUSO_KEY is required' }, 503)
    }

    const baseUrl = text(Deno.env.get('SNAPFIT_ADDRESS_JUSO_BASE_URL')) || 'https://business.juso.go.kr/addrlink/addrLinkApi.do'
    const historyYn = text(Deno.env.get('SNAPFIT_ADDRESS_JUSO_HISTORY_YN')) || 'N'
    const firstSort = text(Deno.env.get('SNAPFIT_ADDRESS_JUSO_FIRST_SORT')) || 'road'
    const addInfoYn = text(Deno.env.get('SNAPFIT_ADDRESS_JUSO_ADD_INFO_YN')) || 'Y'
    const timeoutMs = Math.max(1000, intParam(Deno.env.get('SNAPFIT_ADDRESS_JUSO_TIMEOUT_MS'), 4000))

    const url = `${baseUrl}?confmKey=${enc(key)}&currentPage=${page}&countPerPage=${countPerPage}&keyword=${enc(keyword)}&resultType=json&hstryYn=${enc(historyYn)}&firstSort=${enc(firstSort)}&addInfoYn=${enc(addInfoYn)}`
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), timeoutMs)
    let response: Response
    try {
      response = await fetch(url, { signal: controller.signal })
    } finally {
      clearTimeout(timer)
    }
    if (!response.ok) {
      return jsonResponse({ error: 'address_api_http_error', status: response.status }, 502)
    }

    const data = await response.json()
    const results = data?.results ?? {}
    const common = results?.common ?? {}
    const errorCode = String(common?.errorCode ?? '0')
    if (errorCode !== '0') {
      return jsonResponse({ error: 'address_api_error', message: String(common?.errorMessage ?? '주소 검색 실패'), errorCode }, 502)
    }

    const juso = Array.isArray(results?.juso) ? results.juso : []
    const items = juso.map((node: Record<string, unknown>) => ({
      zipCode: String(node.zipNo ?? ''),
      roadAddress: String(node.roadAddr ?? ''),
      roadAddressPart1: String(node.roadAddrPart1 ?? ''),
      roadAddressPart2: String(node.roadAddrPart2 ?? ''),
      jibunAddress: String(node.jibunAddr ?? ''),
      englishAddress: String(node.engAddr ?? ''),
      buildingName: String(node.bdNm ?? ''),
      hemdName: String(node.hemdNm ?? ''),
    }))

    return jsonResponse({
      keyword,
      page,
      countPerPage,
      totalCount: intParam(common?.totalCount, items.length),
      items,
    })
  } catch (e) {
    const message = String(e?.message ?? e)
    const isAbort = message.toLowerCase().includes('abort')
    return jsonResponse({ error: isAbort ? 'address_api_timeout' : message }, isAbort ? 504 : 500)
  }
})
