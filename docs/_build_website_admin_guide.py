"""One-off builder for the HD Homes website admin operating guide."""

from pathlib import Path

from fpdf import FPDF

OUT = Path(__file__).with_name("HD_Homes_Website_Admin_Guide.pdf")
FONT = Path(r"C:\Windows\Fonts\segoeui.ttf")
FONT_B = Path(r"C:\Windows\Fonts\segoeuib.ttf")

GOLD = (184, 138, 42)
INK = (28, 28, 28)
MUTED = (90, 90, 90)
RULE = (220, 210, 190)
BAND = (22, 22, 22)


class Guide(FPDF):
    def __init__(self):
        super().__init__(format="A4", unit="mm")
        self.set_auto_page_break(auto=True, margin=18)
        self.add_font("Body", "", str(FONT))
        self.add_font("Body", "B", str(FONT_B))
        self.alias_nb_pages()

    def header(self):
        if self.page_no() == 1:
            return
        self.set_fill_color(*BAND)
        self.rect(0, 0, 210, 12, "F")
        self.set_xy(14, 3.2)
        self.set_font("Body", "B", 8)
        self.set_text_color(212, 175, 90)
        self.cell(0, 5, "HD HOMES  ·  WEBSITE ADMIN GUIDE", align="L")
        self.set_xy(14, 3.2)
        self.set_text_color(230, 230, 230)
        self.set_font("Body", "", 8)
        self.cell(0, 5, "Internal operating instructions", align="R")
        self.ln(12)

    def footer(self):
        self.set_y(-12)
        self.set_draw_color(*RULE)
        self.line(14, self.get_y(), 196, self.get_y())
        self.set_y(-10)
        self.set_font("Body", "", 8)
        self.set_text_color(*MUTED)
        self.cell(0, 5, f"Page {self.page_no()} of {{nb}}", align="R")

    def ensure(self, height):
        if self.get_y() + height > 278:
            self.add_page()

    def h1(self, text):
        self.ensure(16)
        self.ln(2)
        self.set_font("Body", "B", 14)
        self.set_text_color(*INK)
        self.multi_cell(0, 7, text)
        y = self.get_y()
        self.set_draw_color(*GOLD)
        self.set_line_width(0.4)
        self.line(14, y, 48, y)
        self.set_line_width(0.2)
        self.ln(3)

    def h2(self, text):
        self.ensure(12)
        self.ln(1)
        self.set_font("Body", "B", 11.5)
        self.set_text_color(*GOLD)
        self.multi_cell(0, 6, text)
        self.ln(1)

    def p(self, text):
        self.set_font("Body", "", 10.5)
        self.set_text_color(*INK)
        self.multi_cell(0, 5.4, text)
        self.ln(1.6)

    def bullet(self, text):
        self.set_font("Body", "", 10.5)
        self.set_text_color(*INK)
        x = self.l_margin
        self.set_x(x)
        self.cell(5, 5.4, "•")
        self.multi_cell(0, 5.4, text)
        self.ln(0.6)

    def path(self, label, route, what):
        self.ensure(16)
        self.set_font("Body", "B", 10.5)
        self.set_text_color(*INK)
        self.cell(0, 5.2, label, new_x="LMARGIN", new_y="NEXT")
        self.set_font("Body", "", 9)
        self.set_text_color(*GOLD)
        self.cell(0, 4.6, route, new_x="LMARGIN", new_y="NEXT")
        self.set_font("Body", "", 10.5)
        self.set_text_color(*INK)
        self.multi_cell(0, 5.2, what)
        self.ln(1.4)

    def note(self, text):
        self.set_font("Body", "", 10)
        height = self.multi_cell(174, 5, text, dry_run=True, output="HEIGHT") + 6
        self.ensure(height)
        y = self.get_y()
        self.set_fill_color(250, 246, 236)
        self.set_draw_color(*GOLD)
        self.rect(14, y, 182, height, "DF")
        self.set_xy(18, y + 3)
        self.set_text_color(*INK)
        self.multi_cell(174, 5, text)
        self.set_y(y + height + 2)


