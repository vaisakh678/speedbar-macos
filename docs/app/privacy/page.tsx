import type { Metadata } from "next";
import { Page, Section } from "../components/Chrome";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "Wirespeed collects no data. This policy describes what stays on your Mac and the only two occasions the app contacts the internet.",
};

const CONTACT = "support@cortexlumora.com";

export default function Privacy() {
  return (
    <Page title="Privacy Policy" updated="19 September 2026">
      <p className="-mt-4 rounded-lg border border-rule bg-card p-4 leading-relaxed">
        Wirespeed collects nothing about you. There are no accounts, no
        analytics, no telemetry and no crash reporting. Cortexlumora operates no
        servers for this app and receives no data from it.
      </p>

      <Section heading="What stays on your Mac">
        <p>
          Everything the app measures is read locally and stays locally. None of
          it is transmitted anywhere.
        </p>
        <ul className="flex list-disc flex-col gap-2 pl-5">
          <li>
            <strong className="text-foreground">Throughput readings</strong> — read from
            the per-interface byte counters macOS already maintains.
          </li>
          <li>
            <strong className="text-foreground">Active connection</strong> — which
            interface your Mac is routing through, and whether it is a tunnel.
          </li>
          <li>
            <strong className="text-foreground">Local IP address</strong> — read from the
            network interface. Copied to your clipboard only when you click to copy it.
          </li>
          <li>
            <strong className="text-foreground">Session totals and the history graph</strong>{" "}
            — held in memory and discarded when you quit.
          </li>
          <li>
            <strong className="text-foreground">Preferences</strong> — stored in macOS user
            defaults on your Mac.
          </li>
        </ul>
      </Section>

      <Section heading="The only two times Wirespeed contacts the internet">
        <p>
          Both are started by you. Neither happens merely because you opened the
          menu, and neither happens in the background.
        </p>
        <ul className="flex list-disc flex-col gap-2 pl-5">
          <li>
            <strong className="text-foreground">Running a speed test.</strong> When you
            choose <em>Run Speed Test</em>, the app transfers test data to and from
            Cloudflare&apos;s public speed test endpoints at speed.cloudflare.com.
          </li>
          <li>
            <strong className="text-foreground">Looking up your public IP.</strong> When
            you choose <em>Look Up Public IP</em>, the app makes a single request to
            the same host and reads the address Cloudflare reports back.
          </li>
        </ul>
        <p>
          In both cases Cloudflare necessarily sees your IP address, as any
          server does when your Mac connects to it. Their handling of that is
          governed by Cloudflare&apos;s own privacy policy. Wirespeed sends no
          identifier, no account and nothing describing you or your Mac beyond
          what any ordinary HTTPS request carries.
        </p>
      </Section>

      <Section heading="What Wirespeed never does">
        <ul className="flex list-disc flex-col gap-2 pl-5">
          <li>No analytics, telemetry or crash reporting.</li>
          <li>No advertising and no tracking of any kind.</li>
          <li>No accounts, sign-in or registration.</li>
          <li>
            No background network activity. The meter reads counters for traffic
            you are already generating; it never generates traffic to measure you.
          </li>
          <li>
            No sale or sharing of personal data, which follows from there being
            none to sell or share.
          </li>
        </ul>
      </Section>

      <Section heading="Sandboxing">
        <p>
          Wirespeed runs inside the macOS App Sandbox. The only entitlement it
          requests is outgoing network access, which the speed test and the
          public IP lookup need. It has no access to your files, contacts,
          location, camera, microphone or any other protected resource.
        </p>
      </Section>

      <Section heading="Children">
        <p>
          Wirespeed collects no personal information from anyone, children
          included, and is not directed at children.
        </p>
      </Section>

      <Section heading="Changes to this policy">
        <p>
          If this policy changes, the revised version will be posted on this
          page with a new date above. Material changes will also be noted in the
          app&apos;s release notes.
        </p>
      </Section>

      <Section heading="Contact">
        <p>
          Questions about this policy can go to{" "}
          <a href={`mailto:${CONTACT}`} className="text-foreground underline underline-offset-4">
            {CONTACT}
          </a>
          .
          <br />
          Cortexlumora Private Limited
        </p>
      </Section>
    </Page>
  );
}
