export const EdgeKeys = () => {
  return (
    <div className="flex flex-col items-center gap-10 py-10 md:gap-25 md:py-20">
      <div className="flex flex-col items-center gap-8">
        <div className="flex-shrink-0 md:mb-8">
          <video
            src="/videos/lock.mp4"
            autoPlay
            loop
            muted
            playsInline
            className="size-32 md:size-40"
            aria-label="Animation of lock representing security"
          />
        </div>
        <div className="flex flex-col items-center">
          <h1 className="flex items-center gap-2 text-[32px] leading-[105%] font-semibold md:text-[60px]">
            Edge keys
          </h1>
          <h1 className="text-content-50 text-[32px] leading-[105%] font-semibold md:text-[60px]">
            Off-chain messages.
          </h1>
          <h1 className="text-content-50 text-[32px] leading-[105%] font-semibold md:text-[60px]">
            On-chain incentives.
          </h1>
        </div>
        <p className="text-content-70 text-center text-base md:text-lg">
          Your identity is EOA (ETH) + Signal identity; you sign once and keep
          keys local.
          <br /> Messages stay off-chain. The chain coordinates trust, staking,
          rewards, and governance.
        </p>
      </div>
    </div>
  );
};
