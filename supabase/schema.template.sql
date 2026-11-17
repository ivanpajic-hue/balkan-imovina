-- Balkan Imovina 1.1.0 | Initial migration. Run as postgres in Supabase SQL Editor.
-- Auth users are provisioned separately. No browser service_role/secret key is used.
begin;
create schema if not exists bg_private;
revoke all on schema bg_private from public;
grant usage on schema bg_private to authenticated;

create table if not exists public.bg_organizations (
 id uuid primary key default gen_random_uuid(), name text not null,
 warning_days integer not null default 30 check(warning_days between 0 and 365)
);
insert into public.bg_organizations(id,name) values ('00000000-0000-4000-8000-000000000001','Balkan grupa') on conflict(id) do nothing;
create table if not exists public.bg_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 org_id uuid not null references public.bg_organizations(id),
 email text not null, display_name text not null default '',
 role text not null default 'viewer' check(role in ('admin','editor','viewer')),
 active boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create or replace function bg_private.actor_org() returns uuid language sql stable security definer set search_path='' as $$
 select org_id from public.bg_profiles where id=auth.uid() and active;
$$;
create or replace function bg_private.actor_role() returns text language sql stable security definer set search_path='' as $$
 select role from public.bg_profiles where id=auth.uid() and active;
$$;
revoke all on function bg_private.actor_org(), bg_private.actor_role() from public,anon;
grant execute on function bg_private.actor_org(), bg_private.actor_role() to authenticated;

