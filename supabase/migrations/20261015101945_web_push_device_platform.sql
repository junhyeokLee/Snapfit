-- Browser tokens use the same authenticated registration RPC and owner RLS.
-- This does not enable delivery, issue credentials, or change native devices.
alter table public.push_devices
  drop constraint push_devices_platform_check;
alter table public.push_devices
  add constraint push_devices_platform_check
  check (platform in ('android', 'iOS', 'macOS', 'web'));
