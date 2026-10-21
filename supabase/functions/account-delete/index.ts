import { adminClient, getUser } from '../_shared/supabase.ts'
import { createAccountDeletionReviewHandler } from '../_shared/account-deletion-review.ts'

Deno.serve(createAccountDeletionReviewHandler({
  getUser,
  findOpenRequest: async owner => {
    const { data, error } = await adminClient().from('support_inquiries')
      .select('id').eq('user_id', owner).eq('category', 'ACCOUNT_DELETION')
      .in('status', ['OPEN', 'IN_PROGRESS']).order('created_at', { ascending: false })
      .limit(1).maybeSingle()
    if (error) throw error
    return data
  },
  insertRequest: async (owner, email) => {
    const { data, error } = await adminClient().from('support_inquiries').insert({
      user_id: owner, email, category: 'ACCOUNT_DELETION', status: 'OPEN',
      subject: '계정·개인정보 삭제 요청',
      message: '계정 설정에서 본인이 계정·개인정보 삭제 검토를 요청했습니다. '
        + '접수 시 계정·프로필·앨범·사진·거래 기록은 삭제하지 않았고 로그인 상태를 유지했습니다. '
        + '처리 전 본인 확인, 주문·결제·법정 보관 기록, 공유 앨범과 저장소 파일의 소유·참조 범위를 확인하고 처리 결과를 안내해야 합니다.',
    }).select('id').single()
    if (error) throw error
    if (!data) throw new Error('review_request_missing')
    return data
  },
}))
