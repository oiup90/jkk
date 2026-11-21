-- Sign-in visitors get a device-held capability, independent of account access.
begin;
alter table growth_internal.support_tickets alter column user_id drop not null;
alter table growth_internal.support_tickets add column guest_key_hash text;
alter table growth_internal.support_tickets add constraint support_ticket_owner_check
  check ((user_id is not null) <> (guest_key_hash is not null));
create index support_guest_key_idx on growth_internal.support_tickets(guest_key_hash, created_at desc) where guest_key_hash is not null;

-- Null user_id must never make an ordinary authenticated user an owner.
create or replace function public.support_reply(p_ticket uuid,p_body text) returns void language plpgsql security definer set search_path='' as $$
declare t growth_internal.support_tickets%rowtype; admin_reply boolean:=false; body text:=btrim(coalesce(p_body,''));
begin
 perform growth_internal.require_active();
 if length(body) not between 1 and 2000 then raise exception 'Invalid message.' using errcode='P0001'; end if;
 select * into t from growth_internal.support_tickets where id=p_ticket for update;
 if not found or t.status<>'open' then raise exception 'Ticket unavailable.' using errcode='P0001'; end if;
 if t.user_id is distinct from auth.uid() then perform growth_internal.require_admin_editor(); admin_reply:=true; end if;
 insert into growth_internal.support_messages(ticket_id,author_id,is_admin,body) values(t.id,auth.uid(),admin_reply,body);
 update growth_internal.support_tickets set updated_at=now() where id=t.id;
 if not admin_reply then insert into growth_internal.admin_events(kind,subject_id) values('support_reply',t.id); else insert into growth_internal.admin_operations_audit(actor_id,action,subject_id) values(auth.uid(),'Support reply',t.id); end if;
end $$;
create or replace function growth_internal.notify_support_reply() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.is_admin then insert into public.notifications(user_id,kind) select user_id,'support_reply' from growth_internal.support_tickets where id=new.ticket_id and user_id is not null; end if;
 return new;
end $$;

create function public.guest_support_get(p_key text) returns jsonb language plpgsql security definer set search_path='' as $$
declare t growth_internal.support_tickets%rowtype;
begin
 if p_key is null or p_key !~ '^[0-9a-f]{64}$' then raise exception 'Invalid key.' using errcode='P0001'; end if;
 select * into t from growth_internal.support_tickets where guest_key_hash=encode(extensions.digest(p_key,'sha256'),'hex') order by created_at desc,id desc limit 1;
 if not found then return null; end if;
 return jsonb_build_object('status',t.status,'messages',coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at,m.id) from (select body,is_admin,created_at,id from growth_internal.support_messages where ticket_id=t.id order by created_at desc,id desc limit 200) m),'[]'::jsonb));
end $$;

create function public.guest_support_send(p_key text,p_body text,p_new boolean default false) returns void language plpgsql security definer set search_path='' as $$
declare t growth_internal.support_tickets%rowtype; key_hash text; body text:=btrim(coalesce(p_body,'')); tid uuid;
begin
 if p_key is null or p_key !~ '^[0-9a-f]{64}$' or length(body) not between 1 and 2000 or p_new is null then raise exception 'Invalid message.' using errcode='P0001'; end if;
 key_hash:=encode(extensions.digest(p_key,'sha256'),'hex');
 -- Serialize creation and the global limit, including concurrent requests.
 perform pg_advisory_xact_lock(20261120,1500);
 select * into t from growth_internal.support_tickets where guest_key_hash=key_hash order by created_at desc,id desc limit 1 for update;
 if not found or (t.status='closed' and p_new) then
   if (select count(*) from growth_internal.support_tickets where guest_key_hash is not null and created_at > now()-interval '1 minute') >= 60 then raise exception 'Please try again later.' using errcode='P0001'; end if;
   insert into growth_internal.support_tickets(user_id,guest_key_hash,subject) values(null,key_hash,left(body,80)) returning id into tid;
   insert into growth_internal.admin_events(kind,subject_id) values('support_ticket',tid);
 elsif t.status='closed' then
   raise exception 'Ticket closed.' using errcode='P0001';
 else
   tid:=t.id;
   if (select count(*) from growth_internal.support_messages where ticket_id=tid and not is_admin and created_at > now()-interval '1 minute') >= 20 then raise exception 'Please try again later.' using errcode='P0001'; end if;
   insert into growth_internal.admin_events(kind,subject_id) values('support_reply',tid);
 end if;
 insert into growth_internal.support_messages(ticket_id,author_id,is_admin,body) values(tid,null,false,body);
 update growth_internal.support_tickets set updated_at=now() where id=tid;
end $$;
revoke all on function public.guest_support_get(text),public.guest_support_send(text,text,boolean) from public;
grant execute on function public.guest_support_get(text),public.guest_support_send(text,text,boolean) to anon,authenticated;
commit;