create table if not exists public.bg_options (
 id uuid primary key default gen_random_uuid(), org_id uuid not null references public.bg_organizations(id),
 kind text not null, code text not null check(code ~ '^[a-zA-Z0-9_-]{1,80}$'), label text not null,
 sort_order integer not null default 0, active boolean not null default true,
 flags jsonb not null default '{}'::jsonb check(jsonb_typeof(flags)='object'),
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid, updated_by uuid,
 unique(org_id,kind,code)
);
create table if not exists public.bg_owners (
 id uuid primary key default gen_random_uuid(), org_id uuid not null references public.bg_organizations(id),
 code text not null, full_name text not null, kind text not null check(kind in ('legal','natural')),
 country text not null default 'RS', tax_number text, registration_number text,
 within_group boolean not null default true, active boolean not null default true,
 contact_name text, phone text, email text, address text, notes text,
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid, updated_by uuid,
 unique(org_id,code), unique(id,org_id), check(length(trim(code))>0 and length(trim(full_name))>0)
);
create table if not exists public.bg_assets (
 id uuid primary key default gen_random_uuid(), org_id uuid not null references public.bg_organizations(id),
 code text not null, name text not null, country text not null default 'RS', city text not null,
 municipality text, address text, asset_type text not null, lead_owner_id uuid,
 portfolio_status text not null default 'portfolio', usage_status text,
 occupancy_permit text not null default 'unknown', priority text default 'medium', responsible text, complex_name text,
 cadastral_municipality text, parcel_number text, building_number text, unit_number text, ln_number text,
 land_area numeric(18,2) check(land_area>=0), net_area numeric(18,2) check(net_area>=0), gross_area numeric(18,2) check(gross_area>=0),
 registration_status text, construction_permit text, proceedings_status text, encumbrances text, encumbrance_details text,
 acquisition_basis text, acquired_on date, currency text check(currency in ('EUR','RSD')),
 purchase_value numeric(18,2) check(purchase_value between 0 and 1000000000000),
 market_value numeric(18,2) check(market_value between 0 and 1000000000000), valuation_date date,
 annual_tax numeric(18,2) check(annual_tax between 0 and 1000000000000),
 monthly_rent numeric(18,2) check(monthly_rent between 0 and 1000000000000),
 monthly_maintenance numeric(18,2) check(monthly_maintenance between 0 and 1000000000000),
 tenant text, lease_end date, documents_url text check(documents_url is null or documents_url ~ '^https://'), reviewed_on date, notes text,
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid, updated_by uuid,
 unique(org_id,code), unique(id,org_id), foreign key(lead_owner_id,org_id) references public.bg_owners(id,org_id),
 check(length(trim(code))>0 and length(trim(name))>0 and length(trim(city))>0),
 check(currency is not null or (purchase_value is null and market_value is null and annual_tax is null and monthly_rent is null and monthly_maintenance is null))
);
create table if not exists public.bg_ownerships (
 id uuid primary key default gen_random_uuid(), org_id uuid not null references public.bg_organizations(id),
 asset_id uuid not null, owner_id uuid not null,
 numerator bigint not null check(numerator between 1 and 1000000000), denominator bigint not null check(denominator between 1 and 1000000000),
 acquired_on date, acquisition_document text, notes text,
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid, updated_by uuid,
 foreign key(asset_id,org_id) references public.bg_assets(id,org_id), foreign key(owner_id,org_id) references public.bg_owners(id,org_id),
 unique(org_id,asset_id,owner_id), check(numerator<=denominator)
);
create table if not exists public.bg_actions (
 id uuid primary key default gen_random_uuid(), org_id uuid not null references public.bg_organizations(id), asset_id uuid not null,
 position integer not null check(position between 1 and 5), description text not null check(length(trim(description))>0),
 responsible text, due_date date, status text not null default 'not_started', notes text,
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid, updated_by uuid,
 foreign key(asset_id,org_id) references public.bg_assets(id,org_id), unique(org_id,asset_id,position)
);
create table if not exists public.bg_cases (
 id uuid primary key default gen_random_uuid(), org_id uuid not null references public.bg_organizations(id), asset_id uuid not null,
 system text not null check(system in ('ceop','cadastre','other')), case_number text not null check(length(trim(case_number))>0),
 case_type text, status text not null default 'submitted', external_status text, authority text, filed_on date, checked_on date,
 deadline date, responsible text, source_url text check(source_url is null or source_url ~ '^https://'), outcome text, notes text,
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid, updated_by uuid,
 foreign key(asset_id,org_id) references public.bg_assets(id,org_id), unique(org_id,asset_id,system,case_number)
);
create table if not exists public.bg_documents (
 id uuid primary key default gen_random_uuid(), org_id uuid not null references public.bg_organizations(id), asset_id uuid not null,
 code text not null, title text not null, document_type text not null, document_number text, issued_on date, expires_on date,
 status text not null default 'exists', authority text, document_form text,
 url text check(url is null or url ~ '^https://'), responsible text, storage_path text, file_name text, mime_type text,
 file_size bigint check(file_size between 0 and 20971520), notes text,
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid, updated_by uuid,
 foreign key(asset_id,org_id) references public.bg_assets(id,org_id), unique(org_id,code),
 check(length(trim(code))>0 and length(trim(title))>0),
 check(storage_path is null or storage_path like org_id::text || '/' || asset_id::text || '/%')
);
create table if not exists public.bg_utilities (
 id uuid primary key default gen_random_uuid(), org_id uuid not null references public.bg_organizations(id), asset_id uuid not null,
 utility_type text not null, supplier text, contract_owner_id uuid, customer_code text, meter_number text, contract_number text,
 power_kw numeric(18,2) check(power_kw>=0), currency text check(currency in ('EUR','RSD')), monthly_cost numeric(18,2) check(monthly_cost between 0 and 1000000000000),
 valid_until date, supplier_contact text, url text check(url is null or url ~ '^https://'), notes text,
 version integer not null default 1, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid, updated_by uuid,
 foreign key(asset_id,org_id) references public.bg_assets(id,org_id), foreign key(contract_owner_id,org_id) references public.bg_owners(id,org_id),
 check(monthly_cost is null or currency is not null)
);
create table if not exists public.bg_audit_log (
 id bigint generated always as identity primary key, org_id uuid not null references public.bg_organizations(id),
 entity text not null, entity_id uuid not null, operation text not null, actor_id uuid, actor_name text,
 old_data jsonb, new_data jsonb, created_at timestamptz not null default now()
);

