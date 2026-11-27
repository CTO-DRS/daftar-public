# دفتر (Daftar) Roadmap

Current: v0.1.29. Arabic RTL Flutter app, Android + Windows, local SQLite, PDF, OCR, optional Supabase sync.
Rules: offline-first stays the default. ZATCA is labeled "Phase 1 style", never "certified". Mint green accent, no gold. Every release signed with the permanent key.

## Done (v0.1.15 to v0.1.29)
Pack-size and price tiers, split-per-ABI APKs (38 MB arm64), permanent signing key, scan fix, free vision-model OCR chain, voice/text quick invoice, audit log, fingerprint lock, cost price and profit card, barcode scan, stock forecast and reorder, quotes with partial conversion, overdue follow-up queue, optional cloud sync (customers, invoices).

## M3: Share links with "viewed" status (next, in progress)
- Share an invoice as a public link (unguessable token, snapshot of the invoice, no login for the customer).
- Static viewer page on GitHub Pages from daftar-public (free). Counts views through the open_share RPC.
- Invoice list shows "شاهدها العميل" with first/last view time. Share via WhatsApp with the link.
- Revoke a link. Link carries only the invoice snapshot, never other data.

## M4: Sync completeness and live stock
- Sync price tiers, recurring invoices, expenses, settings that matter (numbering, currency).
- Stock as a first-class ledger: on-hand per item, updated by confirmed invoices, purchases and counts, synced across devices. Low-stock banner.
- Conflict view for same-record edits on two devices. Sync status chip in the list.

## M5: Expenses and purchases
- New doc types: expense and purchase (supplier, category, VAT).
- Receipt OCR into an expense, one-tap confirm. Expense totals, net profit (sales minus cost minus expenses), monthly report.

## M6: Automatic flows (fewest taps)
- Scan: camera, auto edge detection, auto-fill, single confirm screen.
- Voice/text: parse, auto-match customer and items from history, create draft, one tap to confirm.
- Smart defaults: last price per customer and item, due date by customer habit.

## M7: Safety and backup
- Local automatic backup (daily, rotating, to app storage plus share-out).
- Encrypted cloud backup on the existing sync server (client-side encryption, key from user passphrase).
- Restore wizard and integrity check.

## M8: Reports and accounting
- Customer and supplier statements with aging, profit by item/customer, VAT return summary, cash-flow view.
- Excel/CSV export for the accountant. Printable A4 and thermal 58/80 mm receipts.

## M9: ZATCA (needs the user)
- Phase 1 style QR already present. Phase 2 (CSID onboarding, signed XML, clearance/reporting) needs his Fatoora sandbox/CSID. Not started; never claim certification.

## M10: Polish and quality
- Windows installer and in-app update check parity, tablet/desktop layouts.
- Accessibility (TalkBack, large text), performance on low-end phones, widget tests for every screen, crash-free CI gates.
- Onboarding (3 screens), sample data, in-app help in Arabic.
- Multi-user roles (owner, cashier) on the sync layer.

## Needs the user
Fatoora sandbox/CSID (M9). Google OAuth client only if he wants Drive backup (the server backup avoids it). Any paid Supabase plan or domain.
