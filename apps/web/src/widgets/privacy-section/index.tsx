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
      <div className="bg-white-7 flex h-full flex-1 flex-col items-center justify-between gap-11 rounded-4xl px-9 pt-8">
        <div className="flex flex-col gap-4">
          <h2 className="text-4xl leading-[150%] font-semibold">{title}</h2>
          <p className="text-content-70 text-lg">{text}</p>
        </div>
        <div className="flex flex-1 items-end justify-center">
          <Image
            src={image}
            alt={title}
            width={300}
            height={100}
            className="object-contain"
          />
        </div>
      </div>
    </SpotlightCard>
  );
};

export const PrivacySection = () => {
  return (
    <div className="flex flex-col items-center gap-25 py-30">
      <div className="flex flex-col items-center">
        <h1 className="flex items-center gap-2 text-[60px] leading-[105%] font-semibold">
          Privacy is value.
        </h1>
        <h1 className="text-content-50 text-[60px] leading-[105%] font-semibold">
          Ownership is the product.
        </h1>
      </div>
      <div className="flex w-full justify-between gap-6">
        {cards.map((card) => (
          <Card key={card.title} {...card} />
        ))}
      </div>
    </div>
  );
};