-- Auth provisioning: invited/created users start inactive. Admin explicitly grants access.
create or replace function bg_private.on_auth_user() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.bg_profiles(id,org_id,email,display_name) values(new.id,'00000000-0000-4000-8000-000000000001',coalesce(new.email,''),left(coalesce(new.raw_user_meta_data->>'full_name',split_part(coalesce(new.email,''),'@',1)),120))
 on conflict(id) do update set email=excluded.email,updated_at=now();
 return new;
end; $$;
drop trigger if exists bg_auth_user_created on auth.users;
create trigger bg_auth_user_created after insert or update of email on auth.users for each row execute function bg_private.on_auth_user();
insert into public.bg_profiles(id,org_id,email,display_name)
 select id,'00000000-0000-4000-8000-000000000001',coalesce(email,''),left(coalesce(raw_user_meta_data->>'full_name',split_part(coalesce(email,''),'@',1)),120) from auth.users
 on conflict(id) do nothing;

create or replace function bg_private.stamp() returns trigger language plpgsql set search_path='' as $$
begin
 if tg_op='UPDATE' then
  if new.org_id is distinct from old.org_id or new.id is distinct from old.id then raise exception 'Organizacija i interni ID se ne menjaju.'; end if;
  new.version:=old.version+1; new.created_at:=old.created_at; new.created_by:=old.created_by;
 else new.version:=1; new.created_at:=clock_timestamp(); new.created_by:=auth.uid(); end if;
 new.updated_at:=clock_timestamp(); new.updated_by:=auth.uid();
 return new;
end; $$;
create or replace function bg_private.validate_options() returns trigger language plpgsql security definer set search_path='' as $$
declare mapping jsonb; f text; kind_name text; field_value text; oldj jsonb;
begin
 mapping:= ('__DICT_FIELDS__'::jsonb)->replace(tg_table_name,'bg_','');
 if tg_op='UPDATE' then oldj:=to_jsonb(old); else oldj:='{}'::jsonb; end if;
 for f,kind_name in select j.key,j.value from jsonb_each_text(coalesce(mapping,'{}'::jsonb)) as j loop
  field_value:=to_jsonb(new)->>f;
  if field_value is not null and not exists(select 1 from public.bg_options o where o.org_id=new.org_id and o.kind=kind_name and o.code=field_value and (o.active or oldj->>f=field_value)) then
   raise exception 'Nevažeća stavka liste: % (%).',f,field_value using errcode='23514';
  end if;
 end loop;
 return new;
end; $$;
create or replace function bg_private.protect_option_code() returns trigger language plpgsql set search_path='' as $$
begin
 if new.kind is distinct from old.kind or new.code is distinct from old.code then raise exception 'Šifra i kategorija liste su trajne. Menjajte naziv ili deaktivirajte stavku.'; end if;
 return new;
end; $$;
drop trigger if exists bg_option_code on public.bg_options;
create trigger bg_option_code before update on public.bg_options for each row execute function bg_private.protect_option_code();

create or replace function bg_private.audit() returns trigger language plpgsql security definer set search_path='' as $$
declare d jsonb; actor text; tenant_id uuid;
begin
 if tg_op='DELETE' then d:=to_jsonb(old); else d:=to_jsonb(new); end if;
 select display_name into actor from public.bg_profiles where id=auth.uid();
 tenant_id:=case when tg_table_name='bg_organizations' then (d->>'id')::uuid else (d->>'org_id')::uuid end;
 insert into public.bg_audit_log(org_id,entity,entity_id,operation,actor_id,actor_name,old_data,new_data)
 values(tenant_id,tg_table_name,(d->>'id')::uuid,tg_op,auth.uid(),actor,
 case when tg_op='INSERT' then null else to_jsonb(old) end,case when tg_op='DELETE' then null else to_jsonb(new) end);
 if tg_op='DELETE' then return old; end if; return new;
end; $$;

