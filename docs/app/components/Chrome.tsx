import Link from "next/link";

const links = [
  { href: "/", label: "Overview" },
  { href: "/support", label: "Support" },
  { href: "/privacy", label: "Privacy" },
];

export function SiteHeader() {
  return (
    <header className="border-b border-rule">
      <nav className="mx-auto flex max-w-3xl items-center gap-6 px-6 py-4">
        <Link href="/" className="flex items-center gap-2 font-semibold">
          <span aria-hidden className="text-[#5CA8FF]">▼</span>
          <span aria-hidden className="-ml-1 text-[#FF9E3D]">▲</span>
          <span className="ml-1">Wirespeed</span>
        </Link>
        <div className="ml-auto flex gap-5 text-sm">
          {links.slice(1).map((l) => (
            <Link key={l.href} href={l.href} className="text-muted hover:text-foreground">
              {l.label}
            </Link>
          ))}
        </div>
      </nav>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer className="mt-auto border-t border-rule">
      <div className="mx-auto flex max-w-3xl flex-col gap-2 px-6 py-8 text-sm text-muted sm:flex-row sm:items-center">
        <p>© 2026 Cortexlumora Private Limited</p>
        <div className="flex gap-5 sm:ml-auto">
          <Link href="/support" className="hover:text-foreground">Support</Link>
          <Link href="/privacy" className="hover:text-foreground">Privacy</Link>
        </div>
      </div>
    </footer>
  );
}

export function Page({ title, updated, children }: { title: string; updated?: string; children: React.ReactNode }) {
  return (
    <main className="mx-auto w-full max-w-3xl flex-1 px-6 py-12">
      <h1 className="text-3xl font-semibold tracking-tight">{title}</h1>
      {updated && <p className="mt-2 text-sm text-muted">Last updated {updated}</p>}
      <div className="mt-8 flex flex-col gap-8">{children}</div>
    </main>
  );
}

export function Section({ heading, children }: { heading: string; children: React.ReactNode }) {
  return (
    <section className="flex flex-col gap-3">
      <h2 className="text-lg font-semibold tracking-tight">{heading}</h2>
      <div className="flex flex-col gap-3 leading-relaxed text-muted">{children}</div>
    </section>
  );
}
