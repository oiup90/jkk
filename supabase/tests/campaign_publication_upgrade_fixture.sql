-- Synthetic historical campaigns before the publication migration.
insert into auth.users(id) values ('f1000000-0000-4000-8000-000000000001');
insert into public.wallets(id,balance) values ('f1000000-0000-4000-8000-000000000001',20);
insert into public.campaigns(id,"ownerId",type,link,requested,remaining,status,"createdAt",reward_per_task) values
 ('f2000000-0000-4000-8000-000000000001','f1000000-0000-4000-8000-000000000001','like','https://instagram.com/p/A/',3,2,'active',now()-interval '1 day',2),
 ('f2000000-0000-4000-8000-000000000002','f1000000-0000-4000-8000-000000000001','follow','https://instagram.com/sample/',1,0,'completed',now()-interval '2 days',1);
