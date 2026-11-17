-- Run in Supabase SQL Editor AFTER schema.sql, in a test project.
-- Everything is rolled back, including auth users and records.
begin;
create or replace function public.bg_test_assert(ok boolean,message text) returns void language plpgsql security invoker as $$ begin if ok is distinct from true then raise exception 'FAIL: %',message; end if; end $$;
grant execute on function public.bg_test_assert(boolean,text) to authenticated,anon;
insert into auth.users(id,email) values
 ('10000000-0000-4000-8000-000000000001','bg-admin-test@example.invalid'),
 ('10000000-0000-4000-8000-000000000002','bg-editor-test@example.invalid'),
 ('10000000-0000-4000-8000-000000000003','bg-viewer-test@example.invalid'),
 ('10000000-0000-4000-8000-000000000004','bg-inactive-test@example.invalid');
update public.bg_profiles set active=true,role='admin' where id='10000000-0000-4000-8000-000000000001';
update public.bg_profiles set active=true,role='editor' where id='10000000-0000-4000-8000-000000000002';
update public.bg_profiles set active=true,role='viewer' where id='10000000-0000-4000-8000-000000000003';
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
insert into public.bg_assets(id,org_id,code,name,country,city,asset_type,portfolio_status,occupancy_permit)
 values('20000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','RLS-TEST','RLS test','RS','Šabac','office','portfolio','unknown');
select public.bg_test_assert((select version=1 from public.bg_assets where code='RLS-TEST'),'editor inserts asset');
update public.bg_assets set notes='Test concurrency' where code='RLS-TEST' and version=1;
select public.bg_test_assert((select version=2 from public.bg_assets where code='RLS-TEST'),'version increments');
update public.bg_assets set notes='Stale overwrite' where code='RLS-TEST' and version=1;
select public.bg_test_assert((select notes='Test concurrency' from public.bg_assets where code='RLS-TEST'),'stale update does not overwrite');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
select public.bg_test_assert((select count(*)=1 from public.bg_assets where code='RLS-TEST'),'viewer reads');
update public.bg_assets set notes='Unauthorized' where code='RLS-TEST';
select public.bg_test_assert((select notes='Test concurrency' from public.bg_assets where code='RLS-TEST'),'viewer cannot update');
delete from public.bg_assets where code='RLS-TEST';
select public.bg_test_assert((select count(*)=1 from public.bg_assets where code='RLS-TEST'),'viewer cannot delete');
do $$ begin
 begin
  insert into public.bg_assets(org_id,code,name,country,city,asset_type,portfolio_status,occupancy_permit) values('00000000-0000-4000-8000-000000000001','BAD','BAD','RS','Šabac','office','portfolio','unknown');
  raise exception 'FAIL: viewer insert unexpectedly allowed';
 exception when insufficient_privilege then null; end;
 begin
  perform public.bg_manage_user('10000000-0000-4000-8000-000000000003','admin',true,'Escalation');
  raise exception 'FAIL: viewer role escalation unexpectedly allowed';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000004',true);
select public.bg_test_assert((select count(*)=0 from public.bg_assets),'inactive account reads no assets');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select public.bg_test_assert((select count(*)>=1 from public.bg_audit_log where entity_id='20000000-0000-4000-8000-000000000001'),'server audit exists');
delete from public.bg_assets where code='RLS-TEST';
select public.bg_test_assert((select count(*)=0 from public.bg_assets where code='RLS-TEST'),'admin can delete');
reset role;
set local role anon;
do $$ begin
 begin perform count(*) from public.bg_assets; raise exception 'FAIL: anonymous table access';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'RLS checks passed; rolling back all test data' as result;
rollback;
