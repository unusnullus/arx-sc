import { HeroSection } from "@/widgets/hero-section";
import { GovernanceSection } from "@/widgets/governance-section";
import { TokenInfo } from "@/widgets/token-info";
import { RecentTransaction } from "@/widgets/recent-transactions";
import { IntroArx } from "@/widgets/intro-arx";
import { PrivacySection } from "@/widgets/privacy-section";
import { EdgeKeys } from "@/widgets/edge-keys";
import { ArxRoadmap } from "@/widgets/arx-roadmap";
import { CtaSection } from "@/widgets/cta-section";

export default function Home() {
  return (
    <div className="container flex flex-col gap-20">
      <HeroSection />
      <div className="flex flex-col gap-20 items-center">
        <div className="flex flex-col gap-6 items-center">
          <h1 className="text-[60px] font-semibold flex items-center gap-2 leading-[105%]">
            Token details & activity
          </h1>
          <p className="text-content-70 text-lg max-w-md text-center">
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
    </div>
  );
}
