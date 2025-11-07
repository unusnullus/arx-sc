import dynamic from "next/dynamic";

import { HeroSection } from "@/widgets/hero-section";
import { BuySection } from "@/widgets/buy-section";
import { TokenDetails } from "@/widgets/token-details";

const GovernanceSection = dynamic(
  () =>
    import("@/widgets/governance-section").then((mod) => ({
      default: mod.GovernanceSection,
    })),
  { ssr: true },
);

const IntroArx = dynamic(
  () =>
    import("@/widgets/intro-arx").then((mod) => ({
      default: mod.IntroArx,
    })),
  { ssr: true },
);

const PrivacySection = dynamic(
  () =>
    import("@/widgets/privacy-section").then((mod) => ({
      default: mod.PrivacySection,
    })),
  { ssr: true },
);

const EdgeKeys = dynamic(
  () =>
    import("@/widgets/edge-keys").then((mod) => ({
      default: mod.EdgeKeys,
    })),
  { ssr: true },
);

const ArxRoadmap = dynamic(
  () =>
    import("@/widgets/arx-roadmap").then((mod) => ({
      default: mod.ArxRoadmap,
    })),
  { ssr: true },
);

const CtaSection = dynamic(
  () =>
    import("@/widgets/cta-section").then((mod) => ({
      default: mod.CtaSection,
    })),
  { ssr: true },
);

const Footer = dynamic(
  () =>
    import("@/widgets/footer").then((mod) => ({
      default: mod.Footer,
    })),
  { ssr: true },
);

export default function Home() {
  return (
    <div className="container flex flex-col gap-20">
      <HeroSection />
      <BuySection />
      <TokenDetails />
      <GovernanceSection />
      <IntroArx />
      <PrivacySection />
      <EdgeKeys />
      <ArxRoadmap />
      <CtaSection />
      <Footer />
    </div>
  );
}
