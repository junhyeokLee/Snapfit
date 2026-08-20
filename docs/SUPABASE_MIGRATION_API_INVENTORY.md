# SnapFit REST API inventory for Supabase migration

Total endpoint usages: 29

## `lib/features/album/data/api/album_api.dart`
- `POST` `/api/albums`
- `GET` `/api/albums/{albumId}`
- `GET` `/api/albums`
- `PUT` `/api/albums/{albumId}`
- `DELETE` `/api/albums/{albumId}`
- `PATCH` `/api/albums/reorder`
- `POST` `/api/albums/{albumId}/lock`
- `POST` `/api/albums/{albumId}/unlock`

## `lib/features/album/data/api/album_member_api.dart`
- `POST` `/api/albums/{albumId}/members/invite`
- `GET` `/api/invites/{token}`
- `POST` `/api/invites/{token}/accept`
- `GET` `/api/albums/{albumId}/members`

## `lib/features/album/presentation/providers/design_template_catalog_provider.dart`
- `GET` `/api/templates`

## `lib/features/auth/data/api/auth_api.dart`
- `POST` `/api/auth/login/kakao`
- `POST` `/api/auth/login/google`
- `POST` `/api/auth/refresh`
- `POST` `/api/auth/profile`
- `DELETE` `/api/auth/account`
- `POST` `/api/auth/consents`

## `lib/features/billing/data/billing_repository.dart`
- `GET` `/api/billing/plans`
- `POST` `/api/billing/$orderId/cancel`

## `lib/features/notification/data/notification_repository.dart`
- `GET` `/api/notifications/policy`

## `lib/features/profile/data/order_repository.dart`
- `POST` `/api/orders/$orderId/advance`
- `POST` `/api/orders/$orderId/payment/confirm`

## `lib/features/store/data/api/template_api.dart`
- `GET` `/api/templates`
- `GET` `/api/templates/summary`
- `GET` `/api/templates/{id}`
- `POST` `/api/templates/{id}/like`
- `POST` `/api/templates/{id}/use`
