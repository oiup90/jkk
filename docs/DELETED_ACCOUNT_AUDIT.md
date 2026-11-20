<!-- coderabbit-ai-generated:v1 -->

# Deleted account audit

Open **Deleted accounts audit** in the administrator sidebar or compact workspace menu. Search by email, name or exact user UUID. Open an archive to inspect its sections and download the complete JSON, including image/evidence data where still present at deletion. MFA-verified active editors and viewers can read archives; ordinary users and anonymous clients cannot. Reads/exports create an administrator operations audit event. Client roles cannot directly modify or delete archives.

The BEFORE DELETE trigger archives remaining business rows and the account's identity before Auth cascades remove them, in the same transaction. Failure to archive prevents deletion; rollback also rolls back the archive. It covers all Auth deletions after deployment, including self-deletion, using an explicit business-table allowlist. Related owned-campaign evidence, support replies and transfer ledger rows are included. Business-table writes are briefly locked during capture, so large accounts can delay concurrent writes; validate capacity for large deployments.

Archives have no automatic expiry. They preserve what exists at deletion, not records already purged by existing retention jobs, previous edits, or earlier account deletions. They do not capture Auth credentials, OTPs, PIN hashes, push tokens, provider logs or external Instagram content. Only explicitly selected Auth identity fields are retained, not arbitrary user metadata. New business tables must be reviewed and added to the allowlist. Exported JSON contains personal information; retain it only in the administrator's audit storage.

<!-- coderabbit-ai-generated:v1 -->

<!-- coderabbit-ai-generated-section:v1:a5bebfa9f2235f0646bf93f2c2389f785bbf38fffb729fca6ad8d8410306d5b0 -->

Migration `20261120131954_deleted_account_audit.sql` was applied to project `stpxbshwdiupigymakfy` on 2026-11-20. Future Auth deletions are archived. The user deletion screen and privacy page now disclose this retention.

<!-- /coderabbit-ai-generated:v1 --> Updated user and admin builds are needed for the revised notice and audit screen. The archive feature cannot recover previously deleted records. Native Windows file dialogs and real account deletion must be checked with an authorized test account after deployment; development uses synthetic fixtures.
