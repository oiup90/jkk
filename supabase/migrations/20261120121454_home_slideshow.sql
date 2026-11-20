-- User-home slides: authenticated reads; MFA-verified editors manage content.
begin;
create table growth_internal.home_slides (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('referral','earnings','image')),
  title text not null check (char_length(title) between 1 and 80),
  image_data bytea,
  mime text,
  enabled boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  check ((kind in ('referral','earnings') and image_data is null and mime is null)
     or (kind='image' and image_data is not null and mime is not null and mime in ('image/png','image/jpeg') and octet_length(image_data) between 24 and 524288)),
  unique (sort_order)
);
alter table growth_internal.home_slides enable row level security;
revoke all on growth_internal.home_slides from public, anon, authenticated, service_role;
insert into growth_internal.home_slides(id,kind,title,sort_order) values
 ('00000000-0000-4000-8000-000000000001','referral','Referral rewards',1),
 ('00000000-0000-4000-8000-000000000002','earnings','Campaign earnings',2);

create function public.home_slides() returns table(id uuid,kind text,title text,mime text,image_base64 text,sort_order integer)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_active();
 return query select s.id,s.kind,s.title,s.mime,pg_catalog.replace(pg_catalog.encode(s.image_data,'base64'), E'\n', ''),s.sort_order
 from growth_internal.home_slides s where s.enabled order by s.sort_order;
end $$;
revoke all on function public.home_slides() from public, anon;
grant execute on function public.home_slides() to authenticated;

create function public.admin_home_slides() returns table(id uuid,kind text,title text,mime text,image_base64 text,sort_order integer,enabled boolean)
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin();
 return query select s.id,s.kind,s.title,s.mime,pg_catalog.replace(pg_catalog.encode(s.image_data,'base64'), E'\n', ''),s.sort_order,s.enabled
 from growth_internal.home_slides s order by s.sort_order;
end $$;
revoke all on function public.admin_home_slides() from public, anon;
grant execute on function public.admin_home_slides() to authenticated;

create function public.admin_add_home_slide(p_title text,p_mime text,p_base64 text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_data bytea; v_id uuid; v_sort_order integer; v_title text := btrim(p_title);
begin
 perform growth_internal.require_admin_editor();
 if v_title is null or char_length(v_title) not between 1 and 80 or p_mime is null or p_mime not in ('image/png','image/jpeg') or p_base64 is null or length(p_base64)>699052 then
   raise exception 'Invalid slide' using errcode='P0001';
 end if;
 begin v_data := pg_catalog.decode(p_base64,'base64'); exception when others then raise exception 'Invalid slide image' using errcode='P0001'; end;
 if octet_length(v_data) not between 24 and 524288 or
   (p_mime='image/png' and substring(v_data from 1 for 8)<>decode('89504e470d0a1a0a','hex')) or
   (p_mime='image/jpeg' and substring(v_data from 1 for 3)<>decode('ffd8ff','hex')) then
   raise exception 'Invalid slide image' using errcode='P0001';
 end if;
 perform pg_advisory_xact_lock(hashtext('freelan_home_slides'));
 if (select count(*) from growth_internal.home_slides where kind='image') >= 8 then raise exception 'Slide limit reached' using errcode='P0001'; end if;
 select coalesce(max(sort_order),0)+1 into v_sort_order from growth_internal.home_slides;
 insert into growth_internal.home_slides(kind,title,mime,image_data,sort_order) values ('image',v_title,p_mime,v_data,v_sort_order) returning id into v_id;
 insert into growth_internal.admin_operations_audit(actor_id,action) values (auth.uid(),'Home slide added');
 return v_id;
end $$;
revoke all on function public.admin_add_home_slide(text,text,text) from public, anon;
grant execute on function public.admin_add_home_slide(text,text,text) to authenticated;

create function public.admin_set_home_slide_enabled(p_id uuid,p_enabled boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 if p_enabled is null then raise exception 'Invalid slide' using errcode='P0001'; end if;
 update growth_internal.home_slides set enabled=p_enabled where id=p_id;
 if not found then raise exception 'Slide not found' using errcode='P0001'; end if;
 insert into growth_internal.admin_operations_audit(actor_id,action) values (auth.uid(),case when p_enabled then 'Home slide enabled' else 'Home slide hidden' end);
end $$;
revoke all on function public.admin_set_home_slide_enabled(uuid,boolean) from public, anon;
grant execute on function public.admin_set_home_slide_enabled(uuid,boolean) to authenticated;

create function public.admin_delete_home_slide(p_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform growth_internal.require_admin_editor();
 perform pg_advisory_xact_lock(hashtext('freelan_home_slides'));
 delete from growth_internal.home_slides where id=p_id and kind='image';
 if not found then raise exception 'Slide cannot be deleted' using errcode='P0001'; end if;
 insert into growth_internal.admin_operations_audit(actor_id,action) values (auth.uid(),'Home slide deleted');
end $$;
revoke all on function public.admin_delete_home_slide(uuid) from public, anon;
grant execute on function public.admin_delete_home_slide(uuid) to authenticated;
-- Serialize ordering with insert and delete; move one step and retain stable IDs.
create function public.admin_move_home_slide(p_id uuid,p_direction integer) returns void
language plpgsql security definer set search_path='' as $$
declare current_order integer; next_order integer; next_id uuid;
begin
 perform growth_internal.require_admin_editor();
 if p_direction is null or p_direction not in (-1,1) then raise exception 'Invalid direction' using errcode='P0001'; end if;
 perform pg_advisory_xact_lock(hashtext('freelan_home_slides'));
 select s.sort_order into current_order from growth_internal.home_slides s where s.id=p_id;
 if not found then raise exception 'Slide not found' using errcode='P0001'; end if;
 select s.id,s.sort_order into next_id,next_order from growth_internal.home_slides s
 where (p_direction=-1 and s.sort_order<current_order) or (p_direction=1 and s.sort_order>current_order)
 order by case when p_direction=-1 then -s.sort_order else s.sort_order end limit 1;
 if next_id is null then return; end if;
 update growth_internal.home_slides set sort_order=-1 where id=p_id;
 update growth_internal.home_slides set sort_order=current_order where id=next_id;
 update growth_internal.home_slides set sort_order=next_order where id=p_id;
 insert into growth_internal.admin_operations_audit(actor_id,action) values (auth.uid(),'Home slide reordered');
end $$;
revoke all on function public.admin_move_home_slide(uuid,integer) from public, anon;
grant execute on function public.admin_move_home_slide(uuid,integer) to authenticated;
commit;