def build():
    pdf = Guide()
    pdf.set_margins(14, 18, 14)
    pdf.add_page()

    pdf.set_fill_color(*BAND)
    pdf.rect(0, 0, 210, 78, "F")
    pdf.set_xy(14, 22)
    pdf.set_font("Body", "B", 11)
    pdf.set_text_color(*GOLD)
    pdf.cell(0, 6, "HD HOMES LIMITED")
    pdf.set_xy(14, 32)
    pdf.set_font("Body", "B", 22)
    pdf.set_text_color(255, 255, 255)
    pdf.multi_cell(170, 9, "Website admin\noperating guide")
    pdf.set_x(14)
    pdf.set_font("Body", "", 11)
    pdf.set_text_color(220, 220, 220)
    pdf.multi_cell(
        170,
        6,
        "Platform audit — how staff control, operate, and publish the public website.",
    )
    pdf.set_xy(14, 86)
    pdf.set_text_color(*MUTED)
    pdf.set_font("Body", "", 10)
    pdf.multi_cell(
        0,
        5,
        "Prepared from the live admin desks and navigation map. 5 October 2026.\n"
        "Sign in at /login with a staff role that includes Website (CMS) permission. "
        "Company profile and platform switches need Settings permission.",
    )
    pdf.ln(4)

    pdf.h1("1. How control works")
    pdf.p(
        "This audit maps every admin desk that feeds the public website. "
        "The site does not invent listings, quotes, or service detail pages. "
        "Visitors see only what staff saved and published, plus switches that are on. "
        "Two control layers work together."
    )
    pdf.bullet(
        "Website (sidebar) writes the content: headlines, estates, services, blog posts, FAQs, menus, and footer links."
    )
    pdf.bullet(
        "Settings turns whole areas on or off: calculators, blog, FAQs, testimonials, contact forms, portals, and maintenance mode."
    )
    pdf.p(
        "A published estate still stays hidden if the property-listings switch is off. "
        "A saved FAQ still stays hidden if that question is a draft, or if the FAQ switch is off. "
        "Both the record and the switch have to allow it."
    )
    pdf.p(
        "Most Website desks write to Supabase and refresh the public site on save or publish. "
        "Many lists also use realtime so another admin sees updates without reloading. "
        "Hosted builds (for example Vercel) show saved content on the next page load; "
        "local Flutter previews need a hot restart when you change app code."
    )

    pdf.h1("2. Permissions (who can operate the website)")
    pdf.p(
        "The left sidebar hides desks your role cannot use. Super Admin sees everything. "
        "Typical bundles from the permission engine:"
    )
    pdf.bullet(
        "Website — homepage, pages, blog, media, banners, menus, footer, SEO, services, "
        "calculators, careers, proof content, and most section editors opened from Website overview."
    )
    pdf.bullet(
        "Properties — estates, property listings, inspections, consultations, callbacks "
        "(enquiries from public booking flows)."
    )
    pdf.bullet(
        "Settings — Platform Control Center: public feature flags, maintenance, email, "
        "and Company Profile under Website."
    )
    pdf.bullet(
        "Support — live chat command center and ticket handling (works with the live-chat FAB switch)."
    )
    pdf.bullet(
        "Marketing hub — optional shortcut to the website forms inbox at /dashboard/website/support."
    )
    pdf.p(
        "If a colleague cannot open a desk, assign the matching permission in Users → Roles. "
        "Do not share the super-admin account for day-to-day editing."
    )

    pdf.h1("3. Where to sign in")
    pdf.path(
        "Admin dashboard",
        "/dashboard",
        "Open the site, sign in as staff, and use the left sidebar. Website permission is required for the content desks. Settings permission is required for company profile and the platform switches.",
    )
    pdf.path(
        "Website control center",
        "/dashboard/website",
        "The overview. It lists every public-site editor: homepage, pages, blog, proof, services, calculators, menus, footer, and SEO. The sidebar keeps the daily desks. The overview opens the rest.",
    )
    pdf.path(
        "Platform Control Center",
        "/dashboard/settings",
        "Open Public Website for the on/off switches. Change a switch, then save. Discard drops unsaved edits. Maintenance mode is on this same screen.",
    )

    pdf.h1("4. What visitors see in the header")
    pdf.p("The public header is fixed in this order:")
    pdf.bullet("Home")
    pdf.bullet("About")
    pdf.bullet("Properties — All Properties, Payment Calculator, Construction Updates")
    pdf.bullet("Investment — Opportunities, ROI Calculator")
    pdf.bullet("Discover — Services, Estates, Gallery, Blog, Careers, Contact")
    pdf.p(
        "Discover holds those six pages so they are not repeated as their own top links. "
        "Trust Center is retired. It is not in Discover, the footer, or the homepage. "
        "The old address /trust returns visitors to the homepage. Do not add a Trust Center link back."
    )
    pdf.p(
        "Menus (/dashboard/website/menus) can supply header labels. "
        "The Properties, Investment, and Discover dropdowns are put back automatically. "
        "A menu row that points at /trust is ignored."
    )

    pdf.h1("5. Switches that gate the public site")
    pdf.p("Go to Settings, then Public Website. Save after you change a switch.")
    pdf.h2("Floating buttons")
    pdf.bullet("WhatsApp button on public pages.")
    pdf.bullet("Live chat button.")
    pdf.bullet("Call button on mobile.")
    pdf.bullet("Book-inspection button on mobile.")
    pdf.h2("Pages and tools")
    pdf.bullet("Payment calculator — Properties menu and the calculator page.")
    pdf.bullet("ROI calculator — Investment menu and the calculator page.")
    pdf.bullet("Public search — the search icon in the header.")
    pdf.bullet("Newsletter — the homepage signup band.")
    pdf.bullet("Blog — Blog inside Discover and the public blog.")
    pdf.bullet("Testimonials — published quotes on the homepage and the other public pages that show them.")
    pdf.bullet("Partners — the partners band.")
    pdf.bullet("FAQ — published questions on the homepage, services, properties, estates, and investment.")
    pdf.bullet("Featured properties — the homepage property band.")
    pdf.bullet("Property and estate listings — the Properties menu and featured estates.")
    pdf.bullet("Investment — the Investment menu and related calls to action.")
    pdf.bullet("Construction updates — Construction Updates in the Properties menu.")
    pdf.bullet("Contact forms — the Contact page and lead forms.")
    pdf.bullet("Client portal entry — client login links.")
    pdf.bullet("Investor portal entry — investor login links.")
    pdf.h2("Maintenance")
    pdf.p(
        "Maintenance mode locks the public site for visitors who are not staff. "
        "Allow admin bypass lets a signed-in staff member keep browsing. "
        "The announcement banner uses the banner message on this screen. "
        "Set the maintenance title and message before you turn the lock on."
    )

    pdf.h1("6. Homepage")
    pdf.path(
        "Homepage desk",
        "/dashboard/website/homepage",
        "This is the switchboard for the public homepage. Each block can be shown or hidden. Some blocks are edited here. Others open their own desk.",
    )
    pdf.bullet("Hero — headline, buttons, and background. Also edited in Hero Manager at /dashboard/website/hero.")
    pdf.bullet("Search — the search field under the hero. It still needs the public-search switch.")
    pdf.bullet("About and Why Choose — story and reasons. The first three saved reasons are the ones that publish on the experience band.")
    pdf.bullet("Executive quote — shown only when the block is visible and the message is not empty.")
    pdf.bullet("Featured estates and featured properties — records you mark Featured and Published on their own desks.")
    pdf.bullet("Testimonials, partners, awards, statistics, blog, and FAQ — edited on their own desks. The homepage row only shows or hides the band.")
    pdf.bullet("Closing and call to action — the bottom of the homepage.")
    pdf.note(
        "If no estate is published, the estates page does not invent sample communities. "
        "Visitors see: No estates published yet. New communities will show here as soon as they are published."
    )

    pdf.h1("7. Estates and property listings")
    pdf.path(
        "Estates",
        "/dashboard/estates",
        "Create the estate, add the cover and gallery, then use the two switches on the row.",
    )
    pdf.bullet("Published — the estate appears on /estates. Draft stays off the public site.")
    pdf.bullet("Featured — a published estate can also appear on the homepage featured band.")
    pdf.bullet("Delete removes it from the public site. Linked properties are kept.")
    pdf.p("Publish an estate only when the name, location, cover, and price label are ready. An empty catalog is clearer than a draft community.")
    pdf.path(
        "Property listings",
        "/dashboard/properties",
        "Same rule: create the listing, upload the cover, then mark it Featured and Published. Draft listings stay off /properties and off the homepage.",
    )
    pdf.path(
        "Browse categories",
        "/dashboard/website/browse-categories",
        "The category cards on the properties marketplace. Counts follow the live published listings.",
    )

    pdf.h1("8. Services")
    pdf.path(
        "Services desk",
        "/dashboard/website/services",
        "Categories, the service catalog, and case studies. Only published items appear on /services.",
    )
    pdf.p(
        "Each service card has a Learn more label and an optional link. "
        "Leave the link empty and the card has no button. "
        "If you add a link, use an in-site path such as /contact or /book-consultation, or a full https address."
    )
    pdf.p(
        "There is no separate generated service page. An old address such as /services/project-management "
        "sends the visitor back to /services. Put the real offer in the card the admin saved."
    )

    pdf.h1("9. Investment, calculators, and construction")
    pdf.path(
        "Investments",
        "/dashboard/website/investments",
        "Public opportunities and the market-insights tab. The Investment menu also needs the investment switch in Settings.",
    )
    pdf.path(
        "Payment calculator",
        "/dashboard/website/payment-calculator",
        "Plans, rates, and applications. Hidden when the payment-calculator switch is off.",
    )
    pdf.path(
        "ROI calculator",
        "/dashboard/website/roi-calculator",
        "Return bounds and the formula visitors use. Hidden when the ROI switch is off.",
    )
    pdf.path(
        "Construction updates",
        "/dashboard/website/construction",
        "Progress cards opened from Properties, then Construction Updates. Upload the gallery on each update. Hidden when the construction switch is off.",
    )
    pdf.p(
        "Inspections, consultations, and callbacks that visitors book are worked in the Properties group of the sidebar: "
        "Inspections, Consultations, and Callbacks. Those desks operate the enquiries. They do not rewrite the public page design."
    )

    pdf.h1("10. Stories, proof, and the About page")
    pdf.path(
        "Blog",
        "/dashboard/website/blog",
        "Write the article, add a cover, and publish it. Drafts stay off /blog and off the homepage teaser. Categories can be shown or hidden.",
    )
    pdf.path(
        "Testimonials",
        "/dashboard/website/testimonials",
        "Save the client name, title, quote, and rating. Publish the quote. Featured quotes are shown first. The public band shows up to eight published quotes, and only while the testimonials switch is on.",
    )
    pdf.path(
        "FAQ",
        "/dashboard/website/faq",
        "Add the question and answer. Set it to Published, or use the eye control on the row to publish or unpublish. The page switch Show FAQs on the public website is the same FAQ switch as Settings. Published questions use one card: gold FAQ label, the question list, and View all FAQs. They appear on the homepage, services, properties, estates, and investment.",
    )
    pdf.path(
        "Awards, partners, statistics",
        "/dashboard/website/awards   ·   /partners   ·   /statistics",
        "These feed the homepage proof bands and the About page. Hide a homepage band from the homepage desk without deleting the records.",
    )
    pdf.path(
        "About building blocks",
        "/dashboard/website/client-journey",
        "Client journey steps, journey benefits, offices, team, and the digital profile are separate editors opened from Website overview. They publish on the About page.",
    )
    pdf.path(
        "Digital profile",
        "/dashboard/website/digital-profile",
        "The About profile card, downloadable files, and trust figures.",
    )
    pdf.path(
        "Team",
        "/dashboard/website/team",
        "Leadership shown on About.",
    )
    pdf.path(
        "Careers",
        "/dashboard/website/careers",
        "Job posts, the public application form, and the applications that come in. Careers stays inside Discover.",
    )
    pdf.path(
        "Pages and hub heroes",
        "/dashboard/website/pages",
        "Headlines and legal pages: privacy, terms, cookies, and refunds. Legal contact instructions point visitors to the Contact page.",
    )
    pdf.path(
        "Media library",
        "/dashboard/website/media",
        "Upload images used by heroes, listings, construction updates, and the gallery. The public Gallery page is inside Discover.",
    )

    pdf.h1("11. Chrome, company details, and SEO")
    pdf.path(
        "Banners",
        "/dashboard/website/banners",
        "The gold announcement bar at the top of public pages. Publish the banner you want visitors to see. Turn older banners off.",
    )
    pdf.path(
        "Footer",
        "/dashboard/website/footer",
        "Columns and links under the site. Use real pages only: About, Properties, Investment, Contact, Privacy, Terms, Cookies, and the login labels you still want. Do not add Trust Center.",
    )
    pdf.path(
        "Company profile",
        "/dashboard/website/company",
        "Legal name, phone, email, and address used across the public site. Requires settings permission.",
    )
    pdf.path(
        "SEO",
        "/dashboard/website/seo",
        "One title and description per public path: Home, About, Properties, Estates, Construction, Services, Blog, Gallery, Contact, Book inspection, Book consultation, Search, Investment, and Careers. Saving writes the score from the actual title and description. The public page uses the saved tags.",
    )

    pdf.h1("12. Contact hub and public forms")
    pdf.path(
        "Contact hub copy",
        "/dashboard/website/pages  (page slug: contact)",
        "Hero headline, intro, and hub sections for /contact. Contact forms only work when "
        "the contact-forms switch is on in Settings.",
    )
    pdf.path(
        "Website forms inbox",
        "/dashboard/website/support",
        "Support tickets and form submissions from the public site. Also linked from Marketing "
        "command center as Forms inbox. Operate statuses here; do not confuse with Support → "
        "Command Center for internal ops tickets.",
    )
    pdf.path(
        "Live chat",
        "/dashboard/live-chat",
        "Configure published vs draft chat product, section titles, and staff routing. "
        "The floating chat button follows Settings → Live chat FAB.",
    )
    pdf.p(
        "Book inspection and book consultation are public routes (/book-inspection, "
        "/book-consultation). Their copy is edited through the relevant hub pages and "
        "contact CMS providers; completed bookings land under Properties → Inspections or "
        "Consultations.",
    )

    pdf.h1("13. Enquiries the website creates")
    pdf.p("Publishing a page is only half the operation. These desks receive what visitors submit.")
    pdf.bullet("Contact and consultation forms — Contact hub, when contact forms are switched on.")
    pdf.bullet("Book inspection — Properties, then Inspections.")
    pdf.bullet("Callbacks — Properties, then Callbacks.")
    pdf.bullet("Careers applications — Website, then Careers.")
    pdf.bullet("Calculator applications — the payment-calculator desk.")
    pdf.bullet("Live chat — Support, then Live Chat. The public chat button follows the live-chat switch.")
    pdf.p(
        "Client and investor accounts are separate from the public pages. "
        "Users, roles, and compliance stay in the Users section of the sidebar. "
        "Do not delete the super admin when clearing test accounts."
    )

    pdf.h1("14. A normal publishing pass")
    pdf.p("Use this order when you put a new community or offer on the site.")
    pdf.bullet("1. Upload images in the Media Library.")
    pdf.bullet("2. Create the estate or listing. Leave it as Draft until the cover, location, and price label are correct.")
    pdf.bullet("3. Turn Published on. Turn Featured on only if it should also sit on the homepage.")
    pdf.bullet("4. Open the public page in a private window: /estates, /properties, or /services.")
    pdf.bullet("5. If the page is empty, the record is still a draft, it was deleted, or the matching switch in Settings is off.")
    pdf.bullet("6. Set the SEO title and description for that path.")
    pdf.bullet("7. If the offer needs a button, put a real link on the service card. An empty link means no button.")
    pdf.h2("Before you announce a page")
    pdf.bullet("Read the public page. Confirm you do not see sample names that you did not publish.")
    pdf.bullet("Confirm FAQs and testimonials on that page are ones you published.")
    pdf.bullet("Confirm the header dropdowns still read Properties, Investment, and Discover, with no Trust Center.")
    pdf.bullet("Confirm the footer has no retired links.")

    pdf.h1("15. If something does not appear")
    pdf.bullet("The record is still Draft, or it was deleted.")
    pdf.bullet("The homepage block for that band is hidden.")
    pdf.bullet("The matching switch in Settings, Public Website, is off. Save after you turn it on.")
    pdf.bullet("Blog, calculators, investment, construction, and contact each have their own switch.")
    pdf.bullet("Featured homepage estates require both Published and Featured, plus the listings switch.")
    pdf.bullet("A service with no saved link correctly shows no Learn more button.")
    pdf.bullet("Maintenance mode is on, so visitors see the lock instead of the site.")
    pdf.p(
        "Changes in this admin are stored for the live database immediately after you save or publish. "
        "A hosted web build shows them on the next refresh of that deployment. "
        "A local preview needs a hot restart before the new screen code is visible."
    )

    pdf.h1("16. Appendix — admin desk to public page")
    pdf.p(
        "Quick reference from Website overview and sidebar. Open /dashboard/website for the live counts."
    )
    rows = [
        ("Homepage sections", "/dashboard/website/homepage", "/"),
        ("Hero Manager", "/dashboard/website/hero", "/"),
        ("Estates catalog", "/dashboard/estates", "/estates"),
        ("Property listings", "/dashboard/properties", "/properties"),
        ("Browse categories", "/dashboard/website/browse-categories", "/properties"),
        ("Pages & hub heroes", "/dashboard/website/pages", "Hub slugs: about, properties, estates, services, contact, investment, careers, gallery, search"),
        ("Legal pages", "/dashboard/website/pages", "/pages/privacy, /pages/terms, /pages/cookies, /pages/refund-policy"),
        ("Blog", "/dashboard/website/blog", "/blog"),
        ("Services", "/dashboard/website/services", "/services"),
        ("Investments", "/dashboard/website/investments", "/investment"),
        ("Payment calculator", "/dashboard/website/payment-calculator", "/properties/payment-calculator"),
        ("ROI calculator", "/dashboard/website/roi-calculator", "/investment/roi-calculator"),
        ("Construction", "/dashboard/website/construction", "/construction"),
        ("Testimonials", "/dashboard/website/testimonials", "Home + services, properties, estates, investment, about"),
        ("FAQ", "/dashboard/website/faq", "Same pages as testimonials band"),
        ("Awards / Partners / Statistics", "/dashboard/website/awards etc.", "Home + About"),
        ("Client journey & benefits", "/dashboard/website/client-journey", "/about"),
        ("Offices / Team / Digital profile", "/dashboard/website/offices etc.", "/about"),
        ("Careers", "/dashboard/website/careers", "/careers"),
        ("Media library", "/dashboard/website/media", "Gallery + listing covers"),
        ("Banners", "/dashboard/website/banners", "Top bar on all public pages"),
        ("Menus", "/dashboard/website/menus", "Header + drawer (dropdowns auto-applied)"),
        ("Footer", "/dashboard/website/footer", "Site footer columns"),
        ("Company profile", "/dashboard/website/company", "Contact details site-wide"),
        ("SEO", "/dashboard/website/seo", "Meta tags per public path"),
        ("Platform switches", "/dashboard/settings", "Feature flags + maintenance"),
        ("Forms inbox", "/dashboard/website/support", "Inbound website tickets"),
        ("Live chat desk", "/dashboard/live-chat", "Floating chat widget"),
    ]
    for label, admin_path, public_effect in rows:
        pdf.path(label, admin_path, public_effect)

    pdf.ln(4)
    pdf.set_font("Body", "", 9)
    pdf.set_text_color(*MUTED)
    pdf.multi_cell(
        0,
        4.6,
        "This guide covers the public website an administrator operates from Website and Settings. "
        "Finance, sales, construction operations, and the client and investor portals have their own desks "
        "and are not rewritten from the website editors.",
    )

    pdf.output(str(OUT))
    print(OUT)


if __name__ == "__main__":
    build()
