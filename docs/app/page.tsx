import Link from "next/link";
import { Page, Section } from "./components/Chrome";

export default function Home() {
  return (
    <Page title="Wirespeed">
      <p className="-mt-4 text-lg leading-relaxed text-muted">
        A live network speed monitor for the macOS menu bar. Wirespeed reads the
        throughput counters macOS already keeps for your network interface, so
        what you see is the traffic actually crossing your connection.
      </p>

      <Section heading="What it does">
        <ul className="flex list-disc flex-col gap-2 pl-5">
          <li>
            Shows one figure in the menu bar: whichever direction is busier. The
            arrow flips between download and upload as traffic changes.
          </li>
          <li>
            Measures the interface your Mac is actually routing through — Wi-Fi,
            Ethernet or a VPN tunnel — rather than summing every adapter.
          </li>
          <li>A sixty second history graph, session totals and peak speed.</li>
          <li>
            Your local IP address, one click to copy. Your public address too,
            but only when you ask for it.
          </li>
          <li>An on-demand download, upload and latency test.</li>
        </ul>
      </Section>

      <Section heading="Requirements">
        <p>macOS 14.0 or later. Apple silicon and Intel.</p>
      </Section>

      <Section heading="Help and legal">
        <p>
          <Link href="/support" className="underline underline-offset-4 hover:text-foreground">
            Support and troubleshooting
          </Link>{" "}
          ·{" "}
          <Link href="/privacy" className="underline underline-offset-4 hover:text-foreground">
            Privacy policy
          </Link>
        </p>
      </Section>
    </Page>
  );
}
