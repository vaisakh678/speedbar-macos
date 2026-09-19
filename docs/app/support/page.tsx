import type { Metadata } from "next";
import { Page, Section } from "../components/Chrome";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Help, troubleshooting and contact details for Wirespeed, the macOS menu bar network speed monitor.",
};

const CONTACT = "support@cortexlumora.com";

export default function Support() {
  return (
    <Page title="Support">
      <p className="-mt-4 leading-relaxed text-muted">
        Questions, bug reports and feature requests are all welcome. Email{" "}
        <a href={`mailto:${CONTACT}`} className="text-foreground underline underline-offset-4">
          {CONTACT}
        </a>
        . Including your macOS version and which Mac you are using makes most
        problems much quicker to diagnose.
      </p>

      <Section heading="The menu bar item has disappeared">
        <p>
          This is almost always macOS rather than Wirespeed. When the menu bar
          runs out of room, macOS silently hides status items — and it hides
          them entirely rather than showing an overflow. It is most noticeable
          on Macs with a notch, because the notch eats the middle of the bar,
          and when the frontmost app has a long menu of its own.
        </p>
        <p>
          Switching to an app with a shorter menu usually brings the item
          straight back. If you run many menu bar apps, a menu bar manager such
          as Bartender or Ice will keep Wirespeed visible. Setting the menu bar
          display to <em>Download only</em> in Preferences also makes the item
          narrower.
        </p>
      </Section>

      <Section heading="The reading does not match my ISP's advertised speed">
        <p>
          Wirespeed measures the traffic actually crossing your connection right
          now, not how much your connection is capable of. An idle Mac reads
          near zero however fast the line is. To measure capacity, use{" "}
          <em>Run Speed Test</em> in the panel.
        </p>
      </Section>

      <Section heading="The speed test disagrees with Ookla or fast.com">
        <p>
          It will, and by design. Wirespeed&apos;s test is a single stream against
          Cloudflare with no server selection and no multi-connection ramp-up.
          It is meant to answer roughly how fast this link is right now, not to
          replace a dedicated speed testing service. Expect it to read lower
          than a multi-connection test on a fast line.
        </p>
      </Section>

      <Section heading="Numbers look wrong while a VPN is connected">
        <p>
          Wirespeed follows the interface your Mac is routing through, so with a
          VPN up it measures the tunnel. Those figures include the VPN&apos;s own
          encapsulation overhead, so they read slightly higher than the payload
          you are actually moving. The panel names the connection it is
          measuring, so you can always tell which one you are looking at.
        </p>
      </Section>

      <Section heading="Should I read bytes or bits?">
        <p>
          Both are offered in Preferences because both are in common use. ISPs
          advertise in bits per second (Mbps); Finder and most download managers
          count in bytes per second (MB/s). One MB/s is eight Mbps, so a
          connection sold as 100 Mbps tops out around 12.5 MB/s.
        </p>
      </Section>

      <Section heading="A warning triangle is showing">
        <p>
          That means macOS reports no route to the internet. Wirespeed shows it
          instead of a rate because zero bytes per second is indistinguishable
          from a connection that is simply idle.
        </p>
      </Section>

      <Section heading="There is no icon in the Dock">
        <p>
          Wirespeed is a menu bar app and deliberately has no Dock icon or app
          switcher entry. Everything lives in the panel: click the menu bar item
          to open it, and use <em>Quit</em> at the bottom to exit.
        </p>
      </Section>

      <Section heading="Launch at login will not stay switched on">
        <p>
          Registering a login item requires a properly signed copy of the app.
          If you built Wirespeed yourself with ad-hoc signing, macOS refuses the
          registration and the switch reverts. Copies from the App Store are not
          affected.
        </p>
      </Section>

      <Section heading="Contact">
        <p>
          <a href={`mailto:${CONTACT}`} className="text-foreground underline underline-offset-4">
            {CONTACT}
          </a>
          <br />
          Cortexlumora Private Limited
        </p>
      </Section>
    </Page>
  );
}
