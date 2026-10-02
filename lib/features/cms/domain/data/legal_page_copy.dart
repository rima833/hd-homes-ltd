/// Built-in legal pages for `/pages/:slug` until a longer CMS body is published.
class LegalPageCopy {
  const LegalPageCopy({
    required this.title,
    required this.subtitle,
    required this.body,
  });

  final String title;
  final String subtitle;
  final String body;

  static LegalPageCopy? forSlug(String slug) => switch (slug) {
    'terms' => terms,
    'privacy' => privacy,
    'cookies' => cookies,
    'refund-policy' => refunds,
    _ => null,
  };

  /// Short CMS seeds should not replace this copy.
  bool replaces(String? publishedBody) {
    final text = (publishedBody ?? '').trim();
    return text.isEmpty || text.length < 400;
  }

  static const terms = LegalPageCopy(
    title: 'Terms & Conditions',
    subtitle: 'How you may use HD Homes websites, portals, and tools.',
    body: '''
These terms apply to the HD Homes public website, the client portal, and the investor portal. A signed purchase, construction, or investment agreement controls if it conflicts with this page.

Accounts
You must give accurate contact details and keep your login private. HD Homes may suspend an account that is used to mislead staff, other customers, or payment reviewers.

Property and investment information
Listings, calculators, and ROI tools are illustrations. Prices, availability, timelines, and projected returns can change. A figure on the website is not an offer until HD Homes confirms it in writing.

Payments
Bank-transfer instructions name the receiving account for that payment. Send the amount, date, and reference HD Homes asks for, and keep your proof of payment. A transfer is not complete until finance confirms it. Card checkout is not available on this site.

Identity checks
HD Homes may ask you to complete identity verification before it accepts a payment or continues a sale. You agree to provide documents that are yours and still valid.

Acceptable use
Do not attempt to access another person's account, interfere with the site, or submit false applications, tickets, or payment proofs.

Contact
Questions about these terms can be sent through the Trust Center legal form or to the address published on the Contact page.
''',
  );

  static const privacy = LegalPageCopy(
    title: 'Privacy Policy',
    subtitle: 'What HD Homes collects and why.',
    body: '''
HD Homes collects personal information so it can respond to enquiries, manage sales and investments, verify identity, and operate its websites and portals.

Information you give us
Name, email, phone, city, occupation, and the message you type into a form. Payment submissions include the amount, transfer date, sender name, bank, reference, and any proof you upload. Identity verification includes the documents and details you submit for KYC.

Information collected automatically
Sign-in records, pages you open while signed in, and cookies described in the Cookie Policy. Optional analytics run only after you accept cookies.

How it is used
To reply to you, create or update a client or investor record you were invited to, review payments, meet legal and security duties, and improve the site. Staff see a record only when their role allows it.

Sharing
Payment details are shared with the finance team that confirms transfers. Identity documents are shared with the reviewers assigned to KYC. HD Homes does not sell personal information.

Retention and your requests
Records are kept for as long as the enquiry, contract, payment, or legal duty requires. To ask for access or a correction, use the Contact page or the Trust Center legal form and include the email on your account.

Security
Access to portals is limited by role. Payment proofs and identity documents are stored in private storage, not on public pages.
''',
  );

  static const cookies = LegalPageCopy(
    title: 'Cookie Policy',
    subtitle: 'The cookies this site uses and how to choose.',
    body: '''
Essential cookies
The site stores a cookie choice on this device so the banner does not return after you accept or decline. Signed-in sessions use storage required to keep you logged in and to protect the account.

Optional cookies
If you accept, the site may use analytics to understand which pages are used. If you decline, those optional cookies are not enabled. Declining does not block the public pages, calculators, or a portal you are invited to.

How to change your mind
Clear this site's data in your browser and reload. The banner appears again and you can accept or decline.

More detail
The Privacy Policy explains the personal information HD Homes collects when you submit a form or sign in.
''',
  );

  static const refunds = LegalPageCopy(
    title: 'Refund Policy',
    subtitle: 'How cancellations and refunds are handled.',
    body: '''
A refund follows the purchase, construction, or investment agreement you signed, and the payment milestone already reached. This page does not override that agreement.

Before you pay
An enquiry, calculator application, or inspection booking is not a completed purchase. No refund arises until money has been received and confirmed.

After a transfer is submitted
Finance reviews the proof of payment. If a transfer cannot be matched, HD Homes will tell you what is missing. Do not send a second transfer for the same instalment unless staff ask you to.

Refund requests
Write through the Trust Center legal form or the Contact page. Include your name, the email on the account, the contract or property reference, the amount, the date, and the transfer reference. HD Homes will reply with the outcome the agreement allows.

Timing
Where a refund is due, it is paid back to the account the agreement names, or to the account that sent the transfer when the agreement does not name one. Bank processing time is outside HD Homes' control.
''',
  );
}
