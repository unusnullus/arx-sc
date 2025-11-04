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
    <div className="flex flex-col items-center justify-between pt-8 px-9 rounded-4xl bg-white-7 gap-11 flex-1">
      <div className="flex flex-col  gap-4">
        <h2 className="text-4xl font-semibold leading-[150%]">{title}</h2>
        <p className="text-content-70 text-lg">{text}</p>
      </div>
      <div className="flex flex-1 items-end justify-center ">
        <Image
          src={image}
          alt={title}
          width={300}
          height={100}
          className="object-contain"
        />
      </div>
    </div>
  );
};

export const PrivacySection = () => {
  return (
    <div className="flex flex-col items-center py-30 gap-25">
      <div className="flex flex-col items-center">
        <h1 className="text-[60px] font-semibold flex items-center gap-2 leading-[105%]">
          Privacy is value.
        </h1>
        <h1 className="text-[60px] font-semibold text-content-50 leading-[105%]">
          Ownership is the product.
        </h1>
      </div>
      <div className="flex justify-between w-full gap-6">
        {cards.map((card) => (
          <Card key={card.title} {...card} />
        ))}
      </div>
    </div>
  );
};
