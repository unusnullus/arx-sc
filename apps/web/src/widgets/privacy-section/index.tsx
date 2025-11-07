import { SpotlightCard } from "@arx/ui/components";
import Image from "next/image";

const cards = [
  {
    title: "Speak",
    text: "E2EE messenger with groups, channels, roles, bots, mini-apps, and ephemeral modes. No phone or email—sign with your wallet.",
    image: "/images/iphone.svg",
  },
  {
    title: "Pay",
    text: "HD, multi-chain wallet with in-chat transfers and a crypto card—money belongs where we talk.",
    image: "/images/iphone-2.svg",
  },
  {
    title: "Connect",
    text: "Validators double as no-logs VPN; add a global eSIM for travel.",
    image: "/images/iphone-3.svg",
  },
];

const Card = ({
  title,
  text,
  image,
}: {
  title: string;
  text: string;
  image: string;
}) => {
  return (
    <SpotlightCard className="flex-1" spotlightColor="rgba(101, 65, 255, 0.3)">
      <div className="bg-white-7 flex h-full flex-1 flex-col items-center justify-between gap-8 rounded-4xl px-6 pt-6 md:gap-11 md:px-9 md:pt-8">
        <div className="flex flex-col gap-4">
          <h2 className="text-2xl leading-[150%] font-semibold md:text-4xl">
            {title}
          </h2>
          <p className="text-content-70 text-base md:text-lg">{text}</p>
        </div>
        <div className="flex flex-1 items-end justify-center">
          <Image
            src={image}
            alt={`${title} feature illustration showing Arx app interface`}
            width={300}
            height={600}
            className="object-contain"
          />
        </div>
      </div>
    </SpotlightCard>
  );
};

export const PrivacySection = () => {
  return (
    <div className="flex flex-col items-center gap-10 py-10 md:gap-25 md:py-30">
      <div className="flex flex-col items-center">
        <h1 className="flex items-center gap-2 text-[32px] leading-[105%] font-semibold md:text-[60px]">
          Privacy is value.
        </h1>
        <h1 className="text-content-50 text-center text-[32px] leading-[105%] font-semibold md:text-[60px]">
          Ownership is the product.
        </h1>
      </div>
      <div className="flex w-full flex-col justify-between gap-6 md:flex-row">
        {cards.map((card) => (
          <Card key={card.title} {...card} />
        ))}
      </div>
    </div>
  );
};
