begin;
alter table public.campaigns add column instagram_username text;
-- Saved usernames are self-declared profile entries; this does not assert Meta ownership.
create function public.create_campaign_for_account(p_type text,p_username text,p_link text,p_count integer,p_reward integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare campaign uuid; target text;
begin
 perform growth_internal.require_active();
 perform username from public.instagram_accounts where user_id=auth.uid() and username=p_username for share;
 if not found then raise exception 'Choose an Instagram account from your Profile.'; end if;
 target:=case when p_type='follow' then 'https://www.instagram.com/'||p_username||'/' else p_link end;
 campaign:=public.create_campaign_at_rate(p_type,target,p_count,p_reward);
 update public.campaigns set instagram_username=p_username where id=campaign;
 return campaign;
end $$;
revoke all on function public.create_campaign_for_account(text,text,text,integer,integer) from public,anon;
grant execute on function public.create_campaign_for_account(text,text,text,integer,integer) to authenticated;
commit;
