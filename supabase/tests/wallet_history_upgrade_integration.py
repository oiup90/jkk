"""Verify reference backfill on synthetic records created before the migration."""
import subprocess
import sys
DB=sys.argv[1]
def sql(query):
    p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',query],capture_output=True,text=True)
    assert p.returncode == 0,p.stderr
    return p.stdout.strip()
assert sql("select count(*)=4 and sum(amount)=15 from public.coin_ledger") == 't'
assert sql("select count(*)=1 from public.coin_ledger where reason='welcome' and reference_id ~ '^RG[0-9]{10}$'") == 't'
assert sql("select count(*)=1 from public.coin_ledger where reason='referral' and reference_id ~ '^RF[0-9]{10}$'") == 't'
assert sql("select count(distinct l.reference_id)=1 and count(*)=2 and bool_and(l.reference_id=r.reference_id) from public.coin_ledger l join growth_internal.wallet_payment_results r on r.transfer_id=l.transfer_id") == 't'
print('PASS: historical bonus references and existing payment receipt backfilled without changing ledger amounts')
