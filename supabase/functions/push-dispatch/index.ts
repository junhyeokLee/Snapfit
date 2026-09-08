import { adminClient } from '../_shared/supabase.ts';
import { createPushDispatchHandler } from './handler.ts';

Deno.serve(createPushDispatchHandler({ env: (name) => Deno.env.get(name), adminClient }));
