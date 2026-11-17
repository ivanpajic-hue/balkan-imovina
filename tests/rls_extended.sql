-- Additional isolated/test-project checks. Run after schema.sql. All changes roll back.
begin;
create or replace function public.bg_test_assert(ok boolean,message text) returns void language plpgsql security invoker as $$ begin if ok is distinct from true then raise exception 'FAIL: %',message; end if; end $$;
grant execute on function public.bg_test_assert(boolean,text) to authenticated,anon;
insert into public.bg_organizations(id,name) values('90000000-0000-4000-8000-000000000002','Other tenant – TEST');
insert into public.bg_options(org_id,kind,code,label,sort_order,active,flags)
 select '90000000-0000-4000-8000-000000000002',kind,code,label,sort_order,active,flags from public.bg_options where org_id='00000000-0000-4000-8000-000000000001';
insert into auth.users(id,email) values
 ('11000000-0000-4000-8000-000000000001','ext-admin@example.invalid'),
 ('11000000-0000-4000-8000-000000000002','ext-editor@example.invalid'),
 ('11000000-0000-4000-8000-000000000003','ext-viewer@example.invalid'),
 ('11000000-0000-4000-8000-000000000004','ext-other-admin@example.invalid');
update public.bg_profiles set active=true,role='admin' where id='11000000-0000-4000-8000-000000000001';
update public.bg_profiles set active=true,role='editor' where id='11000000-0000-4000-8000-000000000002';
update public.bg_profiles set active=true,role='viewer' where id='11000000-0000-4000-8000-000000000003';
update public.bg_profiles set active=true,role='admin',org_id='90000000-0000-4000-8000-000000000002' where id='11000000-0000-4000-8000-000000000004';
insert into public.bg_assets(id,org_id,code,name,country,city,asset_type,portfolio_status,occupancy_permit) values
 ('21000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','EXT-OWN','Own fixture','RS','Šabac','office','portfolio','unknown'),
 ('21000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000002','EXT-OTHER','Other fixture','RS','Šabac','office','portfolio','unknown');
insert into public.bg_owners(id,org_id,code,full_name,kind,country) values
 ('31000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000002','EXT-OWNER','Other owner','legal','RS');
insert into storage.objects(bucket_id,name) values
 ('bg-estate-documents','00000000-0000-4000-8000-000000000001/21000000-0000-4000-8000-000000000001/rls-own.pdf'),
 ('bg-estate-documents','90000000-0000-4000-8000-000000000002/21000000-0000-4000-8000-000000000002/rls-other.pdf');
set local role authenticated;
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000003',true);
select public.bg_test_assert((select count(*)=0 from public.bg_assets where code='EXT-OTHER'),'other tenant assets hidden');
select public.bg_test_assert((select count(*)=0 from public.bg_owners where code='EXT-OWNER'),'other tenant owners hidden');
select public.bg_test_assert((select count(*)=1 from storage.objects where name like '%/rls-own.pdf'),'viewer reads own private file');
select public.bg_test_assert((select count(*)=0 from storage.objects where name like '%/rls-other.pdf'),'viewer cannot read other private file');
select public.bg_test_assert((select count(*)=0 from public.bg_audit_log),'viewer cannot read audit log');
do $$ begin
 begin
  update public.bg_profiles set role='admin' where id=auth.uid();
  raise exception 'FAIL: direct self escalation allowed';
 exception when insufficient_privilege then null; end;
 begin
  insert into storage.objects(bucket_id,name) values('bg-estate-documents','00000000-0000-4000-8000-000000000001/21000000-0000-4000-8000-000000000001/viewer-write.pdf');
  raise exception 'FAIL: viewer storage insert allowed';
 exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000002',true);
do $$ begin
 begin
  insert into public.bg_assets(org_id,code,name,country,city,asset_type,portfolio_status,occupancy_permit) values('90000000-0000-4000-8000-000000000002','BAD-OTHER','BAD','RS','Šabac','office','portfolio','unknown');
  raise exception 'FAIL: cross tenant insert allowed';
 exception when insufficient_privilege then null; end;
 begin
  insert into public.bg_ownerships(org_id,asset_id,owner_id,numerator,denominator) values('00000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001','31000000-0000-4000-8000-000000000002',1,1);
  raise exception 'FAIL: cross tenant owner link allowed';
 exception when foreign_key_violation then null; end;
 begin
  insert into public.bg_actions(org_id,asset_id,position,description,status) values('00000000-0000-4000-8000-000000000001','21000000-0000-4000-8000-000000000001',6,'Bad sixth step','not_started');
  raise exception 'FAIL: sixth action allowed';
 exception when check_violation then null; end;
 begin
  insert into storage.objects(bucket_id,name) values('bg-estate-documents','90000000-0000-4000-8000-000000000002/21000000-0000-4000-8000-000000000002/editor-cross.pdf');
  raise exception 'FAIL: cross tenant storage insert allowed';
 exception when insufficient_privilege then null; end;
end $$;
insert into storage.objects(bucket_id,name) values('bg-estate-documents','00000000-0000-4000-8000-000000000001/21000000-0000-4000-8000-000000000001/editor-own.pdf');
select public.bg_test_assert((select count(*)=1 from storage.objects where name like '%/editor-own.pdf'),'editor inserts own private file');
delete from public.bg_assets where code='EXT-OWN';
select public.bg_test_assert((select count(*)=1 from public.bg_assets where code='EXT-OWN'),'editor cannot delete asset');
select set_config('request.jwt.claim.sub','11000000-0000-4000-8000-000000000004',true);
do $$ declare blocked boolean:=false; begin
 begin perform public.bg_manage_user('11000000-0000-4000-8000-000000000004','viewer',false,'Other admin');
 exception when others then
  if sqlerrm like 'Mora ostati najmanje jedan aktivan administrator%' then blocked:=true; else raise; end if;
 end;
 if not blocked then raise exception 'FAIL: last admin removed'; end if;
end $$;
select public.bg_test_assert((select active and role='admin' from public.bg_profiles where id=auth.uid()),'last administrator stays active');
reset role;
select 'Extended RLS checks passed; rolling back all test data' as result;
rollback;
