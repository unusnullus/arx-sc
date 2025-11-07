import { HeroSection } from "@/widgets/hero-section";
import { BuySection } from "@/widgets/buy-section";
import { TokenDetails } from "@/widgets/token-details";
import { EdgeKeys } from "@/widgets/edge-keys";
import { Footer } from "@/widgets/footer";
import { GovernanceSection } from "@/widgets/governance-section";
import { ArxRoadmap } from "@/widgets/arx-roadmap";
import { CtaSection } from "@/widgets/cta-section";
import { IntroArx } from "@/widgets/intro-arx";
import { PrivacySection } from "@/widgets/privacy-section";

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