-- Every business table is tenant-scoped. Editor writes; only admin deletes.
do $$ declare t text; begin
 foreach t in array array['bg_options','bg_owners','bg_assets','bg_ownerships','bg_actions','bg_cases','bg_documents','bg_utilities'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon, authenticated',t);
  execute format('grant select,insert,update on public.%I to authenticated',t);
  if t<>'bg_options' then execute format('grant delete on public.%I to authenticated',t); end if;
  execute format('drop policy if exists bg_read on public.%I',t);
  execute format('create policy bg_read on public.%I for select to authenticated using (org_id=(select bg_private.actor_org()))',t);
  execute format('drop policy if exists bg_insert on public.%I',t);
  execute format('drop policy if exists bg_update on public.%I',t);
  execute format('drop policy if exists bg_delete on public.%I',t);
  if t='bg_options' then
   execute format('create policy bg_insert on public.%I for insert to authenticated with check (org_id=(select bg_private.actor_org()) and (select bg_private.actor_role())=''admin'')',t);
   execute format('create policy bg_update on public.%I for update to authenticated using (org_id=(select bg_private.actor_org()) and (select bg_private.actor_role())=''admin'') with check (org_id=(select bg_private.actor_org()) and (select bg_private.actor_role())=''admin'')',t);
  else
   execute format('create policy bg_insert on public.%I for insert to authenticated with check (org_id=(select bg_private.actor_org()) and (select bg_private.actor_role()) in (''admin'',''editor''))',t);
   execute format('create policy bg_update on public.%I for update to authenticated using (org_id=(select bg_private.actor_org()) and (select bg_private.actor_role()) in (''admin'',''editor'')) with check (org_id=(select bg_private.actor_org()) and (select bg_private.actor_role()) in (''admin'',''editor''))',t);
   execute format('create policy bg_delete on public.%I for delete to authenticated using (org_id=(select bg_private.actor_org()) and (select bg_private.actor_role())=''admin'')',t);
  end if;
  execute format('drop trigger if exists bg_stamp on public.%I',t);
  execute format('create trigger bg_stamp before insert or update on public.%I for each row execute function bg_private.stamp()',t);
  execute format('drop trigger if exists bg_dictionary on public.%I',t);
  if t<>'bg_options' then execute format('create trigger bg_dictionary before insert or update on public.%I for each row execute function bg_private.validate_options()',t); end if;
  execute format('drop trigger if exists bg_audit on public.%I',t);
  execute format('create trigger bg_audit after insert or update or delete on public.%I for each row execute function bg_private.audit()',t);
  execute format('create index if not exists %I on public.%I(org_id,id)',t||'_org',t);
 end loop;
end $$;
alter table public.bg_profiles enable row level security;
alter table public.bg_organizations enable row level security;
alter table public.bg_audit_log enable row level security;
revoke all on public.bg_profiles,public.bg_organizations,public.bg_audit_log from anon,authenticated;
grant select on public.bg_profiles,public.bg_organizations,public.bg_audit_log to authenticated;
grant update(name,warning_days) on public.bg_organizations to authenticated;
drop policy if exists bg_profile_read on public.bg_profiles;
create policy bg_profile_read on public.bg_profiles for select to authenticated using(id=auth.uid() or (org_id=(select bg_private.actor_org()) and (select bg_private.actor_role())='admin'));
drop policy if exists bg_org_read on public.bg_organizations;
create policy bg_org_read on public.bg_organizations for select to authenticated using(id=(select bg_private.actor_org()));
drop policy if exists bg_org_update on public.bg_organizations;
create policy bg_org_update on public.bg_organizations for update to authenticated using(id=(select bg_private.actor_org()) and (select bg_private.actor_role())='admin') with check(id=(select bg_private.actor_org()) and (select bg_private.actor_role())='admin');
drop policy if exists bg_audit_read on public.bg_audit_log;
create policy bg_audit_read on public.bg_audit_log for select to authenticated using(org_id=(select bg_private.actor_org()) and (select bg_private.actor_role())='admin');
drop trigger if exists bg_audit on public.bg_profiles;
create trigger bg_audit after update on public.bg_profiles for each row execute function bg_private.audit();
drop trigger if exists bg_audit on public.bg_organizations;
create trigger bg_audit after update on public.bg_organizations for each row execute function bg_private.audit();

create or replace function public.bg_manage_user(p_user_id uuid,p_role text,p_active boolean,p_display_name text) returns void language plpgsql security definer set search_path='' as $$
declare target public.bg_profiles; oid uuid;
begin
 oid:=bg_private.actor_org();
 if bg_private.actor_role() is distinct from 'admin' or oid is null then raise exception 'Samo administrator upravlja pristupom.' using errcode='42501'; end if;
 if p_role not in ('admin','editor','viewer') or p_active is null then raise exception 'Nevažeća uloga.'; end if;
 perform pg_advisory_xact_lock(hashtextextended(oid::text,0));
 select * into target from public.bg_profiles where id=p_user_id and org_id=oid for update;
 if not found then raise exception 'Korisnik nije u ovoj organizaciji.'; end if;
 if target.role='admin' and target.active and (p_role<>'admin' or not p_active) and (select count(*) from public.bg_profiles where org_id=oid and role='admin' and active)<=1 then
  raise exception 'Mora ostati najmanje jedan aktivan administrator.';
 end if;
 update public.bg_profiles set role=p_role,active=p_active,display_name=left(coalesce(p_display_name,''),120),updated_at=now() where id=p_user_id and org_id=oid;
end; $$;
revoke all on function public.bg_manage_user(uuid,text,boolean,text) from public,anon;
grant execute on function public.bg_manage_user(uuid,text,boolean,text) to authenticated;

create index if not exists bg_assets_city on public.bg_assets(org_id,city);
create index if not exists bg_assets_status on public.bg_assets(org_id,portfolio_status,occupancy_permit);
create index if not exists bg_cases_asset on public.bg_cases(org_id,asset_id);
create index if not exists bg_cases_deadline on public.bg_cases(org_id,deadline);
create index if not exists bg_actions_asset on public.bg_actions(org_id,asset_id,due_date);
create index if not exists bg_ownerships_owner on public.bg_ownerships(org_id,owner_id,asset_id);
create index if not exists bg_documents_asset on public.bg_documents(org_id,asset_id);
create index if not exists bg_utilities_asset on public.bg_utilities(org_id,asset_id);
create index if not exists bg_audit_date on public.bg_audit_log(org_id,created_at desc);

-- Stable codes, editable labels and flags. Re-running never overwrites admin changes.
__SEEDS__

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('bg-estate-documents','bg-estate-documents',false,20971520,array['application/pdf','image/jpeg','image/png','image/webp','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet','text/plain'])
 on conflict(id) do update set public=false,file_size_limit=20971520,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists bg_storage_read on storage.objects;
create policy bg_storage_read on storage.objects for select to authenticated using(
 bucket_id='bg-estate-documents' and (storage.foldername(storage.objects.name))[1]=(select bg_private.actor_org())::text
 and exists(select 1 from public.bg_assets a where a.org_id=(select bg_private.actor_org()) and a.id::text=(storage.foldername(storage.objects.name))[2])
);
drop policy if exists bg_storage_insert on storage.objects;
create policy bg_storage_insert on storage.objects for insert to authenticated with check(
 bucket_id='bg-estate-documents' and (select bg_private.actor_role()) in ('admin','editor')
 and (storage.foldername(storage.objects.name))[1]=(select bg_private.actor_org())::text
 and exists(select 1 from public.bg_assets a where a.org_id=(select bg_private.actor_org()) and a.id::text=(storage.foldername(storage.objects.name))[2])
);
drop policy if exists bg_storage_delete on storage.objects;
create policy bg_storage_delete on storage.objects for delete to authenticated using(
 bucket_id='bg-estate-documents' and (select bg_private.actor_role()) in ('admin','editor') and (storage.foldername(storage.objects.name))[1]=(select bg_private.actor_org())::text
);
revoke all on all functions in schema bg_private from public,anon;
grant execute on function bg_private.actor_org(),bg_private.actor_role() to authenticated;
commit;

-- AFTER creating/inviting your first Auth user, run separately with the real email:
-- update public.bg_profiles set active=true,role='admin' where lower(email)=lower('ADMIN_EMAIL');
-- select email,role,active from public.bg_profiles;
