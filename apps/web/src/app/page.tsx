import { BuySection } from "@/widgets/buy-section";
import { GovernanceSection } from "@/widgets/governance-section";
import { TokenInfo } from "@/widgets/token-info";
import { RecentTransaction } from "@/widgets/recent-transactions";
import { IntroArx } from "@/widgets/intro-arx";
import { PrivacySection } from "@/widgets/privacy-section";
import { EdgeKeys } from "@/widgets/edge-keys";
import { ArxRoadmap } from "@/widgets/arx-roadmap";
import { CtaSection } from "@/widgets/cta-section";
import { HeroSection } from "@/widgets/hero-section";
import { Footer } from "@/widgets/footer";

export default function Home() {
  return (
    <div className="container flex flex-col gap-20">
      <HeroSection />
      <BuySection />
      <div className="flex flex-col items-center gap-10 md:gap-20">
        <div className="flex flex-col items-center gap-6">
          <h1 className="flex items-center gap-2 text-center text-[32px] leading-[105%] font-semibold md:text-[60px]">
            Token details & activity
          </h1>
          <p className="text-content-70 max-w-md text-center text-lg md:text-xl">
            Learn more about the ARX token — its role in the Arx Network and
            your recent activity.{" "}
          </p>
        </div>
        <div className="grid w-full grid-cols-1 gap-5 md:grid-cols-2">
          <TokenInfo />
          <RecentTransaction />
        </div>
      </div>
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
