begin;

create index referrals_history_by_referrer on growth_internal.referrals
  (referrer_id, created_at desc, referred_id);

create function public.referral_history(p_offset integer default 0)
returns table (direction text, masked_name text, masked_email text, created_at timestamptz)
language plpgsql security definer set search_path='' as $$
declare caller uuid := auth.uid();
begin
  perform growth_internal.require_active();
  if p_offset is null or p_offset < 0 then
    raise exception 'Invalid history offset.' using errcode='P0001';
  end if;
  return query
    with page as (
      select r.referred_id as other_id, 'referred'::text as direction, r.created_at
      from growth_internal.referrals r where r.referrer_id = caller
      union all
      select r.referrer_id, 'referrer'::text, r.created_at
      from growth_internal.referrals r where r.referred_id = caller
      order by 3 desc, 1, 2
      limit 50 offset p_offset
    )
    select p.direction,
      case when n.name = '' then null
        when length(n.name) = 1 then '***'
        else left(n.name, 1) || '***' end,
      case when u.email is null or u.email = '' then null
        when strpos(u.email, '@') > 2 then left(u.email, 1) || '***@***'
        else '***@***' end,
      p.created_at
    from page p
    join auth.users u on u.id = p.other_id
    cross join lateral (select btrim(coalesce(u.raw_user_meta_data->>'full_name','')) as name) n
    order by p.created_at desc, p.other_id, p.direction;
end $$;
revoke all on function public.referral_history(integer) from public, anon;
grant execute on function public.referral_history(integer) to authenticated;

commit;
